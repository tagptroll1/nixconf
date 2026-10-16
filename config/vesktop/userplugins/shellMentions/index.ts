import definePlugin, { PluginNative } from "@utils/types";

import * as Discord from "./discord";
import type { Channel } from "./discord";
import { addToChat, type CachedMessage, errorText, type MentionChannel, type Origin, type RawMessage, sendFailed, sentReply, snippet, trimMentions } from "./logic";

const Native = VencordNative.pluginHelpers.ShellMentions as PluginNative<typeof import("./native")>;
type Command = import("./native").Command;

const MAX_ITEMS = 20;
const MAX_LIST = 40;
const CHAT_SIZE = 2;
const REFETCH_COOLDOWN = 30_000;
const MAX_FETCH_ERRORS = 3;
// Text and announcement channels; the rest can't take a plain reply.
const TEXT_TYPES = new Set([0, 5]);

const cache = new Map<string, CachedMessage>();
const lastFetch = new Map<string, number>();
// One pending retry per refill key, and its consecutive failures.
const retryTimers = new Map<string, ReturnType<typeof setTimeout>>();
const fetchErrors = new Map<string, number>();
let timer: ReturnType<typeof setTimeout> | null = null;
let running = false;
// Set once Discord.validate() passes for this renderer; until then nothing
// touches Discord's stores.
let compatible = false;
let unsubscribe: (() => void) | null = null;
// This renderer's hello from native; 0 until then and after stop. Async work
// that outlives its generation is dropped.
let generation = 0;
// The one channel the shell's chat widget is showing, oldest message first.
let openId: string | null = null;
let chat: RawMessage[] = [];
// The list the panel last asked for, kept fresh until it opens a chat.
type Browse = { list: "dms" | "guilds"; } | { list: "channels"; guildId: string; };
let browse: Browse | null = null;
let lastBrowseJson = "";

function isPrivate(channel: Channel) {
    return channel.type === 1 || channel.type === 3;
}

// Local guess for live messages; Discord's own count trims it in compute().
function qualifies(msg: RawMessage) {
    const me = Discord.currentUserId();
    if (!me || msg.author?.id === me) return false;
    const channel = Discord.channel(msg.channel_id);
    if (!channel) return false;
    if (isPrivate(channel)) return true;
    if (msg.mentions?.some(u => u.id === me)) return true;
    const { guildId } = channel;
    if (msg.mention_everyone && !(guildId && Discord.suppressEveryone(guildId))) return true;
    if (!guildId || Discord.suppressRoles(guildId)) return false;
    const roles = Discord.member(guildId, me)?.roles ?? [];
    return !!msg.mention_roles?.some(r => roles.includes(r));
}

function names(guildId: string | null) {
    return {
        user: Discord.userName,
        role: (id: string) => (guildId && Discord.role(guildId, id)?.name) || "role",
        channel: (id: string) => Discord.channel(id)?.name || "channel",
    };
}

function avatarUrl(author: { id: string; avatar?: string | null; } | null | undefined) {
    if (!author) return "";
    if (author.avatar) return `https://cdn.discordapp.com/avatars/${author.id}/${author.avatar}.png?size=64`;
    return `https://cdn.discordapp.com/embed/avatars/${Number((BigInt(author.id) >> 22n) % 6n)}.png`;
}

function where(channel: Channel) {
    if (channel.type === 1) return "DM";
    if (channel.type === 3) {
        return channel.name || channel.recipients.map(Discord.userName).join(", ") || "Group DM";
    }
    const guild = Discord.guild(channel.guildId);
    return `#${channel.name}${guild ? " · " + guild.name : ""}`;
}

function title(channel: Channel) {
    return channel.type === 1 ? Discord.userName(channel.recipients[0]) : where(channel);
}

function channelIcon(channel: Channel) {
    if (channel.type === 1) return avatarUrl(Discord.user(channel.recipients[0]));
    if (channel.icon) return `https://cdn.discordapp.com/channel-icons/${channel.id}/${channel.icon}.png?size=64`;
    return "";
}

function channelPath(channel: Channel) {
    return `/channels/${channel.guildId || "@me"}/${channel.id}`;
}

function item(msg: RawMessage, channel: Channel) {
    const author = msg.author;
    const member = channel.guildId && author ? Discord.member(channel.guildId, author.id) : null;
    return {
        id: msg.id,
        channelId: channel.id,
        path: `${channelPath(channel)}/${msg.id}`,
        author: member?.nick || author?.global_name || author?.username || "unknown",
        avatarUrl: avatarUrl(author),
        where: where(channel),
        snippet: snippet(msg, names(channel.guildId)),
        ts: msg.timestamp ? Date.parse(msg.timestamp) : 0,
    };
}

// A server confirmation outlives a later live copy of the same message.
function remember(msg: RawMessage, origin: Origin) {
    if (!msg?.id || !msg.channel_id) return;
    const known = cache.get(msg.id)?.origin === "server";
    cache.set(msg.id, { ...msg, origin: known ? "server" : origin });
}

async function fetchDm(channelId: string, after: string | null, count: number): Promise<RawMessage[]> {
    const messages = await Discord.fetchMessages(channelId, { after: after || "0", limit: Math.min(count, 50) });
    const me = Discord.currentUserId();
    return messages.filter(msg => msg.author?.id !== me);
}

// Recompute once the cooldown ends, since no Discord event may come to do it.
function retryIn(key: string, delay: number) {
    if (retryTimers.has(key)) return;
    retryTimers.set(key, setTimeout(() => {
        retryTimers.delete(key);
        schedule();
    }, delay));
}

function clearRetries() {
    for (const t of retryTimers.values()) clearTimeout(t);
    retryTimers.clear();
}

// Refill a channel's missing messages, at most once per cooldown. A key that
// keeps failing rests until the next reconnect or ack.
function refill(key: string, fetch: () => Promise<RawMessage[]>) {
    if ((fetchErrors.get(key) ?? 0) >= MAX_FETCH_ERRORS) return;
    const now = Date.now();
    const wait = (lastFetch.get(key) ?? 0) + REFETCH_COOLDOWN - now;
    if (wait > 0) {
        retryIn(key, wait);
        return;
    }
    lastFetch.set(key, now);
    const gen = generation;
    fetch().then(messages => {
        if (gen !== generation) return;
        fetchErrors.delete(key);
        for (const msg of messages) remember(msg, "server");
        schedule();
    }, err => {
        console.warn("[ShellMentions] fetch failed", err);
        if (gen !== generation) return;
        const errors = (fetchErrors.get(key) ?? 0) + 1;
        fetchErrors.set(key, errors);
        if (errors < MAX_FETCH_ERRORS) retryIn(key, REFETCH_COOLDOWN);
    });
}

function compute() {
    timer = null;
    if (!running || !compatible) return;
    const channels = new Map<string, Channel>();
    const read: MentionChannel[] = [];
    for (const id of Discord.mentionChannelIds()) {
        const channel = Discord.channel(id);
        if (!channel) continue;
        channels.set(id, channel);
        read.push({ id, count: Discord.mentionCount(id), ack: Discord.ackId(id), private: isPrivate(channel) });
    }

    const { total, picked, keep, refillDms, guildMissing } = trimMentions(cache.values(), read);
    for (const c of refillDms) refill(c.id, () => fetchDm(c.id, c.ack, c.count));
    if (guildMissing) refill("@guilds", Discord.fetchMentions);

    for (const id of cache.keys()) if (!keep.has(id)) cache.delete(id);

    const items = picked.slice(0, MAX_ITEMS).map(m => item(m, channels.get(m.channel_id)!));
    Native.publish(JSON.stringify({ type: "mentions", total, items }));
}

function schedule() {
    if (running && compatible && !timer) timer = setTimeout(() => {
        // Store shapes can shift with Discord updates; an empty shelf beats a crash.
        try { compute(); } catch (err) { console.error("[ShellMentions]", err); }
        try { refreshBrowse(); } catch (err) { console.error("[ShellMentions]", err); }
    }, 250);
}

// `id` is the command being answered; null for live updates.
function reply(id: number | null, payload: object) {
    Native.reply(id, payload);
}

function entry(channel: Channel, name: string, iconUrl: string) {
    return {
        id: channel.id,
        name,
        iconUrl,
        unread: Discord.hasUnread(channel.id),
        mentions: Discord.mentionCount(channel.id),
    };
}

function listDms() {
    const items = Discord.privateChannels()
        .slice(0, MAX_LIST)
        .map(c => entry(c, title(c), channelIcon(c)));
    return { type: "dms", items };
}

function textChannels(guildId: string) {
    return Discord.selectableChannels(guildId)
        .filter(e => TEXT_TYPES.has(e.channel.type))
        .sort((a, b) => a.comparator - b.comparator)
        .map(e => e.channel);
}

// Sidebar order, folders flattened.
function listGuilds() {
    const mentions = new Map<string, number>();
    for (const id of Discord.mentionChannelIds()) {
        const guildId = Discord.channel(id)?.guildId;
        if (guildId) mentions.set(guildId, (mentions.get(guildId) ?? 0) + Discord.mentionCount(id));
    }
    const items = Discord.guildFolders()
        .flat()
        .map(Discord.guild)
        .filter(g => g !== null)
        .map(g => ({
            id: g.id,
            name: g.name,
            iconUrl: g.icon ? `https://cdn.discordapp.com/icons/${g.id}/${g.icon}.png?size=64` : "",
            // A muted server shows no unread dot in Discord either.
            unread: !Discord.guildMuted(g.id) && textChannels(g.id).some(c => Discord.hasUnread(c.id)),
            mentions: mentions.get(g.id) ?? 0,
        }));
    return { type: "guilds", items };
}

function listChannels(guildId: string) {
    const items = textChannels(guildId).map(c => entry(c, "#" + c.name, ""));
    return { type: "channels", guildId, title: Discord.guild(guildId)?.name ?? "", items };
}

function browseList(scope: Browse) {
    if (scope.list === "dms") return listDms();
    if (scope.list === "guilds") return listGuilds();
    return listChannels(scope.guildId);
}

function answerBrowse(id: number, scope: Browse) {
    const payload = browseList(scope);
    browse = scope;
    lastBrowseJson = JSON.stringify(payload);
    reply(id, payload);
}

// Unchanged lists stay unsent so store churn doesn't flood the socket.
function refreshBrowse() {
    if (!running || !compatible || !browse) return;
    const payload = browseList(browse);
    const json = JSON.stringify(payload);
    if (json === lastBrowseJson) return;
    lastBrowseJson = json;
    reply(null, payload);
}

function clearBrowse() {
    browse = null;
    lastBrowseJson = "";
}

function publishChat(id: number | null, status: "loading" | "ready" | "error" = "ready", error = "") {
    if (!openId) {
        reply(id, { type: "chat", channelId: null, status: "ready", messages: [] });
        return;
    }
    const channel = Discord.channel(openId);
    if (!channel) {
        reply(id, { type: "chat", channelId: openId, status: "error", error: "Channel not available", messages: [] });
        return;
    }
    reply(id, {
        type: "chat",
        channelId: channel.id,
        status,
        ...(error ? { error } : {}),
        title: title(channel),
        path: channelPath(channel),
        messages: chat.map(m => item(m, channel)),
    });
}

async function fetchChat(id: number | null, channelId: string) {
    const gen = generation;
    let messages: RawMessage[] = [];
    let error = "";
    try {
        messages = await Discord.fetchMessages(channelId, { limit: CHAT_SIZE });
    } catch (err) {
        error = errorText(err, "Could not load messages");
    }
    if (gen !== generation || openId !== channelId) return;
    if (error) {
        publishChat(id, "error", error);
        return;
    }
    chat = addToChat(chat, messages, openId, CHAT_SIZE);
    publishChat(id);
}

// The panel reopens its chat on every hover; blanking it then would collapse
// the dock until the fetch lands.
async function openChat(id: number, channelId: string | null) {
    if (channelId) clearBrowse();
    if (channelId !== openId) chat = [];
    openId = channelId;
    if (!channelId || !Discord.channel(channelId)) {
        publishChat(id);
        return;
    }
    publishChat(id, "loading");
    await fetchChat(id, channelId);
}

async function send(id: number, channelId: string, content: string) {
    const gen = generation;
    let result: object;
    try {
        result = sentReply(channelId, await Discord.send(channelId, content));
    } catch (err) {
        result = sendFailed(channelId, err);
    }
    if (gen === generation) reply(id, result);
}

async function run(cmd: Command) {
    const { id } = cmd;
    if (!compatible) reply(id, { type: "error", reason: "incompatible" });
    else if ("jump" in cmd) Discord.navigate(cmd.jump);
    else if ("list" in cmd) answerBrowse(id, cmd.list === "channels" ? { list: "channels", guildId: cmd.guildId } : { list: cmd.list });
    else if ("open" in cmd) await openChat(id, cmd.open);
    else await send(id, cmd.send, cmd.content);
}

// Null means native moved on to another generation or stopped.
async function pollCommands(gen: number) {
    while (running && gen === generation) {
        const cmd = await Native.nextCommand(gen);
        if (!cmd || !running || gen !== generation) return;
        // Not awaited: a slow fetch or send must not hold up the next command.
        run(cmd).catch(err => {
            console.error("[ShellMentions]", err);
            // The shell still waits on this id.
            if (gen === generation) reply(cmd.id, { type: "error", reason: "command-failed", error: errorText(err, "Command failed") });
        });
    }
}

async function connect() {
    Native.start();
    const gen = await Native.hello();
    // Replies arrive in call order, so a later start's hello always lands last.
    if (!running) return;
    generation = gen;
    clearBrowse();
    clearRetries();
    // After hello, which clears native's status for the new renderer.
    const missing = Discord.validate();
    compatible = missing.length === 0;
    unsubscribe?.();
    unsubscribe = null;
    if (compatible) {
        Native.announce({ type: "status", state: "ok" });
        unsubscribe = Discord.onReadStateChange(schedule);
        schedule();
    } else {
        console.error("[ShellMentions] Discord bridge incompatible, missing:", missing);
        Native.announce({ type: "status", state: "incompatible", missing });
        Native.publish(JSON.stringify({ type: "mentions", total: 0, items: [] }));
    }
    pollCommands(gen);
}

export default definePlugin({
    name: "ShellMentions",
    description: "Streams unread mentions and DMs to the desktop shell, and lets it browse, read and reply to chats",
    authors: [{ name: "tagp", id: 0n }],
    enabledByDefault: true,

    flux: {
        CONNECTION_OPEN() {
            if (!compatible) return;
            cache.clear();
            lastFetch.clear();
            fetchErrors.clear();
            schedule();
            // The gateway missed whatever arrived while it was down.
            if (openId) fetchChat(null, openId).catch(err => console.warn("[ShellMentions] fetch failed", err));
        },
        MESSAGE_CREATE({ message, optimistic }: { message: RawMessage; optimistic: boolean; }) {
            if (!compatible) return;
            if (!optimistic && qualifies(message)) remember(message, "live");
            if (!optimistic && message?.channel_id === openId) {
                chat = addToChat(chat, [message], openId, CHAT_SIZE);
                publishChat(null);
            }
            schedule();
        },
        MESSAGE_UPDATE({ message }: { message: RawMessage; }) {
            if (!compatible) return;
            const old = cache.get(message?.id);
            if (old) cache.set(old.id, { ...old, ...message });
            const shown = chat.findIndex(m => m.id === message?.id);
            if (shown !== -1) {
                chat[shown] = { ...chat[shown], ...message };
                publishChat(null);
            }
            schedule();
        },
        MESSAGE_DELETE({ id }: { id: string; }) {
            if (!compatible) return;
            cache.delete(id);
            if (chat.some(m => m.id === id)) {
                chat = chat.filter(m => m.id !== id);
                publishChat(null);
            }
            schedule();
        },
        MESSAGE_DELETE_BULK({ ids }: { ids: string[]; }) {
            if (!compatible) return;
            const deleted = new Set(ids ?? []);
            for (const id of deleted) cache.delete(id);
            if (chat.some(m => deleted.has(m.id))) {
                chat = chat.filter(m => !deleted.has(m.id));
                publishChat(null);
            }
            schedule();
        },
        MESSAGE_ACK() {
            fetchErrors.clear();
            schedule();
        },
        // Names, order and membership of the browse lists.
        CHANNEL_CREATE: schedule,
        CHANNEL_DELETE: schedule,
        CHANNEL_UPDATE: schedule,
        GUILD_CREATE: schedule,
        GUILD_DELETE: schedule,
    },

    start() {
        running = true;
        connect().catch(err => console.error("[ShellMentions]", err));
    },

    stop() {
        running = false;
        compatible = false;
        generation = 0;
        unsubscribe?.();
        unsubscribe = null;
        if (timer) clearTimeout(timer);
        timer = null;
        cache.clear();
        lastFetch.clear();
        clearRetries();
        fetchErrors.clear();
        openId = null;
        chat = [];
        clearBrowse();
        Native.stop();
    },
});
