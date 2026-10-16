// Runs logic.ts against the captured-shape fixtures: `node check.mjs`
// (node 23.6+ strips the types itself). Not part of the Vencord build, which
// only bundles what index.ts and native.ts import.
import { deepStrictEqual } from "node:assert";
import { readdirSync, readFileSync } from "node:fs";

import { addToChat, sendFailed, sentReply, snippet, trimMentions } from "./logic.ts";

const dir = new URL("./fixtures/", import.meta.url);

// Same fallbacks the plugin uses when Discord can't resolve a name.
function lookup({ users = {}, roles = {}, channels = {} }) {
    return {
        user: id => users[id] || "user",
        role: id => roles[id] || "role",
        channel: id => channels[id] || "channel",
    };
}

const kinds = {
    mentions({ cache, channels, names }) {
        const r = trimMentions(cache, channels);
        return {
            total: r.total,
            picked: r.picked.map(m => m.id),
            keep: [...r.keep].sort(),
            refillDms: r.refillDms.map(c => c.id),
            guildMissing: r.guildMissing,
            snippets: names && r.picked.map(m => snippet(m, lookup(names))),
        };
    },
    chat: ({ chat, messages, channelId, size }) => addToChat(chat, messages, channelId, size),
    sent: input => ("err" in input ? sendFailed(input.channelId, input.err) : sentReply(input.channelId, input.res)),
};

// Fixtures state only what they care about.
function only(got, expect) {
    if (Array.isArray(expect) || typeof expect !== "object" || expect === null) return got;
    return Object.fromEntries(Object.keys(expect).map(k => [k, got[k]]));
}

let failed = 0;
let passed = 0;
for (const file of readdirSync(dir).filter(f => f.endsWith(".json")).sort()) {
    const { cases } = JSON.parse(readFileSync(new URL(file, dir), "utf8"));
    for (const c of cases) {
        try {
            deepStrictEqual(only(kinds[c.kind](c.input), c.expect), c.expect);
            passed++;
        } catch (err) {
            failed++;
            console.error(`FAIL ${file}: ${c.name}\n${err.message}\n`);
        }
    }
}
console.log(`${passed} passed, ${failed} failed`);
process.exit(failed ? 1 : 0);
