import assert from 'node:assert/strict';
import { accessSync, constants, existsSync, mkdtempSync, readFileSync, readdirSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';

const sender = fileURLToPath(new URL('../bin/send-notification', import.meta.url));
const icons = fileURLToPath(new URL('../../icons/lucide/icons/', import.meta.url));
const iconPath = name => join(icons, `${name}.svg`);

test('sender CLI with mocked notify-send', () => {
  accessSync(sender, constants.X_OK);
  const dir = mkdtempSync(join(tmpdir(), 'send-notification-'));
  try {
    writeFileSync(join(dir, 'notify-send'), '#!/usr/bin/env bash\nprintf "%s\\0" "$@"\nexit "${MOCK_STATUS:-0}"\n', { mode: 0o755 });
    const run = (args, status = 0) => spawnSync('bash', [sender, ...args], {
      env: { ...process.env, CONFIG_ICON_DIR: '', PATH: `${dir}:${process.env.PATH}`, MOCK_STATUS: String(status) },
      encoding: 'utf8',
    });
    const check = (args, type, icon, rest) => {
      const result = run(args);
      assert.equal(result.status, 0, result.stderr);
      assert.deepEqual(result.stdout.split('\0').slice(0, -1), [
        '-a', 'send-notification', '--category', type, '-u', 'normal', '-i', icon, ...rest,
      ]);
    };
    for (const flag of ['--help', '-h']) {
      const result = run([flag]);
      assert.equal(result.status, 0);
      assert.match(result.stdout, /Usage: send-notification/);
      assert.match(result.stdout, /--type info\|warning\|error/);
      assert.equal(result.stderr, '');
      assert.ok(!result.stdout.includes('\0'), 'help must not call notify-send');
    }
    const list = run(['--list-icons']);
    assert.equal(list.status, 0, list.stderr);
    assert.deepEqual(list.stdout.trim().split('\n').sort(),
      readdirSync(icons).filter(name => name.endsWith('.svg')).map(name => name.slice(0, -4)).sort());
    check(['Title'], 'info', iconPath('info'), ['--', 'Title']);
    for (const type of ['info', 'warning', 'error']) {
      check(['--type', type, 'Title', 'Text'], type,
        iconPath({ info: 'info', warning: 'triangle-alert', error: 'circle-x' }[type]), ['--', 'Title', 'Text']);
    }
    for (const flag of ['--icon', '-i']) {
      check([flag, 'bell', 'Title'], 'info', iconPath('bell'), ['--', 'Title']);
      check([flag, 'wifi', '--type', 'error', 'Title'], 'error', iconPath('wifi'), ['--', 'Title']);
    }
    for (const icon of ['/tmp/image with spaces.png', '\u{1f514}', 'weather-clear']) {
      for (const flag of ['--icon', '-i']) {
        check([flag, icon, 'Title'], 'info', icon, ['--', 'Title']);
      }
    }
    for (const flag of ['--expire-time', '-t']) {
      for (const timeout of ['-1', '0', '2000']) {
        check(['Title', flag, timeout], 'info', iconPath('info'), ['-t', timeout, '--', 'Title']);
      }
    }
    check(['--', '--hint=private:value', '$(touch nope); "quoted"\ntext'], 'info', iconPath('info'),
      ['--', '--hint=private:value', '$(touch nope); "quoted"\ntext']);
    for (const args of [[], [''], ['one', 'two', 'three'], ['--type'], ['--icon'], ['-t'],
      ['--type', 'critical', 'Title'], ['-t', '-2', 'Title'], ['-t', 'oops', 'Title'],
      ['--icon', '', 'Title'], ['Title', '--exec', 'true'], ['--urgency', 'critical', 'Title']]) {
      const result = run(args);
      assert.equal(result.status, 1, JSON.stringify(args));
      assert.equal(result.stdout, '', 'invalid input must not call notify-send');
      assert.match(result.stderr, /Usage:/);
    }
    assert.equal(run(['Title'], 7).status, 7);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('Fish completes shared icons and image paths only for icon options', () => {
  const completion = fileURLToPath(new URL('../../fish/completions/send-notification.fish', import.meta.url));
  const dir = mkdtempSync(join(tmpdir(), 'notification completion '));
  try {
    writeFileSync(join(dir, 'preview.png'), '');
    const complete = line => {
      const result = spawnSync('fish', ['--no-config', '-c',
        'source "$argv[1]"; complete --do-complete "$argv[2]"', completion, line], {
        env: { ...process.env, CONFIG_ICON_DIR: '', PATH: `${sender.slice(0, sender.lastIndexOf('/'))}:${process.env.PATH}` },
        cwd: dir, encoding: 'utf8', timeout: 5000,
      });
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stderr, '');
      return result.stdout.trim().split('\n').map(value => value.split('\t')[0]);
    };
    for (const flag of ['-i', '--icon']) {
      assert.ok(complete(`send-notification ${flag} bell`).includes('bell'));
      assert.ok(complete(`send-notification ${flag} ./pre`).includes('./preview.png'));
    }
    assert.ok(!complete('send-notification bell').includes('bell'));
    assert.deepEqual(complete('send-notification --type w'), ['warning']);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

const screenshot = fileURLToPath(new URL('../../mango/scripts/screenshot-region.sh', import.meta.url));

for (const [name, action, status, opensFolder] of [
  ['default selection', 'default', 0, true],
  ['dismissal', '', 0, false],
  ['failed notify', 'default', 1, false],
]) {
  test(`screenshot save: ${name}`, () => {
    const dir = mkdtempSync(join(tmpdir(), 'screenshot home with spaces '));
    try {
      const mock = `#!/usr/bin/env bash
set -euo pipefail
command_name=\${0##*/}
printf '%s\\0' "$@" > "$HOME/$command_name.args"
case "$command_name" in
  slurp) printf '10,20 300x400\\n' ;;
  grim) printf 'mock image\\n' ;;
  tee|wl-copy)
    while IFS= read -r line; do
      if [[ $command_name == tee ]]; then printf '%s\\n' "$line"; fi
    done
    ;;
  date) printf '2026-09-20_12-34-56\\n' ;;
  notify-send) printf '%s\\n' "$MOCK_ACTION"; exit "$MOCK_STATUS" ;;
  mkdir|cosmic-files) ;;
  *) exit 99 ;;
esac
`;
      for (const command of ['grim', 'slurp', 'wl-copy', 'tee', 'mkdir', 'date', 'notify-send', 'cosmic-files']) {
        writeFileSync(join(dir, command), mock, { mode: 0o755 });
      }
      // Sourcing keeps the background listener a child we can explicitly wait for.
      const result = spawnSync('bash', ['-c', 'source "$1" save; wait', 'screenshot-test', screenshot], {
        env: {
          ...process.env, HOME: dir, PATH: `${dir}:${process.env.PATH}`,
          MOCK_ACTION: action, MOCK_STATUS: String(status),
        },
        encoding: 'utf8',
        timeout: 5000,
      });
      assert.ifError(result.error);
      assert.equal(result.status, 0, result.stderr);
      assert.equal(result.stderr, '');
      const args = command => readFileSync(join(dir, `${command}.args`), 'utf8').split('\0').slice(0, -1);
      const folder = join(dir, 'Pictures/Screenshots');
      const file = join(folder, '2026-09-20_12-34-56.png');
      assert.deepEqual(args('grim'), ['-g', '10,20 300x400', '-']);
      assert.ok(existsSync(join(dir, 'slurp.args')));
      assert.deepEqual(args('wl-copy'), ['--type', 'image/png']);
      assert.deepEqual(args('tee'), [file]);
      assert.deepEqual(args('mkdir'), ['-p', folder]);
      assert.deepEqual(args('date'), ['+%Y-%m-%d_%H-%M-%S']);
      assert.deepEqual(args('notify-send'), [
        '--app-name', 'send-notification', '--category', 'info',
        '--action', 'default=Open folder', '-u', 'normal', '-i', 'dialog-information',
        '-t', '5000', '--', 'Screenshot saved', file,
      ]);
      assert.equal(existsSync(join(dir, 'cosmic-files.args')), opensFolder);
      if (opensFolder) assert.deepEqual(args('cosmic-files'), [folder]);
      assert.equal(existsSync(join(dir, 'Pictures')), false, 'no screenshot directories written');
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  });
}
