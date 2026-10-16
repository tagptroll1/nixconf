const assert = require('node:assert/strict')
const { readFileSync } = require('node:fs')
const { test } = require('node:test')
const vm = require('node:vm')

// QML's `.pragma library` line is not JavaScript; the rest runs as is.
const source = readFileSync(`${__dirname}/../shell/plugins/stagedock/DockLayout.js`, 'utf8')
const layout = vm.createContext({})
vm.runInContext(source.replace(/^\.pragma library\s*$/m, ''), layout)

// Results come from the vm realm; deepEqual also compares prototypes.
const plain = (value) => JSON.parse(JSON.stringify(value))

const gap = 8
const mini = 44

function bottoms(list, heights, tops) {
  return list.map((d) => ({ top: tops[d.id], bottom: tops[d.id] + heights[d.id] }))
    .sort((a, b) => a.top - b.top)
}

function assertNoOverlap(spans) {
  for (let i = 1; i < spans.length; i++) assert.ok(spans[i].top >= spans[i - 1].bottom, JSON.stringify(spans))
}

test('packEdge centres tabs on their y when they fit', () => {
  const list = [{ id: 1, y: 100 }, { id: 2, y: 400 }]
  const { tops, compact } = layout.packEdge(list, { 1: 44, 2: 76 }, 1440, gap, mini)
  assert.deepEqual(plain(tops), { 1: 78, 2: 362 })
  assert.deepEqual(plain(compact), {})
})

test('packEdge keeps tabs near the bottom on screen and apart', () => {
  const list = [{ id: 1, y: 1420 }, { id: 2, y: 1430 }]
  const heights = { 1: 76, 2: 76 }
  const { tops } = layout.packEdge(list, heights, 1440, gap, mini)
  const spans = bottoms(list, heights, tops)
  assertNoOverlap(spans)
  assert.ok(spans[spans.length - 1].bottom <= 1440)
})

test('packEdge stacks five tabs upward off the screen bottom', () => {
  const list = [1, 2, 3, 4, 5].map((id) => ({ id, y: 1400 }))
  const heights = { 1: 44, 2: 44, 3: 44, 4: 44, 5: 44 }
  const { tops } = layout.packEdge(list, heights, 1440, gap, mini)
  const spans = bottoms(list, heights, tops)
  assertNoOverlap(spans)
  assert.equal(spans[spans.length - 1].bottom, 1440)
})

test('packEdge closes gaps, then folds from the bottom, when the edge is too short', () => {
  const list = [{ id: 1, y: 0 }, { id: 2, y: 100 }, { id: 3, y: 200 }]
  const heights = { 1: 100, 2: 100, 3: 100 }

  const tight = layout.packEdge(list, heights, 300, gap, mini)
  assert.deepEqual(plain(tight.tops), { 1: 0, 2: 100, 3: 200 })
  assert.deepEqual(plain(tight.compact), {})

  const folded = layout.packEdge(list, heights, 250, gap, mini)
  assert.deepEqual(plain(folded.compact), { 3: true })
  assertNoOverlap(bottoms(list, { ...heights, 3: mini }, folded.tops))
})

test('restTop prefers a pinned top over the packed one', () => {
  assert.equal(layout.restTop({ 2: { top: 50, y: 72 } }, { 1: 10, 2: 20 }, 2), 50)
  assert.equal(layout.restTop({}, { 1: 10 }, 1), 10)
  assert.equal(layout.restTop({}, {}, 3), 0)
})

test('neighbours lists the other tabs on the same monitor edge, top to bottom', () => {
  const dock = { id: 1, monitor: 'DP-1', edge: 'right' }
  const tabs = [
    { id: 1, monitor: 'DP-1', edge: 'right', top: 100, height: 44 },
    { id: 2, monitor: 'DP-1', edge: 'right', top: 300, height: 44 },
    { id: 3, monitor: 'DP-1', edge: 'right', top: 0, height: 76 },
    { id: 4, monitor: 'DP-1', edge: 'left', top: 50, height: 44 },
    { id: 5, monitor: 'HDMI-A-1', edge: 'right', top: 50, height: 44 }
  ]
  assert.deepEqual(plain(layout.neighbours(dock, tabs).map((o) => o.id)), [3, 2])
  assert.deepEqual(plain(layout.neighbours(null, tabs)), [])
})

function startDrag(top, height, obs, bottom) {
  const home = obs.filter((o) => o.top < top).length
  return { top, height, obs, home, slot: home, bottom }
}

test('dragging down past a tab slides it into the room above', () => {
  const obs = [{ id: 2, top: 100, height: 44 }]
  let drag = startDrag(40, 44, obs, 1440)

  // Centre short of the commit point: nothing passes.
  let next = layout.move(drag, 80, 1396, gap, 0.75)
  assert.equal(next.slot, 0)
  assert.equal(next.obs, obs)

  next = layout.move(drag, 120, 1396, gap, 0.75)
  assert.equal(next.slot, 1)
  assert.equal(next.obs[0].passed, 120 - gap - 44)

  // Back up far enough sends it home.
  drag = { ...drag, top: next.top, obs: next.obs, slot: next.slot }
  next = layout.move(drag, 40, 1396, gap, 0.75)
  assert.equal(next.slot, 0)
  assert.equal(next.obs[0].passed, undefined)
})

test('move clamps the dragged tab to its edge', () => {
  const drag = startDrag(40, 44, [], 1440)
  assert.equal(layout.move(drag, -30, 1396, gap, 0.75).top, 0)
  assert.equal(layout.move(drag, 2000, 1396, gap, 0.75).top, 1396)
})

test('landing puts the tab in its gap and reports every passed tab', () => {
  const obs = [{ id: 2, top: 100, height: 44, passed: 30 }, { id: 3, top: 300, height: 45 }]
  const moves = layout.landing({ top: 150, height: 44, obs, slot: 1 }, 1, 1396, gap)
  assert.deepEqual(plain(moves), [
    { id: 1, top: 150, y: 172 },
    { id: 2, top: 30, y: 52 }
  ])

  // Dropped overlapping the next tab: pulled back one gap above it.
  const odd = layout.landing({ top: 280, height: 45, obs: [{ id: 3, top: 300, height: 44 }], slot: 0 }, 1, 1396, gap)
  assert.deepEqual(plain(odd[0]), { id: 1, top: 247, y: 269 })
})
