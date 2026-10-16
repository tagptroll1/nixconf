import { app } from "electron";
import { unlinkSync } from "fs";
import { createServer, Server, Socket } from "net";
import { join } from "path";

// The shell's StageDock reads mention state from here and drives the chat
// widget back through it: listing, reading, replying and jumping.
const socketPath = join(process.env.XDG_RUNTIME_DIR || "/tmp", "vesktop-mentions.sock");
const channelPath = /^\/channels\/(@me|\d+)\/\d+(\/\d+)?$/;
const snowflake = /^\d{1,20}$/;
// RegExp.test coerces, so a number or ["1"] would pass and be forwarded as-is.
const isId = (v: unknown): v is string => typeof v === "string" && snowflake.test(v);

type Body =
    | { jump: string; }
    | { list: "dms" | "guilds"; }
    | { list: "channels"; guildId: string; }
    | { open: string | null; }
    | { send: string; content: string; };

// The renderer sees native's route token as `id`, never the shell's own.
export type Command = Body & { id: number; };

// Bounds the route table if the renderer never answers some commands.
const MAX_ROUTES = 64;
// A slow or misbehaving client must not grow main-process memory without bound.
const MAX_LINE = 64 * 1024;
const MAX_QUEUE = 32;
const MAX_PENDING = 1024 * 1024;
const MAX_CLIENTS = 8;

let server: Server | null = null;
const clients = new Set<Socket>();
let state = "";
// The renderer's verdict on Discord's internals, replayed like mention state.
let status = "";
const queue: Command[] = [];
let waiter: ((cmd: Command | null) => void) | null = null;
// Handed to the renderer but not yet acknowledged by its next poll.
let inflight: Command | null = null;
// Each renderer load says hello and gets a fresh generation; 0 means none is
// listening. The counter never resets so a stopped poller can't pass as current.
let counter = 0;
let generation = 0;
// Each client counts its own ids, so replies route by a token native hands out.
const routes = new Map<number, { client: Socket; id: number; }>();
let lastToken = 0;

function unlinkSocket() {
    try { unlinkSync(socketPath); } catch { }
}

// Only well-formed commands reach the renderer; the socket is the trust edge.
function parseBody(raw: any): Body | null {
    if (typeof raw.jump === "string") return channelPath.test(raw.jump) ? { jump: raw.jump } : null;
    if (raw.list === "dms" || raw.list === "guilds") return { list: raw.list };
    if (raw.list === "channels") return isId(raw.guildId) ? { list: "channels", guildId: raw.guildId } : null;
    if ("open" in raw) return raw.open === null || isId(raw.open) ? { open: raw.open } : null;
    if (isId(raw.send) && typeof raw.content === "string") {
        const content = raw.content.trim();
        return content && content.length <= 2000 ? { send: raw.send, content } : null;
    }
    return null;
}

function parse(raw: any): Command | null {
    if (!raw || typeof raw !== "object") return null;
    // Without an id a reply has nowhere to go.
    if (!Number.isSafeInteger(raw.id) || raw.id <= 0) return null;
    const body = parseBody(raw);
    return body && { ...body, id: raw.id };
}

function route(client: Socket, cmd: Command): Command {
    const token = ++lastToken;
    routes.set(token, { client, id: cmd.id });
    if (routes.size > MAX_ROUTES) routes.delete(routes.keys().next().value!);
    return { ...cmd, id: token };
}

function forget(client: Socket) {
    clients.delete(client);
    for (const [token, r] of routes) if (r.client === client) routes.delete(token);
}

function readyLine() {
    return JSON.stringify({ type: "ready", generation }) + "\n";
}

// A client that stops reading gets dropped rather than buffered forever.
function send(client: Socket, line: string) {
    if (client.writableLength > MAX_PENDING) {
        console.warn("[ShellMentions] dropping client, too much unread output");
        client.destroy();
        return;
    }
    client.write(line);
}

function broadcast(line: string) {
    for (const client of clients) send(client, line);
}

function deliver(client: Socket, cmd: Command) {
    if (!generation) {
        send(client, JSON.stringify({ type: "error", id: cmd.id, generation, reason: "renderer-unavailable" }) + "\n");
        return;
    }
    cmd = route(client, cmd);
    if (!waiter) {
        if (queue.length >= MAX_QUEUE) console.warn("[ShellMentions] command queue full, dropped", queue.shift());
        queue.push(cmd);
        return;
    }
    const resolve = waiter;
    waiter = null;
    inflight = cmd;
    resolve(cmd);
}

function onClient(client: Socket) {
    if (clients.size >= MAX_CLIENTS) {
        console.warn("[ShellMentions] refusing client, limit reached");
        client.destroy();
        return;
    }
    clients.add(client);
    send(client, readyLine());
    if (status) send(client, status);
    if (state) send(client, state);
    let buffer = "";
    client.setEncoding("utf8");
    client.on("data", chunk => {
        buffer += chunk;
        let nl: number;
        while ((nl = buffer.indexOf("\n")) !== -1) {
            const line = buffer.slice(0, nl);
            buffer = buffer.slice(nl + 1);
            let cmd: Command | null;
            try { cmd = parse(JSON.parse(line)); } catch { continue; }
            if (cmd) deliver(client, cmd);
        }
        if (buffer.length > MAX_LINE) {
            console.warn("[ShellMentions] dropping client, line too long");
            client.destroy();
        }
    });
    client.on("close", () => forget(client));
    client.on("error", () => forget(client));
}

export function start() {
    if (server) return;
    // A crashed session leaves the socket file behind and listen() would fail.
    unlinkSocket();
    server = createServer(onClient);
    server.on("error", err => console.error("[ShellMentions]", err));
    server.listen(socketPath);
    app.once("will-quit", stop);
}

export function stop() {
    generation = 0;
    queue.length = 0;
    inflight = null;
    state = "";
    status = "";
    routes.clear();
    if (waiter) { waiter(null); waiter = null; }
    // end() flushes the ready line that destroy() would drop.
    const line = readyLine();
    for (const client of clients) client.end(line, () => client.destroy());
    clients.clear();
    server?.close();
    server = null;
    unlinkSocket();
}

// Mention state is replayed to every new client.
export function publish(_, json: string) {
    state = json + "\n";
    broadcast(state);
}

export function announce(_, payload: object) {
    status = JSON.stringify({ ...payload, id: null, generation }) + "\n";
    broadcast(status);
}

// A command's answer goes only to the client that sent it; a null token is a
// live update for everyone.
export function reply(_, token: number | null, payload: object) {
    const target = token === null ? null : routes.get(token);
    if (token !== null && !target) return;
    const line = JSON.stringify({ ...payload, id: target ? target.id : null, generation }) + "\n";
    if (target) send(target.client, line);
    else broadcast(line);
}

// A reload keeps the main process, server and shell connection alive, so each
// new renderer announces itself. Its predecessor may have died holding a
// command it never ran; that goes back to the front of the queue.
export function hello(_): number {
    generation = ++counter;
    if (inflight) queue.unshift(inflight);
    inflight = null;
    state = "";
    status = "";
    if (waiter) { waiter(null); waiter = null; }
    broadcast(readyLine());
    return generation;
}

// Long poll: resolves with the next command the shell sent, or null once the
// caller's generation is over. Polling again acknowledges the last command.
export function nextCommand(_, gen: number): Promise<Command | null> {
    if (gen !== generation) return Promise.resolve(null);
    inflight = queue.shift() ?? null;
    if (inflight) return Promise.resolve(inflight);
    waiter?.(null);
    return new Promise(resolve => { waiter = resolve; });
}
