// REJECTED STUDY 2026-09-08: production Foe uses the original animation again.
// Pixel-authored orc choreography. No generated imagery, whole-sprite transforms,
// antialiasing or palette interpolation. Source files are never overwritten.
// Run with Node and the installed sharp module on NODE_PATH.
const fs = require('node:fs/promises');
const path = require('node:path');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const sharp = require('sharp');
const root = path.resolve(__dirname, '..');
const qa = path.join(root, 'build/qa/orc-authored');
const W = 64, H = 64, O = 16;
let source, palette, head, torso, frontFoot, backFoot;

const rgba = c => c.split(',').map(Number);
const C = {
  ink: rgba('1,5,1,255'), dark: rgba('1,3,4,255'),
  skinDark: rgba('54,72,31,255'), skinShade: rgba('76,103,37,255'),
  skin: rgba('139,164,78,255'), skinMid: rgba('165,183,104,255'),
  skinLight: rgba('197,215,129,255'), skinTop: rgba('208,215,132,255'),
  leg: rgba('87,88,37,255'), legLight: rgba('142,149,83,255'),
  leather: rgba('92,79,48,255'), leatherShade: rgba('75,63,30,255'),
  wood: rgba('97,66,40,255'), woodLight: rgba('117,79,52,255'),
  woodTop: rgba('141,102,70,255'), woodShade: rgba('87,61,38,255'),
  woodDark: rgba('60,41,28,255'),
};
const key = color => color.join(',');
function pixel(image, x, y, color) {
  x = Math.round(x) + O; y = Math.round(y) + O;
  assert(x >= 0 && x < W && y >= 0 && y < H, `Clipped pixel ${x},${y}`);
  image.set(color, (y * W + x) * 4);
}
function polygon(image, points, color) {
  const minX = Math.floor(Math.min(...points.map(p => p[0])));
  const maxX = Math.ceil(Math.max(...points.map(p => p[0])));
  const minY = Math.floor(Math.min(...points.map(p => p[1])));
  const maxY = Math.ceil(Math.max(...points.map(p => p[1])));
  for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) {
    let inside = false;
    for (let i = 0, j = points.length - 1; i < points.length; j = i++) {
      const a = points[i], b = points[j];
      if ((a[1] > y + .5) !== (b[1] > y + .5) &&
        x + .5 < (b[0] - a[0]) * (y + .5 - a[1]) / (b[1] - a[1]) + a[0]) inside = !inside;
    }
    if (inside) pixel(image, x, y, color);
  }
}
function line(image, a, b, color) {
  let x = Math.round(a[0]), y = Math.round(a[1]);
  const bx = Math.round(b[0]), by = Math.round(b[1]);
  const dx = Math.abs(bx - x), dy = -Math.abs(by - y), sx = x < bx ? 1 : -1, sy = y < by ? 1 : -1;
  let error = dx + dy;
  while (true) {
    pixel(image, x, y, color);
    if (x === bx && y === by) break;
    const e2 = 2 * error;
    if (e2 >= dy) { error += dy; x += sx; }
    if (e2 <= dx) { error += dx; y += sy; }
  }
}
function limb(image, a, b, widthA, widthB, colors) {
  const dx = b[0] - a[0], dy = b[1] - a[1], length = Math.hypot(dx,dy) || 1;
  const normal = [-dy / length, dx / length];
  const points = (wa, wb) => [[a[0]+normal[0]*wa,a[1]+normal[1]*wa],
    [b[0]+normal[0]*wb,b[1]+normal[1]*wb], [b[0]-normal[0]*wb,b[1]-normal[1]*wb],
    [a[0]-normal[0]*wa,a[1]-normal[1]*wa]];
  polygon(image, points(widthA / 2 + 1, widthB / 2 + 1), C.ink);
  polygon(image, points(widthA / 2, widthB / 2), colors[0]);
  line(image, [a[0]-1,a[1]], [b[0]-1,b[1]], colors[1]);
  if (colors[2]) line(image, [a[0],a[1]], [Math.round((a[0]+b[0])/2),Math.round((a[1]+b[1])/2)], colors[2]);
}
function patch(points, condition = () => true) {
  return points.filter(([x,y]) => condition(x,y)).map(([x,y]) => ({x,y,c:[...source.subarray((y*32+x)*4,(y*32+x)*4+4)]})).filter(p=>p.c[3]);
}
function rectPoints(x0,y0,x1,y1) {
  const points=[];
  for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++) points.push([x,y]);
  return points;
}
function stamp(image, pixels, dx=0, dy=0) {
  for(const p of pixels) pixel(image,p.x+dx,p.y+dy,p.c);
}
function sourceGuard() {
  const result=Buffer.alloc(W*H*4);
  stamp(result, patch(rectPoints(0,0,31,31)));
  return result;
}

// Every pose specifies its weight-bearing feet, hip, chest, elbow, grip and club
// tip independently. The head is a byte-for-byte copy of the original face.
const poses = {
  ready: {ch:[0,0], hip:[0,0], head:[0,0], fk:[12,26], ff:[0,0], bk:[23,27], bf:[0,0], elbow:[26,17], grip:[25,22], tip:[3,14]},
  brace: {ch:[0,1], hip:[0,0], head:[0,1], fk:[11,27], ff:[0,1], bk:[24,28], bf:[1,0], elbow:[27,18], grip:[25,23], tip:[3,16]},
  draw: {ch:[1,0], hip:[0,0], head:[1,0], fk:[13,26], ff:[1,0], bk:[25,27], bf:[1,0], elbow:[28,17], grip:[25,15], tip:[24,-7]},
  coil: {ch:[2,0], hip:[1,0], head:[1,0], fk:[13,25], ff:[1,-2], bk:[26,27], bf:[1,0], elbow:[28,14], grip:[23,9], tip:[44,0]},
  plant: {ch:[0,1], hip:[-1,0], head:[0,1], fk:[8,27], ff:[-3,1], bk:[23,27], bf:[1,0], elbow:[28,11], grip:[25,9], tip:[18,-13]},
  swing: {ch:[-1,1], hip:[-1,0], head:[-1,1], fk:[7,27], ff:[-4,1], bk:[23,26], bf:[1,0], elbow:[19,10], grip:[14,9], tip:[-6,0]},
  contact: {ch:[-3,2], hip:[-2,1], head:[-3,2], fk:[7,27], ff:[-4,1], bk:[22,26], bf:[1,-1], elbow:[16,17], grip:[10,19], tip:[-12,20]},
  follow: {ch:[-3,3], hip:[-2,1], head:[-3,3], fk:[6,28], ff:[-4,1], bk:[23,27], bf:[1,0], elbow:[16,20], grip:[11,23], tip:[-9,28]},
  recoil: {ch:[-2,3], hip:[-1,1], head:[-2,3], fk:[8,28], ff:[-3,1], bk:[24,27], bf:[1,0], elbow:[18,21], grip:[13,24], tip:[-7,27]},
  recover: {ch:[-1,2], hip:[-1,0], head:[-1,2], fk:[10,27], ff:[-2,1], bk:[24,27], bf:[1,0], elbow:[23,21], grip:[18,23], tip:[-3,20]},
  settle: {ch:[0,1], hip:[0,0], head:[0,1], fk:[12,27], ff:[0,1], bk:[24,27], bf:[0,0], elbow:[26,19], grip:[23,23], tip:[1,16]},
  crouch: {ch:[0,3], hip:[0,1], head:[0,3], fk:[10,28], ff:[-2,1], bk:[26,28], bf:[2,0], elbow:[27,21], grip:[23,25], tip:[2,17]},
  gather: {ch:[1,4], hip:[1,2], head:[1,4], fk:[10,29], ff:[-2,1], bk:[27,29], bf:[2,0], elbow:[28,22], grip:[22,22], tip:[11,3]},
  lift: {ch:[1,2], hip:[1,1], head:[1,2], fk:[11,28], ff:[-2,1], bk:[26,27], bf:[2,0], elbow:[28,17], grip:[24,14], tip:[28,-8]},
  raise: {ch:[1,0], hip:[1,0], head:[1,0], fk:[11,27], ff:[-2,1], bk:[25,27], bf:[2,0], elbow:[28,10], grip:[25,6], tip:[42,-6]},
  overhead: {ch:[0,-1], hip:[0,0], head:[0,-1], fk:[10,26], ff:[-2,1], bk:[25,26], bf:[2,0], elbow:[27,5], grip:[24,2], tip:[45,0]},
  hold: {ch:[0,-1], hip:[0,0], head:[0,-1], fk:[10,26], ff:[-2,1], bk:[25,26], bf:[2,0], elbow:[27,5], grip:[24,2], tip:[45,1]},
  release: {ch:[0,0], hip:[0,0], head:[0,0], fk:[10,27], ff:[-2,1], bk:[25,27], bf:[2,0], elbow:[25,10], grip:[21,8], tip:[8,-11]},
  descend: {ch:[-2,2], hip:[-1,1], head:[-2,2], fk:[8,28], ff:[-3,1], bk:[26,28], bf:[2,0], elbow:[16,12], grip:[10,15], tip:[-12,11]},
  slam: {ch:[-3,4], hip:[-1,2], head:[-3,4], fk:[8,29], ff:[-4,1], bk:[26,29], bf:[2,0], elbow:[16,17], grip:[11,18], tip:[-7,28]},
  crush: {ch:[-3,5], hip:[-1,2], head:[-3,5], fk:[8,29], ff:[-4,1], bk:[27,29], bf:[2,0], elbow:[17,21], grip:[11,21], tip:[-9,28]},
  rest: {ch:[-2,5], hip:[0,2], head:[-2,5], fk:[9,29], ff:[-4,1], bk:[27,29], bf:[2,0], elbow:[18,23], grip:[12,23], tip:[-9,28]},
  pry: {ch:[-2,3], hip:[0,1], head:[-2,3], fk:[10,28], ff:[-3,1], bk:[26,28], bf:[2,0], elbow:[21,22], grip:[15,23], tip:[-6,28]},
  rise: {ch:[-1,2], hip:[0,1], head:[-1,2], fk:[11,27], ff:[-2,1], bk:[25,27], bf:[1,0], elbow:[24,20], grip:[19,21], tip:[-2,21]},
};
const clips = [
  {name:'orc_attack_v2', poses:['source','brace','draw','coil','plant','swing','contact','follow','recoil','recover','settle','source'],
    milliseconds:Array(12).fill(35), contact:6, recovery:8},
  {name:'orc_special_v2', poses:['source','brace','crouch','gather','lift','raise','overhead','hold','release','descend','slam','crush','rest','pry','rise','recover','settle','source'],
    milliseconds:Array.from({length:18},(_,i)=>i<7?106.25:i===7?156.25:50), contact:10, recovery:13},
];

function bodyPoint(p, x, y) {
  const t=Math.max(0,Math.min(1,(y-8)/16));
  return [x+Math.round(p.ch[0]*(1-t)+p.hip[0]*t),y+Math.round(p.ch[1]*(1-t)+p.hip[1]*t)];
}
function drawLegs(image,p) {
  // Original bare feet survive intact; thighs/calves articulate into them.
  limb(image,[22+p.hip[0],23+p.hip[1]],p.bk,5,4,[C.leg,C.legLight]);
  limb(image,p.bk,[23+p.bf[0],30+p.bf[1]],4,3,[C.leg,C.legLight]);
  stamp(image,backFoot,p.bf[0],p.bf[1]);
  limb(image,[16+p.hip[0],23+p.hip[1]],p.fk,5,4,[C.skinDark,C.legLight]);
  limb(image,p.fk,[11+p.ff[0],29+p.ff[1]],4,3,[C.leg,C.legLight]);
  stamp(image,frontFoot,p.ff[0],p.ff[1]);
}
function drawTorso(image,p) {
  for(const dot of torso) {
    const at=bodyPoint(p,dot.x,dot.y);
    const previous=bodyPoint(p,dot.x,dot.y-1);
    // Raising the shoulders one row above the hip opens a raster row. Continue
    // that row's hand-authored chest pixels so the extended torso stays solid.
    for(let y=previous[1]+1;y<at[1];y++) pixel(image,at[0],y,dot.c);
    pixel(image,at[0],at[1],dot.c);
  }
}
function drawArm(image,p,back=false) {
  const shoulder=bodyPoint(p,back?17:23,back?12:11);
  const elbow=back?[p.elbow[0]-4,p.elbow[1]+1]:p.elbow;
  const hand=back?[p.grip[0]-3,p.grip[1]-1]:p.grip;
  const colors=back?[C.skinDark,C.skinShade]:[C.skin,C.skinLight,C.skinTop];
  limb(image,shoulder,elbow,back?3:5,back?3:4,colors);
  limb(image,elbow,hand,back?3:4,3,colors);
  // One dark elbow crease reads as flexion at this native pixel density.
  if(!back) line(image,[elbow[0],elbow[1]],[elbow[0]+1,elbow[1]],C.skinShade);
}
function drawClub(image,p) {
  const h=p.grip,t=p.tip, length=Math.hypot(t[0]-h[0],t[1]-h[1]);
  const d=[(t[0]-h[0])/length,(t[1]-h[1])/length],n=[-d[1],d[0]];
  // Club silhouette deliberately tapers into a narrow handle, as in walk0.
  const butt=length-27;
  const profile=[[butt,1],[5,1.4],[length-10,2.4],[length-3,3.2],[length,2],
    [length,-2],[length-3,-3.2],[length-10,-2.4],[5,-1.4],[butt,-1]];
  const wood=Buffer.alloc(W*H*4);
  const vertices=profile.map(([u,v])=>[Math.round(h[0]+d[0]*u+n[0]*v),Math.round(h[1]+d[1]*u+n[1]*v)]);
  polygon(wood,vertices,C.wood);
  const points=[];
  for(let y=0;y<H;y++) for(let x=0;x<W;x++) if(wood[(y*W+x)*4+3]) points.push([x-O,y-O]);
  for(const [x,y] of points) {
    for(const [dx,dy] of [[0,-1],[-1,0],[1,0],[0,1]]) pixel(image,x+dx,y+dy,C.ink);
  }
  for(const [x,y] of points) {
    const u=(x-h[0])*d[0]+(y-h[1])*d[1], v=(x-h[0])*n[0]+(y-h[1])*n[1];
    let color=C.wood;
    if(v>1.1) color=C.woodDark;
    else if(v>.1) color=C.woodShade;
    else if(v<-.6) color=C.woodLight;
    if(u>length-7&&v<-.6&&v>-1.8) color=C.woodTop;
    if(u<5) color=C.woodShade;
    pixel(image,x,y,color);
  }
  // Two short grain marks replace noisy resampling of the diagonal source wood.
  for(const u of [length-5,length-10]) {
    const x=Math.round(h[0]+d[0]*u),y=Math.round(h[1]+d[1]*u);
    pixel(image,x,y,C.woodLight);
  }
}
function drawHand(image,p,back=false) {
  const [x,y]=back?[p.grip[0]-3,p.grip[1]-1]:p.grip;
  polygon(image,[[x-2,y-2],[x+2,y-2],[x+3,y+1],[x+1,y+3],[x-2,y+2]],C.ink);
  polygon(image,[[x-1,y-1],[x+1,y-1],[x+2,y+1],[x,y+2],[x-1,y+1]],back?C.skinShade:C.skinLight);
  pixel(image,x,y+1,C.skinShade);
}
function render(name) {
  if(name==='source') return sourceGuard();
  const p=poses[name],image=Buffer.alloc(W*H*4);
  drawLegs(image,p);
  drawArm(image,p,true);
  drawTorso(image,p);
  stamp(image,head,p.head[0],p.head[1]);
  drawArm(image,p);
  drawClub(image,p);
  drawHand(image,p,true);drawHand(image,p);
  return image;
}

function initPieces() {
  const limits=[[14,18],[13,19],[11,20],[11,20],[11,20],[11,19],[11,20],[10,19],[10,18],[10,18],[9,18],[9,18],[10,18],[10,17]];
  head=patch(rectPoints(9,0,21,13),(x,y)=>x>=limits[y][0]&&x<=limits[y][1]);
  frontFoot=patch(rectPoints(7,28,14,30),(x,y)=>y===28?x>=9&&x<=13:y===29?x<=13:x>=8&&x<=13);
  backFoot=patch(rectPoints(20,29,26,31));
  const temp=Buffer.alloc(W*H*4);
  const outline=[[20,8],[23,8],[25,10],[25,14],[24,19],[24,23],[23,25],[21,26],[20,24],[18,26],[15,25],[14,22],[13,18],[12,15],[15,12],[17,10]];
  polygon(temp,outline,C.ink);
  polygon(temp,[[20,9],[23,9],[24,11],[24,16],[23,21],[23,24],[21,24],[20,22],[17,24],[15,22],[14,18],[14,15],[17,13],[18,11]],C.skinShade);
  polygon(temp,[[21,9],[23,10],[23,17],[21,21],[16,21],[15,18],[16,14],[19,11]],C.skin);
  polygon(temp,[[21,10],[23,11],[22,16],[20,19],[17,18],[18,15]],C.skinMid);
  // Restore source chest/shoulder green pixels and its distinctive diagonal strap.
  const green=dot=>dot[1]>dot[0]&&dot[1]>dot[2]*1.2&&Math.max(...dot.slice(0,3))>45;
  for(let y=8;y<=20;y++) for(let x=14;x<=23;x++) {
    const color=[...source.subarray((y*32+x)*4,(y*32+x)*4+4)];
    if(color[3]&&green(color)&&temp[((y+O)*W+x+O)*4+3]) pixel(temp,x,y,color);
  }
  // Leather strap and the original central loincloth use the source palette.
  limb(temp,[21,8],[17,17],3,3,[C.leatherShade,C.leather]);
  line(temp,[20,9],[16,17],C.ink);
  polygon(temp,[[15,20],[24,21],[24,23],[15,22]],C.ink);
  polygon(temp,[[17,22],[21,22],[20,27],[18,26]],C.ink);
  polygon(temp,[[18,22],[20,23],[19,26],[18,25]],C.woodShade);
  pixel(temp,18,23,C.woodLight);
  torso=[];
  for(let y=0;y<H;y++) for(let x=0;x<W;x++) {
    const at=(y*W+x)*4;
    if(temp[at+3]) torso.push({x:x-O,y:y-O,c:[...temp.subarray(at,at+4)]});
  }
}
function bounds(image) {
  const xs=[],ys=[];
  for(let y=0;y<H;y++) for(let x=0;x<W;x++) if(image[(y*W+x)*4+3]) {xs.push(x);ys.push(y);}
  return [Math.min(...xs),Math.min(...ys),Math.max(...xs)+1,Math.max(...ys)+1];
}
function componentSizes(image) {
  const seen=new Set(),result=[];
  for(let at=0;at<W*H;at++) {
    if(seen.has(at)||!image[at*4+3]) continue;
    const pending=[at];seen.add(at);let count=0;
    while(pending.length) {
      const p=pending.pop(),x=p%W,y=Math.floor(p/W);count++;
      for(let dy=-1;dy<=1;dy++) for(let dx=-1;dx<=1;dx++) {
        const nx=x+dx,ny=y+dy,n=ny*W+nx;
        if(nx<0||nx>=W||ny<0||ny>=H||seen.has(n)||!image[n*4+3]) continue;
        seen.add(n);pending.push(n);
      }
    }
    result.push(count);
  }
  return result.sort((a,b)=>b-a);
}
async function png(image, scale=1) {
  return sharp(image,{raw:{width:W,height:H,channels:4}}).resize(W*scale,H*scale,{kernel:'nearest'}).png().toBuffer();
}
async function sheets(frames,clip) {
  const count=frames.length, columns=6,scale=4,cell=280,rowH=302;
  const layers=[];
  for(const [i,image] of frames.entries()) {
    const x=(i%columns)*cell,y=Math.floor(i/columns)*rowH;
    layers.push({input:await png(image,scale),left:x+8,top:y+24});
    layers.push({input:Buffer.from(`<svg width="280" height="302"><text x="8" y="18" fill="white" font-family="sans-serif" font-size="15">${i.toString().padStart(2,'0')} ${clip.poses[i]} ${clip.milliseconds[i]}ms</text><path d="M 0 216 H 272" stroke="#537372" stroke-opacity=".65"/></svg>`),left:x,top:y});
  }
  await sharp({create:{width:columns*cell,height:Math.ceil(count/columns)*rowH,channels:4,background:'#192430'}}).composite(layers).png().toFile(path.join(qa,clip.name+'-poses.png'));
  const strip=[];
  for(const [i,image] of frames.entries()) strip.push({input:await png(image,2),left:(i%6)*W*2,top:Math.floor(i/6)*H*2});
  await sharp({create:{width:6*W*2,height:Math.ceil(count/6)*H*2,channels:4,background:'#192430'}}).composite(strip).png().toFile(path.join(qa,clip.name+'-native2x.png'));
  const preview=[];
  for(const frame of frames) preview.push(await sharp(frame,{raw:{width:W,height:H,channels:4}}).flatten({background:'#192430'}).resize(128,128,{kernel:'nearest'}).png().toBuffer());
  // Runtime duration stays owned by Foe. These GIFs preview that exact budget.
  const gifDelays=(speed=1)=>{
    let accumulated=0,previous=0;
    return clip.milliseconds.map(ms=>{accumulated+=ms*speed;const next=Math.round(accumulated/10)*10,d=next-previous;previous=next;return d;});
  };
  await sharp(preview,{join:{animated:true}}).gif({loop:0,delay:gifDelays(),dither:0}).toFile(path.join(qa,clip.name+'-native2x.gif'));
  await sharp(preview,{join:{animated:true}}).gif({loop:0,delay:gifDelays(3),dither:0}).toFile(path.join(qa,clip.name+'-native2x-slow.gif'));
  const gif=await sharp(path.join(qa,clip.name+'-native2x.gif'),{animated:true}).metadata();
  assert.equal(gif.pages,frames.length,'GIF frame count');
  assert.equal(gif.delay.reduce((a,b)=>a+b,0),clip.milliseconds.reduce((a,b)=>a+b,0),'GIF playback duration');
}
async function main() {
  await fs.mkdir(qa,{recursive:true});
  const src=await sharp(path.join(root,'assets/anim/orc_walk/0.png')).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  assert.equal(src.info.width,32);assert.equal(src.info.height,32);source=src.data;
  palette=new Set();for(let i=0;i<source.length;i+=4) if(source[i+3]) palette.add(key([...source.subarray(i,i+4)]));
  for(const [name,color] of Object.entries(C)) assert(palette.has(key(color)),`New color ${name}`);
  initPieces();
  const report=[];
  for(const clip of clips) {
    const frames=clip.poses.map(render),dir=path.join(root,'assets/anim',clip.name);
    await fs.mkdir(dir,{recursive:true});
    const rows=[];
    for(const [i,data] of frames.entries()) {
      for(let p=0;p<data.length;p+=4) if(data[p+3]) assert(palette.has(key([...data.subarray(p,p+4)])),`New color in ${clip.name} frame ${i}`);
      const encoded=await png(data),file=path.join(dir,i+'.png');
      await fs.writeFile(file,encoded);
      const decoded=await sharp(encoded).ensureAlpha().raw().toBuffer();assert(data.equals(decoded),'PNG roundtrip');
      const bbox=bounds(data),components=componentSizes(data);
      assert.equal(bbox[3],48,`Foot baseline drift: ${clip.name}/${i}`);
      assert.equal(components.length,1,`Detached body pixels: ${clip.name}/${i}`);
      rows.push({frame:i,pose:clip.poses[i],milliseconds:clip.milliseconds[i],bounds:bbox,components});
    }
    assert(frames[0].equals(frames.at(-1)),'Guard transition must close');
    await sheets(frames,clip);
    report.push({clip:clip.name,source:'orc_walk/0.png',sourceRgbaSha256:crypto.createHash('sha256').update(source).digest('hex'),
      sourceFacePixels:head.length,sourcePaletteSize:palette.size,sourceFaces:'left',canvas:[W,H],sourceOffset:[O,O],footAnchor:[32,48],
      scale:'one source pixel = one output pixel',contactFrame:clip.contact,recoveryStartFrame:clip.recovery,
      tellEndFrame:clip.name==='orc_special_v2'?7:null,executionStartFrame:clip.name==='orc_special_v2'?7:0,
      runtimeBudgetMs:clip.name==='orc_special_v2'?{tell:850,attack:550}:{attack:420},
      milliseconds:clip.milliseconds,durationMs:clip.milliseconds.reduce((a,b)=>a+b,0),
      contactFrameStartsMs:clip.milliseconds.slice(0,clip.contact).reduce((a,b)=>a+b,0),
      contactTimeMs:clip.milliseconds.slice(0,clip.contact).reduce((a,b)=>a+b,0)+clip.milliseconds[clip.contact]/2,
      newPaletteColors:0,firstAndLastMatchSource:true,frames:rows});
  }
  await fs.writeFile(path.join(qa,'orc-motion.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report.map(({clip,contactFrame,footAnchor,durationMs,newPaletteColors})=>({clip,contactFrame,footAnchor,durationMs,newPaletteColors})),null,2));
}
main().catch(error=>{console.error(error);process.exitCode=1;});
