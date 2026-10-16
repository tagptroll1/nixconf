const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { test } = require('node:test')
const vm = require('node:vm')
const logic = require('../shell/plugins/notifications/NotificationLogic.js')

const service = readFileSync(new URL('../shell/plugins/notifications/Service.qml', `file://${__filename}`), 'utf8')
const card = readFileSync(new URL('../shell/plugins/notifications/components/NotificationCard.qml', `file://${__filename}`), 'utf8')

function qmlFunction(source, name, context) {
  const match = source.match(new RegExp(`  function ${name}\\([^]*?\\n  }`))
  assert.ok(match, name)
  return vm.runInNewContext(`(${match[0]})`, context)
}

test('zero timeout stays persistent through delivery, storage and restore', () => {
  const context = {
    NotificationUrgency: { Low: 0, Normal: 1, Critical: 2 },
    lowPopupDuration: 5000, normalPopupDuration: 8000, maxPopupDuration: 30000
  }
  context.requestedDuration = qmlFunction(service, 'requestedDuration', context)
  const durationFor = qmlFunction(service, 'durationFor', context)
  for (const timeout of [-1, 0, 12000]) {
    const snapshot = logic.snapshotOf({ id: 7, urgency: 1, expireTimeout: timeout }, 100)
    const persisted = logic.persistablePopup(snapshot, '/state/images/').entry
    const restored = logic.parsePopupFiles(logic.serializePopup(persisted, 1), 1)[0]
    for (const entry of [snapshot, persisted, restored]) {
      assert.equal(entry.expireTimeout, timeout)
      assert.equal(durationFor(entry.urgency, entry.expireTimeout), timeout === 0 ? 0 : Math.max(8000, timeout))
    }
    assert.equal(logic.popupExpired(restored, durationFor(1, timeout), 100000), timeout !== 0)
    assert.equal(logic.historyRows('', [snapshot], 1)[0].expireTimeout, -1)
  }
  assert.equal(durationFor(0, 0), 0)
  assert.equal(durationFor(2, -1), 0)
  assert.equal(logic.popupExpired({ deadline: 500 }, 0, 100000), false)
  for (const timeout of [undefined, null, NaN, Infinity, -2]) {
    assert.equal(logic.snapshotOf({ expireTimeout: timeout }).expireTimeout, -1)
    assert.equal(logic.popupEntry({ expireTimeout: timeout }, 1).expireTimeout, -1)
  }
})

test('Lucide tint survives icon persistence and restore without tinting other images', () => {
  for (const role of ['appIcon', 'image']) {
    const snapshot = logic.snapshotOf({ id: 7, [role]: '/nix/store/assets/lucide/icons/bell.svg' }, 100)
    const persisted = logic.persistablePopup(snapshot, '/state/images/')
    assert.equal(logic.isLucideIcon(snapshot[role]), true)
    assert.equal(persisted.entry[role], `file:///state/images/100-7-${role}.lucide.svg`)
    const filename = persisted.copies[0].to.split('/').pop()
    assert.equal(filename.slice(0, filename.lastIndexOf('-')), logic.imageStem(snapshot))
    const restored = logic.parsePopupFiles(logic.serializePopup(persisted.entry, 1), 1)[0]
    assert.equal(logic.isLucideIcon(restored[role]), true)
    assert.deepEqual(logic.persistablePopup(restored, '/state/images/').copies, [])
  }
  for (const icon of ['/tmp/photo.png', '/tmp/bell.svg', 'file:///state/images/100-7-appIcon', 'bell']) {
    assert.equal(logic.isLucideIcon(icon), false)
  }
  assert.match(card, /layer.enabled: NotificationLogic.isLucideIcon\(root.smallIconSource\)/)
  assert.match(card, /layer.effect: MultiEffect \{\s+brightness: 1.0\s+colorization: 1.0\s+colorizationColor: Color.notifications.text/)
})

test('category survives snapshot, persistence, restore and history replay', () => {
  for (const category of ['info', 'warning', 'error']) {
    const snapshot = logic.snapshotOf({ id: 7, urgency: 1, hints: { category } }, 100)
    const persisted = logic.persistablePopup(snapshot, '/state/images/').entry
    const raw = logic.serializePopup(persisted, 1)
    assert.equal(snapshot.category, category)
    assert.equal(logic.parsePopupFiles(raw, 1)[0].category, category)
    assert.equal(logic.historyRows(raw, [], 1)[0].category, category)
    assert.equal(logic.historyRows('', [snapshot], 1)[0].category, category)
    assert.equal(persisted.urgency, 1)
  }
  assert.equal(logic.normalizeCategory(' WARNING '), 'warning')
  for (const category of [undefined, null, '', 'device.error', 'email', 42]) {
    assert.equal(logic.normalizeCategory(category), '')
  }
  assert.equal(logic.snapshotOf({}).category, '')
  assert.equal(logic.historyEntry({}, 1).category, '')
})

test('category-only replacements update popup without changing file identity', () => {
  const previous = logic.snapshotOf({ id: 7, hints: { category: 'info' } }, 100)
  const next = logic.replacementSnapshot({ id: 9, hints: { category: 'error' } }, 7, 100)
  assert.equal(logic.popupRowChanged(previous, next), true)
  assert.equal(logic.popupRowChanged(next, { ...next }), false)
  assert.equal(logic.popupFileName(previous), logic.popupFileName(next))
  assert.ok(logic.popupRoles().includes('category'))
  assert.ok(!logic.popupRoles().includes('glyph'))
  assert.ok(!logic.popupRoles().includes('execArgv'))
})

test('private hints are ignored and old persisted commands never enter rows', () => {
  const execArgv = '["bash","-c","touch /tmp/should-not-run"]'
  const snapshot = logic.snapshotOf({ hints: { 'omarchy-glyph': 'X', 'omarchy-exec-argv': execArgv } })
  assert.equal(snapshot.appIcon, '')
  const old = { id: 7, originalId: 7, glyph: '\udb80\udc9a', execArgv, timestamp: 100 }
  for (const entry of [snapshot, logic.historyEntry(old, 1), logic.popupEntry(old, 1),
    logic.persistablePopup(old, '/state/images/').entry,
    logic.parsePopupFiles(JSON.stringify(old), 1)[0]]) {
    assert.ok(!Object.hasOwn(entry, 'execArgv'))
    assert.ok(!Object.hasOwn(entry, 'glyph'))
  }
  assert.equal(logic.historyEntry(old, 1).appIcon, old.glyph)
  assert.equal(logic.historyEntry({ ...old, appIcon: 'app-icon' }, 1).appIcon, 'app-icon')
  assert.doesNotMatch(logic.serializePopup(old, 1), /execArgv|"glyph"/)
  assert.doesNotMatch(service + card, /omarchy-glyph|omarchy-exec-argv|execArgv/)
})

test('normal sender respects DND; legacy sender has no bypass', () => {
  for (const category of ['info', 'warning', 'error']) {
    assert.equal(logic.shouldBypassDnd({ appName: 'send-notification', urgency: 1, hints: { category } }, 2), false)
  }
  assert.equal(logic.shouldBypassDnd({ appName: 'omarchy-action', urgency: 2 }, 2), false)
  assert.equal(logic.shouldBypassDnd({ appName: 'notify-send', urgency: 2 }, 2), true)
  assert.equal(logic.shouldBypassDnd({ appName: 'notify-send', urgency: 1 }, 2), false)
  assert.equal(logic.isEphemeralApp('send-notification'), true)
  assert.equal(logic.isEphemeralApp('notify-send'), true)
  assert.equal(logic.isEphemeralApp('Vesktop'), false)
})

test('icon wrappers preserve emoji and theme names through persistence', () => {
  for (const value of ['\ud83d\udd25', '1\ufe0f\u20e3', 'dialog-information']) {
    const wrapped = 'image://icon/' + encodeURIComponent(value)
    const snapshot = logic.snapshotOf({ appIcon: wrapped, image: wrapped })
    const persisted = logic.persistablePopup({ appIcon: wrapped, image: wrapped }, '/state/images/')
    assert.equal(snapshot.appIcon, value)
    assert.equal(snapshot.image, value)
    assert.equal(persisted.entry.appIcon, value)
    assert.equal(persisted.entry.image, value)
    assert.deepEqual(persisted.copies, [])
  }
})

test('wrapped file images are copied; process-local images are dropped', () => {
  const entry = {
    originalId: 7, timestamp: 100, deadline: 900,
    appIcon: 'image://icon/' + encodeURIComponent('/tmp/app icon.png'),
    image: 'image://icon/' + encodeURIComponent('file:///tmp/image%20name.png')
  }
  const persisted = logic.persistablePopup(entry, '/state/images/')
  assert.deepEqual(persisted.copies, [
    { from: '/tmp/app icon.png', to: '/state/images/100-7-appIcon' },
    { from: '/tmp/image name.png', to: '/state/images/100-7-image' }
  ])
  assert.equal(persisted.entry.deadline, 900)
  assert.equal(persisted.entry.image, 'file:///state/images/100-7-image')
  assert.deepEqual(logic.persistablePopup(persisted.entry, '/state/images/').copies, [])
  assert.equal(logic.persistablePopup({ image: 'image://qsimage/123' }, '/state/images/').entry.image, '')
})

test('text icon classification includes ASCII keycap emoji, excludes paths and names', () => {
  for (const value of ['\ud83d\udd25', '\udb80\udc9a', '1\ufe0f\u20e3', '#\u20e3', '*\ufe0f\u20e3']) {
    assert.equal(logic.isTextIcon(value), true, value)
  }
  for (const value of ['1', '#', 'dialog-warning', '/tmp/\ud83d\udd25.png', 'file:///tmp/image.png', 'two words']) {
    assert.equal(logic.isTextIcon(value), false, value)
  }
})

test('card gives explicit text image precedence over unrelated app icon', () => {
  const context = {
    NotificationLogic: logic,
    Quickshell: { iconPath: name => 'theme:' + name },
    Util: { fileUrl: path => 'file://' + path }
  }
  context.iconSource = qmlFunction(card, 'iconSource', context)
  for (const image of ['\ud83d\udd25', '1\ufe0f\u20e3']) {
    context.imageName = image
    context.appIconName = 'unrelated-app'
    for (const [name, expected] of [['smallIconSource', ''], ['iconText', image]]) {
      const expression = card.match(new RegExp(`readonly property string ${name}: ([^]*?)(?=\\n  readonly)`))[1]
      assert.equal(vm.runInNewContext(expression, context), expected)
    }
  }
  assert.equal(context.iconSource('image://icon/' + encodeURIComponent('\ud83d\udd25')), '')
  assert.equal(context.iconSource('/tmp/icon.png'), 'file:///tmp/icon.png')
})

test('live standard default action remains callable; restored actions never execute', () => {
  for (const restored of [false, true]) {
    let invoked = 0
    let dismissed = 0
    const context = {
      popupModel: { count: 1, get: () => ({ originalId: 7, execArgv: '["evil"]' }) },
      isRestoredRow: () => restored,
      liveRefs: { 7: { actions: [{ identifier: 'default', invoke: () => invoked++ }] } },
      focusApp: () => {},
      dismissPopup: () => dismissed++
    }
    qmlFunction(service, 'invokePopupDefault', context)(0)
    assert.equal(invoked, restored ? 0 : 1)
    assert.equal(dismissed, 1)
  }
})

test('ephemeral sender never launches focus process', () => {
  const focusAppProc = { running: false }
  const focus = qmlFunction(service, 'focusApp', { NotificationLogic: logic, focusAppProc })
  focus({ app: 'send-notification' })
  focus({ app: 'notify-send' })
  assert.deepEqual(focusAppProc, { running: false })
})
