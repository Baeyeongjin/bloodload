// Targeted original-pixel edits only. Run `node tools/refine_vfx_pixels.cjs --write`.
// Originals remain in build/qa/pixel-original; repeated runs read that backup.
const fs = require('fs');
const path = require('path');
const assert = require('assert/strict');
const sharp = require('C:/Users/kpo02/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const root = path.resolve(__dirname, '..');
const qa = path.join(root, 'build/qa');
const write = process.argv.includes('--write');
const clips = ['fx_cleave_wave', 'fx_sk_rare_wave', 'fx_sk_uncommon_field'];

function stats(frame) {
  let area = 0, xsum = 0, ysum = 0;
  const box = [frame.width, frame.height, -1, -1];
  for (let y = 0; y < frame.height; y++) for (let x = 0; x < frame.width; x++) {
    if (!frame.data[(y * frame.width + x) * 4 + 3]) continue;
    area++; xsum += x; ysum += y;
    box[0] = Math.min(box[0], x); box[1] = Math.min(box[1], y);
    box[2] = Math.max(box[2], x); box[3] = Math.max(box[3], y);
  }
  return {area, box, center: area ? [xsum / area, ysum / area] : null};
}

function copyPixels(frame, destination) {
  const out = {width: frame.width, height: frame.height, data: Buffer.alloc(frame.data.length)};
  for (let y = 0; y < frame.height; y++) for (let x = 0; x < frame.width; x++) {
    const i = (y * frame.width + x) * 4;
    if (!frame.data[i + 3]) continue;
    const at = destination(x, y);
    if (!at) continue;
    assert(at[0] >= 0 && at[0] < frame.width && at[1] >= 0 && at[1] < frame.height);
    frame.data.copy(out.data, (at[1] * frame.width + at[0]) * 4, i, i + 4);
  }
  return out;
}

function fallingDrops(frame, distance) {
  const offsets = new Map(), visited = new Set();
  for (let p = 0; p < frame.width * frame.height; p++) {
    if (visited.has(p) || !frame.data[p * 4 + 3]) continue;
    const component = [p]; visited.add(p);
    let bottom = 0;
    for (let j = 0; j < component.length; j++) {
      const at = component[j], x = at % frame.width, y = Math.floor(at / frame.width);
      bottom = Math.max(bottom, y);
      for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
        if (nx < 0 || nx >= frame.width || ny < 0 || ny >= frame.height) continue;
        const next = ny * frame.width + nx;
        if (!visited.has(next) && frame.data[next * 4 + 3]) {
          visited.add(next); component.push(next);
        }
      }
    }
    // Keep each original droplet intact and retain the clip's original ground row.
    for (const at of component) offsets.set(at, Math.min(distance, 60 - bottom));
  }
  return copyPixels(frame, (x, y) => [x, y + offsets.get(y * frame.width + x)]);
}

async function collapsingRemnant(frame, height) {
  const [x0, y0, x1, y1] = stats(frame).box;
  const cropped = await sharp(frame.data, {raw: {width: frame.width, height: frame.height, channels: 4}})
    .extract({left: x0, top: y0, width: x1 - x0 + 1, height: y1 - y0 + 1})
    .resize(x1 - x0 + 1, height, {kernel: 'nearest', fit: 'fill'}).raw().toBuffer();
  const out = {width: frame.width, height: frame.height, data: Buffer.alloc(frame.data.length)};
  for (let y = 0; y < height; y++) {
    cropped.copy(out.data, ((47 - height + 1 + y) * frame.width + x0) * 4,
      y * (x1 - x0 + 1) * 4, (y + 1) * (x1 - x0 + 1) * 4);
  }
  return out;
}

(async () => {
  const report = [], sheet = [], cell = 192, rowHeight = 154;
  for (let row = 0; row < clips.length; row++) {
    const clip = clips[row], source = path.join(root, 'assets/anim', clip);
    const backup = path.join(qa, 'pixel-original', clip);
    if (!fs.existsSync(backup)) {
      fs.mkdirSync(backup, {recursive: true});
      for (const file of fs.readdirSync(source).filter(n => /^\d+\.png$/.test(n)))
        fs.copyFileSync(path.join(source, file), path.join(backup, file));
    }
    const names = fs.readdirSync(backup).filter(n => /^\d+\.png$/.test(n)).sort((a, b) => parseInt(a) - parseInt(b));
    const before = [];
    for (const name of names) {
      const {data, info} = await sharp(path.join(backup, name)).ensureAlpha().raw().toBuffer({resolveWithObject: true});
      before.push({data, width: info.width, height: info.height});
    }
    const after = before.map(f => ({...f, data: Buffer.from(f.data)}));
    if (clip === 'fx_cleave_wave') {
      after[7] = copyPixels(before[6], (x, y) => x >= 86 ? [x, y] : null);
      after[8] = copyPixels(before[6], (x, y) => x >= 92 ? [x, y] : null);
    } else if (clip === 'fx_sk_rare_wave') {
      after[7] = fallingDrops(before[7], 9);
      after[8] = fallingDrops(before[8], 17);
    } else {
      after[7] = await collapsingRemnant(before[7], 14);
      after[8] = await collapsingRemnant(before[8], 6);
    }
    const palette = new Set();
    for (const frame of before) for (let i = 0; i < frame.data.length; i += 4)
      if (frame.data[i + 3]) palette.add(frame.data.readUInt32LE(i));
    for (let f = 0; f < after.length; f++) {
      assert.equal(after[f].width, before[f].width); assert.equal(after[f].height, before[f].height);
      for (let i = 0; i < after[f].data.length; i += 4)
        if (after[f].data[i + 3]) assert(palette.has(after[f].data.readUInt32LE(i)), `${clip}: new color`);
      if (f < 7) assert(after[f].data.equals(before[f].data), `${clip}: changed an earlier frame`);
      if (write && f >= 7)
        await sharp(after[f].data, {raw: {width: after[f].width, height: after[f].height, channels: 4}})
          .png().toFile(path.join(source, names[f]));
    }
    const b = before.map(stats), a = after.map(stats);
    if (clip === 'fx_cleave_wave') {
      assert(a[6].area > a[7].area && a[7].area > a[8].area && a[8].area > 0);
    } else if (clip === 'fx_sk_rare_wave') {
      for (const f of [7, 8]) assert.equal(a[f].area, b[f].area, 'A droplet lost or overlapped pixels');
      assert(a[7].center[1] >= a[6].center[1] && a[8].center[1] > a[7].center[1]);
      assert(Math.max(...a.map(s => s.box[3])) === 60);
    } else {
      assert(a[6].area > a[7].area && a[7].area > a[8].area);
      for (const f of [7, 8]) assert.equal(a[f].box[3], 47);
    }
    report.push({clip, size: [before[0].width, before[0].height], palette: 'original RGBA only', before: b, after: a});
    for (const [variant, frames] of [['BEFORE', before], ['AFTER', after]]) {
      const top = (row * 2 + (variant === 'AFTER' ? 1 : 0)) * rowHeight;
      sheet.push({input: Buffer.from(`<svg width="1728" height="24"><text x="8" y="17" fill="#eee" font-family="sans-serif" font-size="15">${clip} / ${variant} / ORIGINAL PIXELS</text></svg>`), left: 0, top});
      for (let f = 0; f < frames.length; f++) {
        const frame = frames[f];
        const img = await sharp(frame.data, {raw: {width: frame.width, height: frame.height, channels: 4}})
          .resize(frame.width * 2, frame.height * 2, {kernel: 'nearest'}).png().toBuffer();
        sheet.push({input: img, left: f * cell + (cell - frame.width * 2) / 2, top: top + 24});
      }
    }
  }
  fs.writeFileSync(path.join(qa, 'vfx-pixel-retouch.json'), JSON.stringify(report, null, 2));
  await sharp({create: {width: 1728, height: clips.length * 2 * rowHeight, channels: 4, background: '#252731'}})
    .composite(sheet).png().toFile(path.join(qa, 'vfx-pixel-retouch.png'));
  for (const r of report) console.log(r.clip, 'tail area', r.before.slice(6).map(s => s.area), '->', r.after.slice(6).map(s => s.area),
    'tail Y', r.before.slice(6).map(s => s.center?.[1].toFixed(1)), '->', r.after.slice(6).map(s => s.center?.[1].toFixed(1)));
  console.log(write ? 'WROTE 6 TARGETED FRAMES; original dimensions/palette/anchors verified' : 'DRY RUN ONLY');
})().catch(error => {console.error(error); process.exitCode = 1;});
