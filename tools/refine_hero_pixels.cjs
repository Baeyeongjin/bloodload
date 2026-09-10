// Keep the original silhouettes and alpha byte-for-byte. Correct only near-
// duplicate shading colors that flicker away from each costume's source palette.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const anim = path.join(root, 'assets/anim');
const backup = path.join(root, 'build/qa/pixel-original');
const skins = ['valentino_1', 'demon_king', 'dragon', 'shadow', 'emperor', 'grim', 'abyss', 'hawaii', 'pink'];
const apply = process.argv.includes('--apply');
async function read(file) {
  return sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject: true});
}
function colors(data) {
  const result = new Map();
  for (let i = 0; i < data.length; i += 4) {
    if (!data[i + 3]) continue;
    const key = `${data[i]},${data[i + 1]},${data[i + 2]}`;
    result.set(key, (result.get(key) || 0) + 1);
  }
  return result;
}
async function main() {
  const report = [];
  const dirs = await fs.readdir(anim);
  for (const skin of skins) {
    const idle = await read(path.join(anim, `${skin}_idle/0.png`));
    const palette = [...colors(idle.data).keys()].map(c => c.split(',').map(Number));
    for (const dir of dirs.filter(d => d.startsWith(`${skin}_`) && !d.endsWith('_idle'))) {
      for (const name of (await fs.readdir(path.join(anim, dir))).filter(n => /^\d+\.png$/.test(n))) {
        const file = path.join(anim, dir, name);
        const original = path.join(backup, dir, name);
        const {data, info} = await read(file);
        const counts = colors(data);
        const output = Buffer.from(data);
        let changed = 0;
        for (let i = 0; i < data.length; i += 4) {
          if (!data[i + 3]) continue;
          const rgb = [...data.subarray(i, i + 3)];
          if (counts.get(rgb.join(',')) > 2) continue;
          // New attack-light colors have no close source-palette neighbor and
          // stay untouched. No color blending or silhouette interpolation.
          let best = 18 * 18, target;
          for (const color of palette) {
            const d = color.reduce((sum, v, c) => sum + (v - rgb[c]) ** 2, 0);
            if (d < best) { best = d; target = color; }
          }
          if (target && best > 0) { output.set(target, i); changed++; }
        }
        if (!changed) continue;
        for (let i = 3; i < data.length; i += 4) {
          if (output[i] !== data[i]) throw Error(`Alpha changed: ${dir}/${name}`);
        }
        report.push({clip: dir, frame: name, pixels: changed});
        if (apply) {
          await fs.mkdir(path.dirname(original), {recursive: true});
          try { await fs.copyFile(file, original, require('node:fs').constants.COPYFILE_EXCL); }
          catch (e) { if (e.code !== 'EEXIST') throw e; }
          await sharp(output, {raw: info}).png().toFile(file);
        }
      }
    }
  }
  const summary = {applied: apply, files: report.length, pixels: report.reduce((n, row) => n + row.pixels, 0), edits: report};
  await fs.mkdir(path.join(root, 'build/qa'), {recursive: true});
  await fs.writeFile(path.join(root, 'build/qa/hero-pixel-refinement.json'), JSON.stringify(summary, null, 2));
  console.log(JSON.stringify({applied: apply, files: summary.files, pixels: summary.pixels}));
}
main().catch(e => { console.error(e); process.exitCode = 1; });
