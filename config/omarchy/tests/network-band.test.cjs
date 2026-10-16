const assert = require('node:assert/strict')
const { test } = require('node:test')
const model = require('../shell/plugins/panels/network/Model.js')

test('connected Wi-Fi device and its profile UUID from device status', () => {
  const text = [
    'enp12s0:ethernet:connected:3f5f0047-707f-3eb2-8802-e992e7db32ec',
    'lo:loopback:connected (externally):1795e729-90ef-470e-82fa-4a3df4935c21',
    'wlp13s0:wifi:connected:9b1c2d3e-0000-4000-8000-000000000001',
    'p2p-dev-wlp13s0:wifi-p2p:disconnected:'
  ].join('\n')
  assert.deepEqual(model.wifiDeviceFrom(text), { device: 'wlp13s0', uuid: '9b1c2d3e-0000-4000-8000-000000000001' })
  assert.equal(model.wifiDeviceFrom('wlp13s0:wifi:disconnected:\n'), null)
  assert.equal(model.wifiDeviceFrom('wlp13s0:wifi:connecting (configuring):u\n'), null)
})

test('nm band values map both ways, empty is auto', () => {
  for (const [nm, band] of [['bg', '2.4'], ['a', '5'], ['6GHz', '6'], ['', 'auto']]) {
    assert.equal(model.bandFromNm(nm), band)
    assert.equal(model.nmFromBand(band), nm)
  }
})

test('frequency boundaries match formatHeaderFreq', () => {
  for (const mhz of ['2412 MHz', '5500 MHz', '5925 MHz', '6115 MHz', '7124 MHz', '4899 MHz', '60480 MHz']) {
    const band = model.bandForFreq(mhz)
    const header = model.formatHeaderFreq(parseInt(mhz, 10))
    assert.equal(band ? band + 'ghz' : '', ['2.4ghz', '5ghz', '6ghz'].includes(header) ? header : '')
  }
  assert.equal(model.bandForFreq('5924 MHz'), '5')
  assert.equal(model.bandForFreq('5925 MHz'), '6')
})

test('SSID containing colons is rejoined; in-use row gives the live link', () => {
  const rows = model.wifiListRows([
    ' :2462 MHz:Home:Net',
    '*:5500 MHz:Home:Net',
    ' :6115 MHz:Home:Net',
    ' :5180 MHz:Home',
    ' :2437 MHz:Neighbour',
    ''
  ].join('\n'))
  const link = model.linkFrom(rows)
  assert.deepEqual(link, { ssid: 'Home:Net', freq: '5500 MHz' })
  const current = model.bandForFreq(link.freq)
  assert.deepEqual(model.availableBands(rows, link.ssid, current), ['2.4', '5', '6'])
})

test('current band is kept even when the scan cache missed it', () => {
  const rows = model.wifiListRows(' :2462 MHz:Home\n')
  assert.deepEqual(model.availableBands(rows, 'Home', '6'), ['2.4', '6'])
})

test('no in-use row means no link', () => {
  assert.equal(model.linkFrom(model.wifiListRows(' :5500 MHz:Bergen Kino 5G\n')), null)
})
