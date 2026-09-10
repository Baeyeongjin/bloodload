// Reviewed pixel correction: Valentino's third slash reintroduced a red arc
// after it was already gone in frame 7. Keep his body and silver blade intact.
const fs = require('node:fs/promises');
const path = require('node:path');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
(async () => {
  for (const motion of ['attack3', 'cast']) {
    const clip = `valentino_1_${motion}`;
    const file = path.join(root, `assets/anim/${clip}/8.png`);
    const backup = path.join(root, `build/qa/pixel-original/${clip}/8.png`);
    await fs.mkdir(path.dirname(backup), {recursive: true});
    try { await fs.copyFile(file, backup, require('node:fs').constants.COPYFILE_EXCL); }
    catch (e) { if (e.code !== 'EEXIST') throw e; }
    const {data, info} = await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject: true});
    let changed = 0;
    // Source-left outer arc, visually checked at 6x and at the runtime's 2x.
    // This box excludes the face, cape, hands and silver blade colors.
    for (let y = 14; y <= 40; y++) for (let x = 8; x <= 25; x++) {
      const i = (y * info.width + x) * 4;
      if (data[i + 3] && data[i] > 170 && data[i + 1] < 105 && data[i + 2] < 170) {
        data.fill(0, i, i + 4); changed++;
      }
    }
    await sharp(data, {raw: info}).png().toFile(file);
    console.log(`${clip}/8.png: removed ${changed} late arc pixels`);
  }
})().catch(e => { console.error(e); process.exitCode = 1; });
