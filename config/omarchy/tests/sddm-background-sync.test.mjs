import assert from 'node:assert/strict';
import { spawn, spawnSync } from 'node:child_process';
import { once } from 'node:events';
import {
  existsSync, lstatSync, mkdirSync, mkdtempSync, readFileSync, readdirSync,
  rmSync, symlinkSync, unlinkSync, writeFileSync,
} from 'node:fs';
import { join } from 'node:path';
import test from 'node:test';

const source = readFileSync(new URL('../bin/sddm-background-sync', import.meta.url), 'utf8');

function sandbox(t) {
  const root = mkdtempSync('/tmp/opencode/sddm-background-sync-');
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const dest = join(root, 'wallpaper');
  const home = join(root, 'home');
  const bin = join(root, 'bin');
  const current = join(home, '.local/state/omarchy/current');
  mkdirSync(current, { recursive: true });
  mkdirSync(bin);
  const script = join(bin, 'sddm-background-sync');
  writeFileSync(script, source.replace('/var/lib/sddm-wallpaper', dest), { mode: 0o755 });
  const env = { ...process.env, HOME: home, PATH: `${bin}:${process.env.PATH}` };
  const link = join(current, 'background');
  const output = join(dest, 'background');
  const select = (name, content) => {
    const image = join(root, name);
    writeFileSync(image, content, { mode: 0o600 });
    if (lstatSync(link, { throwIfNoEntry: false })) unlinkSync(link);
    symlinkSync(image, link);
    return image;
  };
  const run = () => spawnSync('bash', [script], { env, encoding: 'utf8', timeout: 5000 });
  return { root, dest, bin, script, env, link, output, select, run };
}

test('missing destination skips without provisioning it', (t) => {
  const s = sandbox(t);
  s.select('image.png', 'image');
  assert.equal(s.run().status, 0);
  assert.equal(existsSync(s.dest), false);
});

test('missing or dangling source preserves prior image', (t) => {
  const s = sandbox(t);
  mkdirSync(s.dest);
  writeFileSync(s.output, 'prior');
  assert.equal(s.run().status, 0);
  symlinkSync(join(s.root, 'missing.png'), s.link);
  assert.equal(s.run().status, 0);
  assert.equal(readFileSync(s.output, 'utf8'), 'prior');
});

test('publishes independent regular copy with mode 0644, replacing destination symlink', (t) => {
  const s = sandbox(t);
  mkdirSync(s.dest);
  const prior = join(s.root, 'prior.png');
  writeFileSync(prior, 'prior');
  symlinkSync(prior, s.output);
  const image = s.select('image with spaces.png', 'selected');
  assert.equal(s.run().status, 0);
  assert.equal(lstatSync(s.output).isFile(), true);
  assert.equal(lstatSync(s.output).mode & 0o777, 0o644);
  assert.equal(readFileSync(s.output, 'utf8'), 'selected');
  writeFileSync(image, 'changed');
  assert.equal(readFileSync(s.output, 'utf8'), 'selected');
  assert.equal(readFileSync(prior, 'utf8'), 'prior');
});

for (const command of ['cp', 'chmod', 'mv']) {
  test(`${command} failure reports error, preserves prior image and cleans temp file`, (t) => {
    const s = sandbox(t);
    mkdirSync(s.dest);
    writeFileSync(s.output, 'prior');
    s.select('image.png', 'selected');
    const partialCopy = command === 'cp' ? 'printf partial >"${@: -1}"\n' : '';
    writeFileSync(join(s.bin, command), `#!/usr/bin/env bash\n${partialCopy}exit 1\n`, { mode: 0o755 });
    const result = s.run();
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /sddm-background-sync: failed to publish background/);
    assert.equal(readFileSync(s.output, 'utf8'), 'prior');
    assert.deepEqual(readdirSync(s.dest).sort(), ['.sync.lock', 'background']);
  });
}

test('queued publishers read current selection after acquiring lock', { timeout: 5000 }, async (t) => {
  const s = sandbox(t);
  mkdirSync(s.dest);
  s.select('old.png', 'old');
  const holder = spawn('bash', ['-c', 'exec 9>"$1/.sync.lock"; flock 9; printf ready; read -r release', 'bash', s.dest], { env: s.env });
  t.after(() => holder.kill());
  await once(holder.stdout, 'data');
  const realFlock = spawnSync('bash', ['-c', 'command -v flock'], { encoding: 'utf8' }).stdout.trim();
  writeFileSync(join(s.bin, 'flock'), `#!/usr/bin/env bash\nprintf waiting\nexec "${realFlock}" "$@"\n`, { mode: 0o755 });
  const publishers = [0, 1].map(() => spawn('bash', [s.script], { env: s.env }));
  for (const child of publishers) t.after(() => child.kill());
  const exits = publishers.map((child) => once(child, 'exit'));
  await Promise.all(publishers.map((child) => once(child.stdout, 'data')));
  assert.equal(existsSync(s.output), false);
  s.select('new.png', 'new');
  holder.stdin.end('release\n');
  for (const [code] of await Promise.all(exits)) assert.equal(code, 0);
  assert.equal(readFileSync(s.output, 'utf8'), 'new');
});
