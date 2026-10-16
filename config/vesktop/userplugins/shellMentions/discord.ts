import { sendMessage } from "@utils/discord";
import { findStoreLazy } from "@webpack";
import {
    ChannelStore,
    GuildChannelStore,
    GuildMemberStore,
    GuildRoleStore,
    GuildStore,
    MessageActions,
    NavigationRouter,
    ReadStateStore,
    RestAPI,
    UserGuildSettingsStore,
    UserStore,
} from "@webpack/common";

import type { RawMessage } from "./logic";

// The only door to Discord's internals. Its web client ships on its own
// schedule, so everything used here is checked by validate() at start and the
// rest of the plugin sees plain shapes.

const SortedGuildStore = findStoreLazy("SortedGuildStore");

export interface Channel {
    id: string;
    // 0 text, 1 DM, 3 group DM, 5 announcement.
    type: number;
    guildId: string | null;
    name: string;
    recipients: string[];
    icon: string | null;
}

export interface Guild {
    id: string;
    name: string;
    icon: string | null;
}

export interface User {
    id: string;
    name: string;
    avatar: string | null;
}

// Every method the plugin calls. A lazy store that never resolves throws on
// access, which counts as missing too.
const used: [string, () => unknown][] = [
    ["UserStore.getCurrentUser", () => UserStore?.getCurrentUser],
    ["UserStore.getUser", () => UserStore?.getUser],
    ["ChannelStore.getChannel", () => ChannelStore?.getChannel],
    ["ChannelStore.getSortedPrivateChannels", () => ChannelStore?.getSortedPrivateChannels],
    ["SortedGuildStore.getGuildFolders", () => SortedGuildStore?.getGuildFolders],
    ["GuildStore.getGuild", () => GuildStore?.getGuild],
    ["GuildMemberStore.getMember", () => GuildMemberStore?.getMember],
    ["GuildRoleStore.getRole", () => GuildRoleStore?.getRole],
    ["GuildChannelStore.getChannels", () => GuildChannelStore?.getChannels],
    ["UserGuildSettingsStore.isMuted", () => UserGuildSettingsStore?.isMuted],
    ["ReadStateStore.getMentionChannelIds", () => ReadStateStore?.getMentionChannelIds],
    ["ReadStateStore.getMentionCount", () => ReadStateStore?.getMentionCount],
    ["ReadStateStore.ackMessageId", () => ReadStateStore?.ackMessageId],
    ["ReadStateStore.hasUnread", () => ReadStateStore?.hasUnread],
    ["ReadStateStore.addChangeListener", () => ReadStateStore?.addChangeListener],
    ["ReadStateStore.removeChangeListener", () => ReadStateStore?.removeChangeListener],
    ["RestAPI.get", () => RestAPI?.get],
    ["NavigationRouter.transitionTo", () => NavigationRouter?.transitionTo],
    ["MessageActions.sendMessage", () => MessageActions?.sendMessage],
];

// Names of the used methods this Discord build lacks; empty when all is well.
export function validate(): string[] {
    return used
        .filter(([, get]) => {
            try { return typeof get() !== "function"; } catch { return true; }
        })
        .map(([name]) => name);
}

function toChannel(raw: any): Channel | null {
    if (!raw?.id) return null;
    return {
        id: raw.id,
        type: raw.type,
        guildId: raw.guild_id || null,
        name: raw.name ?? "",
        recipients: raw.recipients ?? [],
        icon: raw.icon || null,
    };
}

export function currentUserId(): string | null {
    return UserStore.getCurrentUser()?.id ?? null;
}

export function user(id: string): User | null {
    const raw: any = UserStore.getUser(id);
    return raw ? { id: raw.id, name: raw.globalName || raw.username, avatar: raw.avatar || null } : null;
}

export function userName(id: string) {
    return user(id)?.name || "user";
}

export function channel(id: string): Channel | null {
    return toChannel(ChannelStore.getChannel(id));
}

export function privateChannels(): Channel[] {
    return ChannelStore.getSortedPrivateChannels().map(toChannel).filter((c): c is Channel => c !== null);
}

// Guild ids per sidebar folder, in sidebar order.
export function guildFolders(): string[][] {
    return (SortedGuildStore.getGuildFolders() as { guildIds: string[]; }[]).map(f => f.guildIds ?? []);
}

export function guild(id: string | null): Guild | null {
    const raw: any = id ? GuildStore.getGuild(id) : null;
    return raw ? { id: raw.id, name: raw.name, icon: raw.icon || null } : null;
}

export function member(guildId: string, userId: string): { nick: string | null; roles: string[]; } | null {
    const raw: any = GuildMemberStore.getMember(guildId, userId);
    return raw ? { nick: raw.nick || null, roles: raw.roles ?? [] } : null;
}

export function role(guildId: string, roleId: string): { name: string; } | null {
    const raw: any = GuildRoleStore.getRole(guildId, roleId);
    return raw ? { name: raw.name } : null;
}

// SELECTABLE is already filtered to channels this account can view.
export function selectableChannels(guildId: string): { channel: Channel; comparator: number; }[] {
    const raw = (GuildChannelStore.getChannels(guildId)?.SELECTABLE ?? []) as { channel: any; comparator: number; }[];
    return raw.flatMap(e => {
        const c = toChannel(e.channel);
        return c ? [{ channel: c, comparator: e.comparator }] : [];
    });
}

export function guildMuted(id: string): boolean {
    return UserGuildSettingsStore.isMuted(id);
}

// Optional, so outside validate(): without them every @everyone and role ping
// counts, and the server-first trim still corrects the list.
export function suppressEveryone(guildId: string): boolean {
    const store: any = UserGuildSettingsStore;
    return typeof store?.isSuppressEveryoneEnabled === "function" && !!store.isSuppressEveryoneEnabled(guildId);
}

export function suppressRoles(guildId: string): boolean {
    const store: any = UserGuildSettingsStore;
    return typeof store?.isSuppressRolesEnabled === "function" && !!store.isSuppressRolesEnabled(guildId);
}

export function mentionChannelIds(): string[] {
    return Array.from(ReadStateStore.getMentionChannelIds());
}

export function mentionCount(id: string): number {
    return ReadStateStore.getMentionCount(id);
}

export function ackId(id: string): string | null {
    return ReadStateStore.ackMessageId(id) ?? null;
}

export function hasUnread(id: string): boolean {
    return ReadStateStore.hasUnread(id);
}

// Returns the unsubscribe.
export function onReadStateChange(fn: () => void) {
    ReadStateStore.addChangeListener(fn);
    return () => ReadStateStore.removeChangeListener(fn);
}

export async function fetchMessages(channelId: string, query: { after?: string; limit: number; }): Promise<RawMessage[]> {
    const res = await RestAPI.get({ url: `/channels/${channelId}/messages`, query });
    return res?.body ?? [];
}

export async function fetchMentions(): Promise<RawMessage[]> {
    const res = await RestAPI.get({
        url: "/users/@me/mentions",
        query: { limit: 50, roles: true, everyone: true },
    });
    return res?.body ?? [];
}

export function navigate(path: string) {
    NavigationRouter.transitionTo(path);
}

// Waiting for the channel to be ready holds the send until the chat is opened
// in Vesktop itself, which the dock never does.
export function send(channelId: string, content: string): Promise<any> {
    return sendMessage(channelId, { content }, false);
}
