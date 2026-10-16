// Pure bridge logic. No Discord or Vencord imports, so check.mjs can run it
// under plain node against the fixtures.

// Raw gateway/REST message: the only shape both live events and fetches share.
export interface RawMessage {
    id: string;
    channel_id: string;
    content?: string;
    author?: { id: string; username?: string; global_name?: string | null; avatar?: string | null; };
    mentions?: { id: string; }[];
    mention_roles?: string[];
    mention_everyone?: boolean;
    attachments?: unknown[];
    embeds?: unknown[];
    timestamp?: string;
}

// "server" came through Discord's own mention filter, which applies the user's
// suppress settings; "live" is our guess from the gateway.
export type Origin = "server" | "live";

export interface CachedMessage extends RawMessage {
    origin: Origin;
}

// A mention channel as Discord's read state sees it.
export interface MentionChannel {
    id: string;
    count: number;
    ack: string | null;
    private: boolean;
}

// Names the snippet puts in place of raw <@id>, <@&id> and <#id> tokens.
export interface Names {
    user(id: string): string;
    role(id: string): string;
    channel(id: string): string;
}

export const newer = (a: string, b: string | null) => BigInt(a) > BigInt(b || "0");

const newestFirst = (a: RawMessage, b: RawMessage) => (newer(a.id, b.id) ? -1 : 1);

// A newer live guess must not take the slot of a mention Discord confirmed.
const serverFirst = (a: CachedMessage, b: CachedMessage) =>
    a.origin === b.origin ? newestFirst(a, b) : a.origin === "server" ? -1 : 1;

// Newest `count` unread per channel: Discord's badge decides how many, the
// cache which. Channels the cache can't fill are handed back for a refill, and
// a guild channel also until the server has confirmed every slot.
export function trimMentions(cached: Iterable<CachedMessage>, channels: MentionChannel[]) {
    const all = [...cached];
    let total = 0;
    const picked: CachedMessage[] = [];
    const keep = new Set<string>();
    const refillDms: MentionChannel[] = [];
    let guildMissing = false;
    for (const channel of channels) {
        if (!channel.count) continue;
        total += channel.count;
        const candidates = all.filter(m => m.channel_id === channel.id && newer(m.id, channel.ack));
        const unread = candidates.sort(channel.private ? newestFirst : serverFirst).slice(0, channel.count);
        for (const m of unread) {
            keep.add(m.id);
            picked.push(m);
        }
        if (channel.private) {
            if (unread.length < channel.count) refillDms.push(channel);
        } else if (candidates.filter(m => m.origin === "server").length < channel.count) {
            guildMissing = true;
        }
    }
    picked.sort(newestFirst);
    return { total, picked, keep, refillDms, guildMissing };
}

// Keeps the newest `size`, oldest first, so a live message racing the fetch still lands.
export function addToChat(chat: RawMessage[], messages: RawMessage[], channelId: string | null, size: number) {
    const byId = new Map(chat.map(m => [m.id, m]));
    for (const m of messages) if (m.channel_id === channelId) byId.set(m.id, m);
    return [...byId.values()].sort((a, b) => (newer(a.id, b.id) ? 1 : -1)).slice(-size);
}

export function snippet(msg: RawMessage, names: Names) {
    const text = (msg.content ?? "")
        .replace(/<@!?(\d+)>/g, (_, id) => "@" + names.user(id))
        .replace(/<@&(\d+)>/g, (_, id) => "@" + names.role(id))
        .replace(/<#(\d+)>/g, (_, id) => "#" + names.channel(id))
        .replace(/<a?:(\w+):\d+>/g, ":$1:")
        .replace(/\s+/g, " ")
        .trim();
    if (text) return text.length > 140 ? text.slice(0, 139) + "…" : text;
    if (msg.attachments?.length) return "[attachment]";
    if (msg.embeds?.length) return "[embed]";
    return "";
}

export function errorText(err: any, fallback: string) {
    return String(err?.body?.message || err?.message || fallback);
}

// Resolving is not proof of delivery; a response saying otherwise wins.
export function sentReply(channelId: string, res: any) {
    return res?.ok === false ? sendFailed(channelId, res) : { type: "sent", channelId, ok: true };
}

export function sendFailed(channelId: string, err: any) {
    return { type: "sent", channelId, ok: false, error: errorText(err, "Send failed") };
}
