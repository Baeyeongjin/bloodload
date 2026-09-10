// REJECTED 2026-09-08: stiff head/torso and unnatural leg proportions.
// Retained for diagnosis; these generated poses are not used by Main.
// Authored pixel poses, not interpolation/optical flow/image generation.
// The original face and armour pixels are retained at their original density.
// Arms, legs, blade, cape folds and key poses are explicitly drawn below.
// Author facing right; saved game assets face left, as Main expects.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const ROOT = path.resolve(__dirname, '..');
const QA = path.join(ROOT, 'build/qa/authored-hero-v2');
const W = 64;
const C = {
  outline: '030702ff', black: '070903ff', coat: '4e1020ff', coatLight: '521625ff',
  coatShade: '401317ff', dark: '28231bff', leather: '594534ff', leatherLight: '8a765bff',
  brown: '644735ff', brownLight: '69503eff', skin: 'd3b59dff', skinShade: 'aa8d76ff',
  blade: 'fbe3e0ff', bladeShade: 'e2cfc0ff', guard: '836a50ff',
};
const colour = Object.fromEntries(Object.entries(C).map(([k,v]) => [k, Buffer.from(v, 'hex')]));
let source, frontSource;
function pixel(im, x, y, c) {
  x = Math.round(x); y = Math.round(y);
  if (x >= 0 && x < W && y >= 0 && y < W) colour[c].copy(im, (y * W + x) * 4);
}
function line(im, a, b, c, width = 1) {
  let [x,y] = a.map(Math.round); const [tx,ty] = b.map(Math.round);
  const dx = Math.abs(tx-x), sx = x < tx ? 1 : -1, dy = -Math.abs(ty-y), sy = y < ty ? 1 : -1;
  let err = dx + dy;
  for (;;) {
    for (let oy = -Math.floor(width/2); oy <= Math.floor(width/2); oy++)
      for (let ox = -Math.floor(width/2); ox <= Math.floor(width/2); ox++) pixel(im,x+ox,y+oy,c);
    if (x === tx && y === ty) break;
    const e = 2*err; if (e >= dy) {err += dy; x += sx;} if (e <= dx) {err += dx; y += sy;}
  }
}
function polygon(im, points, fill, outline = true) {
  const minY = Math.max(0,Math.floor(Math.min(...points.map(p=>p[1]))));
  const maxY = Math.min(63,Math.ceil(Math.max(...points.map(p=>p[1]))));
  for (let y = minY; y <= maxY; y++) {
    const xs=[];
    for (let i=0,j=points.length-1;i<points.length;j=i++) {
      const [x1,y1]=points[j], [x2,y2]=points[i];
      if ((y1<=y&&y2>y)||(y2<=y&&y1>y)) xs.push(x1+(y-y1)*(x2-x1)/(y2-y1));
    }
    xs.sort((a,b)=>a-b);
    for(let i=0;i+1<xs.length;i+=2) for(let x=Math.ceil(xs[i]);x<=Math.floor(xs[i+1]);x++) pixel(im,x,y,fill);
  }
  if(outline) for(let i=0;i<points.length;i++) line(im,points[i],points[(i+1)%points.length],'outline');
}
function limb(im, a, knee, foot, front) {
  const ankle=[foot[0],foot[1]-1];
  line(im,a,knee,'outline',5); line(im,knee,ankle,'outline',3);
  line(im,a,knee,'dark',3); line(im,a,knee,front?'leather':'dark');
  line(im,knee,ankle,front?'brown':'dark');
  if(front) pixel(im,knee[0],knee[1]-1,'leatherLight');
  const [x,y]=foot;
  // Ground-contact coordinate is the last filled sole row (47).
  line(im,[x-1,y],[x+3,y],'outline'); line(im,[x,y-1],[x+2,y-1],front?'brown':'dark');
  pixel(im,x,y-2,front?'leather':'dark');
}
function arm(im, shoulder, elbow, hand, front) {
  line(im,shoulder,elbow,'outline',3); line(im,elbow,hand,'outline',3);
  line(im,shoulder,elbow,front?'leather':'dark'); line(im,elbow,hand,front?'brownLight':'leather');
  if(front) pixel(im,elbow[0],elbow[1]-1,'leatherLight');
  pixel(im,hand[0],hand[1],'skin'); pixel(im,hand[0]-1,hand[1],'skinShade');
}
function sword(im, hand, tip) {
  const dx=tip[0]-hand[0],dy=tip[1]-hand[1],len=Math.hypot(dx,dy);
  const start=[hand[0]+dx/len*3,hand[1]+dy/len*3];
  line(im,hand,tip,'outline',3);
  line(im,start,tip,'coatLight');
  // A one-pixel pale edge preserves the original wine/ivory sword palette.
  line(im,[start[0]-dy/len,start[1]+dx/len],[tip[0]-dy/len,tip[1]+dx/len],'blade');
  const guard=[hand[0]+dx/len*2,hand[1]+dy/len*2];
  line(im,[guard[0]-dy/len*2,guard[1]+dx/len*2],[guard[0]+dy/len*2,guard[1]-dx/len*2],'guard');
  line(im,[hand[0]-dx/len*2,hand[1]-dy/len*2],hand,'brown');
}
function render(p) {
  const im=Buffer.alloc(W*W*4), [hx,hy]=p.hip, dy=hy-37;
  const lean=p.lean||0, chest=[hx+2+lean,hy-8], headShift=[hx-32+lean,dy];
  const tip=p.cape||[hx-19,hy-3], fold=p.fold||[hx-11,hy+3];
  polygon(im,[[hx-2+lean,17+dy],[hx+lean,23+dy],[chest[0]-2,chest[1]],
    tip,[tip[0]+3,tip[1]+3],fold,[hx-3,hy+2]],'coat');
  polygon(im,[[hx-2+lean,20+dy],[hx-3+lean,26+dy],[tip[0]+3,tip[1]],
    [tip[0]+1,tip[1]+1],[hx-4+lean,28+dy]],'coatLight',false);
  polygon(im,[[tip[0]+3,tip[1]+3],fold,[hx-3,hy+2],[hx-7,hy-1]],'outline',false);
  polygon(im,[[tip[0]+5,tip[1]+2],[hx-6,hy-3],[hx-8,hy+1],
    [fold[0]-1,fold[1]-1]],'coatShade',false);
  line(im,[tip[0]+4,tip[1]+2],[hx-7,hy-2],'coatLight');
  line(im,tip,[hx-5,hy-3],'coatLight');
  limb(im,[hx-2,hy],p.bk,p.bf,false);
  limb(im,[hx+1,hy],p.fk,p.ff,true);
  const torso=[[29,28],[35,27],[38,29],[37,35],[34,39],[28,37],[28,32]]
    .map(([x,y])=>[x+hx-32+Math.round((37-y)/10*lean),y+dy]);
  polygon(im,torso,'dark');
  const rows=p.turn ? [[26,29,34],[27,28,36],[28,28,37],[29,28,37],[30,27,37],
    [31,27,37],[32,27,36],[33,27,36],[34,27,36],[35,28,35],[36,29,35],[37,30,35]]
    : [[28,33,38],[29,33,38],[30,32,37],[31,32,36],[32,31,35],
      [33,30,35],[34,29,36],[35,29,35],[36,29,35],[37,30,35]];
  const armour=p.turn?frontSource:source;
  for(const [y,x0,x1] of rows) for(let x=x0;x<=x1;x++) {
    const i=(y*W+x)*4;
    if(armour[i+3]) armour.copy(im,((y+dy)*W+x+hx-32+Math.round((37-y)/10*lean))*4,i,i+4);
  }
  const backHand=p.bh||[p.hand[0]-2,p.hand[1]+1];
  arm(im,[chest[0]-4,chest[1]],p.be||[chest[0]-4,hy-3],backHand,false);
  sword(im,p.hand,p.tip);
  arm(im,[chest[0]+1,chest[1]],p.elbow,p.hand,true);
  // Protected original face/hair/neck tile: only an integer translation.
  for(let y=17;y<=28;y++) for(let x=33;x<=41;x++) {
    const i=(y*W+x)*4;
    if(source[i+3]) source.copy(im,((y+headShift[1])*W+x+headShift[0])*4,i,i+4);
  }
  for(const [x,y] of p.clearPixels||[]) im.fill(0,(y*W+x)*4,(y*W+x+1)*4);
  return im;
}
function pose(hip,lean,bk,bf,fk,ff,hand,tip,elbow,cape,extras={}) {
  return {hip,lean,bk,bf,fk,ff,hand,tip,elbow,cape,...extras};
}
const RUN = [
  // At 30 poses/s and 2x render scale the planted sole travels 3,4,3 native
  // pixels per pose: exactly 200 screen px/s over each three-pose interval.
  pose([32,37],1,[29,39],[26,39],[37,43],[42,47],[41,32],[52,18],[37,33],[12,33],{bh:[28,34],be:[29,31]}),
  pose([32,38],1,[31,40],[28,40],[36,44],[39,47],[41,33],[52,19],[37,34],[11,34],{bh:[28,33],be:[29,32]}),
  pose([33,37],1,[33,41],[31,42],[34,42],[35,47],[42,32],[53,18],[38,33],[11,33],{bh:[29,31],be:[30,30]}),
  pose([34,36],1,[36,40],[35,44],[31,41],[32,47],[43,31],[54,17],[39,32],[12,31],{bh:[30,29],be:[30,29]}),
  pose([34,35],1,[37,40],[38,45],[29,39],[29,43],[43,30],[54,16],[39,31],[13,30],{bh:[30,29],be:[30,28]}),
  pose([33,35],1,[38,41],[41,46],[28,38],[28,40],[42,30],[53,16],[38,31],[14,30],{bh:[30,30],be:[29,28]}),
  pose([32,37],1,[37,43],[42,47],[29,39],[26,39],[41,32],[52,18],[37,33],[14,33],{bh:[30,34],be:[29,31]}),
  pose([32,38],1,[36,44],[39,47],[31,40],[28,40],[41,33],[52,19],[37,34],[13,35],{bh:[30,35],be:[29,33]}),
  pose([33,37],1,[34,42],[35,47],[33,41],[31,42],[42,32],[53,18],[38,33],[12,35],{bh:[29,36],be:[29,33]}),
  pose([34,36],1,[31,41],[32,47],[36,40],[35,44],[43,31],[54,17],[39,32],[11,34],{bh:[27,35],be:[28,32]}),
  pose([34,35],1,[29,39],[29,43],[37,40],[38,45],[43,30],[54,16],[39,31],[11,32],{bh:[27,34],be:[28,30]}),
  pose([33,35],1,[28,38],[28,40],[38,41],[41,46],[42,30],[53,16],[38,31],[12,31],{bh:[28,34],be:[29,29]}),
];
// Exact shared poses join all three attacks. A is the running/ready sword angle;
// B is a low loaded stance, C finishes the rising cut behind the shoulder.
const A = pose([32,37],0,[27,42],[24,47],[36,43],[41,47],[40,31],[52,17],[36,32],[13,35]);
const B = pose([29,40],-2,[26,44],[24,47],[34,44],[41,47],[33,35],[40,48],[32,32],[13,39]);
const CPOSE = pose([31,37],0,[27,42],[23,47],[36,42],[41,47],[32,24],[22,9],[33,27],[12,36]);
// Facing the target while withdrawing: planted feet advance in local space as
// the hero moves backwards. This is an authored guard/backstep, not reversed run.
const BACKSTEP = [A,
  pose([31,38],-1,[28,43],[28,47],[37,44],[45,47],[39,30],[50,15],[35,31],[17,35]),
  pose([30,39],-2,[30,43],[32,47],[36,41],[46,44],[38,29],[48,14],[34,30],[19,34]),
  pose([30,39],-2,[32,43],[36,47],[34,40],[42,42],[38,29],[48,14],[34,30],[21,35]),
  pose([31,38],-1,[29,41],[29,44],[33,43],[33,47],[39,30],[50,15],[35,31],[18,36]),
  pose([32,37],0,[27,40],[24,44],[35,43],[37,47],[40,31],[52,17],[36,32],[15,36]),
];
const ATTACK = [A,
  pose([30,39],-2,[26,44],[24,47],[34,43],[40,47],[37,28],[43,12],[33,30],[14,39]),
  pose([28,40],-3,[26,44],[24,47],[34,44],[40,47],[32,26],[24,10],[30,29],[16,41]),
  pose([29,39],-2,[26,44],[24,47],[34,43],[41,47],[33,24],[37,6],[32,27],[15,40]),
  pose([32,38],2,[28,44],[24,47],[38,44],[44,47],[40,27],[55,15],[38,29],[10,35]),
  pose([35,39],3,[29,43],[24,47],[42,44],[46,47],[45,30],[60,29],[42,30],[8,31]),
  pose([36,40],3,[30,44],[25,47],[43,45],[47,47],[44,33],[57,43],[42,32],[8,29]),
  pose([35,40],2,[30,44],[25,47],[42,45],[47,47],[42,35],[53,47],[40,33],[9,29]),
  pose([35,40],2,[30,44],[25,47],[41,45],[46,47],[41,35],[51,48],[39,33],[10,30]),
  pose([34,40],1,[29,44],[24,47],[40,45],[45,47],[39,35],[48,49],[37,33],[12,32]),
  pose([33,39],0,[28,43],[24,47],[39,44],[44,47],[37,34],[46,48],[35,32],[14,34]),
  pose([32,39],-1,[27,43],[24,47],[37,44],[43,47],[36,34],[44,48],[34,32],[15,36]),
  pose([31,39],-1,[27,43],[24,47],[36,44],[42,47],[35,34],[43,48],[33,32],[15,37]),
  pose([30,40],-2,[26,44],[24,47],[35,44],[42,47],[34,35],[42,49],[32,32],[15,39]),
  pose([29,40],-2,[26,44],[24,47],[34,44],[41,47],[33,35],[41,49],[32,32],[14,40]), B,
];
const ATTACK2 = [B,
  pose([28,40],-2,[25,44],[24,47],[34,44],[41,47],[32,35],[38,49],[31,32],[14,41]),
  pose([29,40],-2,[26,44],[24,47],[34,44],[41,47],[33,34],[44,45],[32,32],[15,40]),
  pose([31,38],0,[27,42],[23,47],[36,43],[43,47],[35,32],[49,39],[35,31],[13,38]),
  pose([32,37],1,[27,42],[23,47],[37,42],[44,47],[38,29],[55,31],[37,29],[10,35]),
  pose([34,36],1,[29,42],[24,47],[39,42],[45,47],[41,27],[57,25],[39,28],[9,31]),
  pose([34,35],1,[29,41],[24,47],[39,41],[45,47],[40,24],[51,11],[38,26],[10,29]),
  pose([34,35],1,[29,41],[24,47],[39,41],[45,47],[36,22],[39,5],[36,25],[11,28]),
  pose([33,35],0,[28,41],[23,47],[38,41],[44,47],[33,22],[28,6],[34,25],[12,28]),
  pose([32,36],0,[28,42],[23,47],[37,42],[43,47],[31,23],[20,10],[33,26],[13,29]),
  pose([31,36],-1,[27,42],[23,47],[36,42],[42,47],[30,24],[16,14],[32,27],[14,30]),
  pose([31,37],-1,[27,42],[23,47],[36,42],[42,47],[31,24],[18,13],[32,27],[14,31]),
  pose([31,37],0,[27,42],[23,47],[36,42],[41,47],[31,24],[19,12],[33,27],[14,33]),
  pose([31,37],0,[27,42],[23,47],[36,42],[41,47],[32,24],[20,10],[33,27],[13,34]),
  pose([31,37],0,[27,42],[23,47],[36,42],[41,47],[32,24],[21,9],[33,27],[12,35]), CPOSE,
];
const ATTACK3 = [CPOSE,
  pose([31,36],-1,[27,41],[23,47],[36,41],[41,47],[32,22],[23,6],[33,25],[13,35]),
  pose([32,34],0,[28,39],[24,45],[36,39],[41,46],[33,20],[31,3],[34,23],[13,32]),
  pose([33,34],1,[29,39],[25,44],[38,39],[42,44],[35,20],[39,3],[36,23],[12,29]),
  pose([34,35],2,[29,40],[25,45],[39,40],[44,45],[39,22],[51,9],[38,25],[10,27]),
  pose([35,37],3,[29,42],[24,46],[41,42],[46,47],[42,26],[58,19],[40,28],[8,27]),
  pose([36,39],3,[30,43],[24,47],[42,44],[47,47],[43,32],[58,41],[41,31],[8,28]),
  pose([36,40],3,[30,44],[24,47],[42,44],[47,47],[42,34],[52,47],[41,32],[10,28]),
  pose([35,40],2,[30,44],[24,47],[41,44],[46,47],[39,35],[47,48],[38,33],[12,30]),
  pose([34,39],2,[29,43],[24,47],[40,43],[45,47],[36,34],[40,48],[36,32],[14,33]),
  pose([33,38],1,[28,42],[24,47],[39,43],[44,47],[33,32],[24,44],[34,30],[16,36]),
  pose([32,37],0,[27,42],[24,47],[38,43],[43,47],[30,29],[16,37],[32,28],[17,38]),
  pose([31,37],0,[27,42],[24,47],[37,43],[42,47],[30,27],[14,25],[32,27],[16,39]),
  pose([31,37],0,[27,42],[24,47],[37,43],[42,47],[32,26],[20,13],[33,27],[15,38]),
  pose([32,37],0,[27,42],[24,47],[36,43],[41,47],[37,28],[42,12],[35,29],[14,36]), A,
];
const HEAVY = [A,
  pose([31,38],0,[27,43],[24,47],[36,43],[42,47],[37,27],[37,10],[35,29],[14,37]),
  pose([31,39],-1,[27,43],[24,47],[35,44],[42,47],[32,24],[23,9],[33,27],[15,38]),
  pose([30,39],-1,[26,43],[24,47],[35,44],[42,47],[31,22],[23,5],[32,25],[16,39]),
  pose([31,38],0,[27,42],[24,47],[36,43],[43,47],[32,20],[28,3],[33,23],[15,37]),
  pose([32,36],1,[27,41],[24,47],[37,42],[43,47],[34,20],[36,3],[35,23],[13,33]),
  pose([34,37],2,[29,42],[24,47],[39,43],[45,47],[39,24],[51,12],[38,27],[10,30]),
  pose([35,39],3,[29,43],[24,47],[41,44],[46,47],[43,31],[57,44],[40,30],[9,29]),
  pose([35,40],3,[29,44],[24,47],[41,44],[46,47],[42,34],[51,47],[40,32],[11,29]),
  pose([34,40],2,[29,44],[24,47],[40,44],[45,47],[40,34],[48,48],[38,32],[13,31]),
  pose([33,39],1,[28,43],[24,47],[39,44],[44,47],[37,33],[42,47],[36,31],[15,34]),
  pose([32,38],0,[27,42],[24,47],[38,43],[43,47],[34,31],[28,46],[34,29],[16,36]),
  pose([32,38],0,[27,42],[24,47],[37,43],[43,47],[32,29],[19,40],[33,28],[16,38]),
  pose([32,37],0,[27,42],[24,47],[37,43],[42,47],[32,27],[21,17],[33,27],[15,38]),
  pose([32,37],0,[27,42],[24,47],[36,43],[41,47],[37,28],[43,12],[35,29],[14,36]), A,
];
// These replace slots 0..2 or 13..15 of the same 16-pose heavy clip.
// The B/C preparation and recovery preserve whichever combo follows the skill.
const HEAVY_FROM_B = [B,
  pose([29,40],-2,[26,44],[24,47],[34,44],[41,47],[31,30],[17,36],[30,32],[14,40]),
  pose([30,39],-1,[26,43],[24,47],[35,44],[42,47],[30,25],[15,16],[31,28],[16,40]),
];
const HEAVY_FROM_C = [CPOSE,
  pose([31,38],-1,[27,43],[24,47],[35,43],[42,47],[31,23],[22,7],[32,26],[14,37]),
  pose([30,39],-1,[26,43],[24,47],[35,44],[42,47],[31,22],[22,5],[32,25],[16,38]),
];
const HEAVY_TO_B = [
  pose([31,39],-1,[27,43],[24,47],[36,44],[42,47],[32,32],[23,46],[32,31],[15,39]),
  pose([30,40],-2,[26,44],[24,47],[35,44],[41,47],[32,34],[33,49],[31,32],[14,40]), B,
];
const HEAVY_TO_C = [
  pose([31,38],-1,[27,42],[24,47],[36,43],[42,47],[31,26],[15,28],[32,28],[15,38]),
  pose([31,37],0,[27,42],[23,47],[36,42],[41,47],[31,24],[17,15],[33,27],[13,37]), CPOSE,
];
// The same original armour in its authored front view makes the shoulder turn
// readable at release; the face remains the protected original side-view tile.
for(const i of [3,4,5,6,7,8,9]) ATTACK[i].turn=true;
for(const i of [3,4,5,6,7,8]) ATTACK2[i].turn=true;
for(const i of [4,5,6,7,8,9]) ATTACK3[i].turn=true;
for(const i of [6,7,8,9,10]) HEAVY[i].turn=true;
// Remove detached fold tips exposed by these two extreme rear-loaded poses.
// Explicit author-facing coordinates; all are outside the protected face tile.
ATTACK[2].clearPixels=[[22,27],[22,28],[22,29]];
ATTACK2[1].clearPixels=[[21,33]];
const CLIPS={run_v2:{poses:RUN,fps:30,loop:true},
  backstep_v2:{poses:BACKSTEP,fps:30,loop:true},
  attack_v2:{poses:ATTACK,fps:16/.6,contact:5},
  attack2_v2:{poses:ATTACK2,fps:16/.6,contact:5},
  attack3_v2:{poses:ATTACK3,fps:16/.6,contact:6},
  heavy_v2:{poses:HEAVY,fps:16/.7,contact:7},
  heavy_from_b_v2:{poses:HEAVY_FROM_B,fps:16/.7},
  heavy_from_c_v2:{poses:HEAVY_FROM_C,fps:16/.7},
  heavy_to_b_v2:{poses:HEAVY_TO_B,fps:16/.7},
  heavy_to_c_v2:{poses:HEAVY_TO_C,fps:16/.7}};
async function png(raw,scale=1) {
  return sharp(raw,{raw:{width:64,height:64,channels:4}}).resize(64*scale,64*scale,{kernel:'nearest'}).png().toBuffer();
}
async function writeClip(name,clip,palette) {
  const dir=path.join(ROOT,'assets/anim/valentino_1_'+name); fs.mkdirSync(dir,{recursive:true});
  const frames=clip.poses.map(render);
  for(const [i,frame] of frames.entries()) {
    for(let p=0;p<frame.length;p+=4) if(frame[p+3]) assert(palette.has(frame.readUInt32LE(p)),`${name}: foreign palette`);
    const pose=clip.poses[i],sx=pose.hip[0]-32+pose.lean,sy=pose.hip[1]-37;
    for(let y=17;y<=28;y++)for(let x=33;x<=41;x++) {
      const p=(y*W+x)*4,q=((y+sy)*W+x+sx)*4;
      if(source[p+3])assert(source.subarray(p,p+4).equals(frame.subarray(q,q+4)),`${name} ${i}: original face changed`);
    }
    const file=path.join(dir,`${i}.png`);
    const encoded=await sharp(frame,{raw:{width:64,height:64,channels:4}}).flop().png().toBuffer();
    if(!fs.existsSync(file)||!fs.readFileSync(file).equals(encoded)) fs.writeFileSync(file,encoded);
  }
  const cell=144,rows=Math.ceil(frames.length/6),images=[];let svg=`<svg width="864" height="${rows*160}">`;
  for(const [i,frame] of frames.entries()) {
    const x=i%6*cell,y=Math.floor(i/6)*160;
    images.push({input:await png(frame,2),left:x+8,top:y+24});
    svg+=`<text x="${x+8}" y="${y+16}" fill="#eee" font-size="12">${name} ${i}${i===clip.contact?' CONTACT':''}</text>`;
  }
  svg+='</svg>';
  await sharp({create:{width:864,height:rows*160,channels:4,background:'#25313c'}})
    .composite([{input:Buffer.from(svg),left:0,top:0},...images]).png().toFile(path.join(QA,name+'-sheet.png'));
  await sharp(Buffer.concat(frames),{raw:{width:64,height:64*frames.length,channels:4,pageHeight:64}})
    .resize({width:128,kernel:'nearest'}).gif({loop:0,delay:Math.round(1000/clip.fps),dither:0})
    .toFile(path.join(QA,name+'.gif'));
  return {frames:frames.length,contact:clip.contact??null,fps:clip.fps,loop:!!clip.loop};
}
(async()=>{
  fs.mkdirSync(QA,{recursive:true});
  source=await sharp(path.join(ROOT,'assets/anim/valentino_1_dash/3.png')).ensureAlpha().flop().raw().toBuffer();
  frontSource=await sharp(path.join(ROOT,'assets/anim/valentino_1_attack/6.png')).ensureAlpha().flop().raw().toBuffer();
  const palette=new Set;
  for(const art of [source,frontSource])for(let i=0;i<art.length;i+=4)if(art[i+3])palette.add(art.readUInt32LE(i));
  for(const [name,hex] of Object.entries(C))assert(palette.has(Buffer.from(hex,'hex').readUInt32LE(0)),`Colour ${name} is not in original source`);
  for(const [from,to] of [[ATTACK,ATTACK2],[ATTACK2,ATTACK3],[ATTACK3,ATTACK]])
    assert(render(from.at(-1)).equals(render(to[0])),'Combo endpoints differ');
  for(const [actual,expected] of [[HEAVY_FROM_B[0],B],[HEAVY_FROM_C[0],CPOSE],
    [HEAVY_TO_B[2],B],[HEAVY_TO_C[2],CPOSE]])
    assert(render(actual).equals(render(expected)),'Heavy bridge boundary differs');
  const report={source:['valentino_1_dash/3.png','valentino_1_attack/6.png'],sourceFaces:'left',authoringFaces:'right',canvas:[64,64],groundRow:47,clips:{}};
  for(const [name,clip] of Object.entries(CLIPS))report.clips[name]=await writeClip(name,clip,palette);
  fs.writeFileSync(path.join(QA,'motion-manifest.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify(report,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
