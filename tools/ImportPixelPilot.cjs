// Mechanical extraction of reviewed generated sheets, not a motion synthesizer.
// Source frames keep one scale per actor and fixed row anchors; do not fit poses individually.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const crypto = require('crypto');
const ROOT = path.resolve(__dirname, '..');
const QA = path.join(ROOT, 'build/qa/redesign-32');
const PALETTES=JSON.parse(fs.readFileSync(path.join(__dirname,'pixel_pilot_palettes.json'),'utf8').replace(/^\uFEFF/,''));
const EDGE_PATCHES=JSON.parse(fs.readFileSync(path.join(__dirname,'pixel_pilot_edge_patches.json'),'utf8')).actors;
const defs = {
  valentino_1: { rows: ['walk','dash','attack','attack2','heavy','special'], scale: 2/9,
    x: [131,128,118,111,111,115], step: 209, ground: [196,363,562,775,983,1188], mirror: true },
  orc: { rows: ['walk','dash','attack','special'], scale: 0.18,
    x: [144,139,144,140], step: 250, ground: [237,464,705,966] },
  frost_golem: { rows: ['walk','dash','attack','special'], scale: 0.185,
    x: [150,147,145,146], step: 250, ground: [237,454,679,923] },
};

async function keyed(file) {
  const {data,info} = await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  const {width:w,height:h}=info, n=w*h, seen=new Uint8Array(n), queue=new Int32Array(n);
  let head=0,tail=0;
  const isBG = i => {
    const [r,g,b,a]=data.subarray(i*4,i*4+4);
    return a<128 || (Math.min(r,g,b)>=220 && Math.max(r,g,b)-Math.min(r,g,b)<=15)
      || (r>g+20 && b>g+20);
  };
  const add=i=>{if(!seen[i] && isBG(i)){seen[i]=1;queue[tail++]=i;}};
  for(let x=0;x<w;x++){add(x);add((h-1)*w+x);}
  for(let y=0;y<h;y++){add(y*w);add(y*w+w-1);}
  while(head<tail){const i=queue[head++],x=i%w,y=(i/w)|0;
    if(x) add(i-1); if(x+1<w) add(i+1); if(y) add(i-w); if(y+1<h) add(i+w);
  }
  for(let i=0;i<n;i++){
    // Magenta is explicitly a non-art matte in these three actors; remove closed holes too.
    const [r,g,b]=data.subarray(i*4,i*4+3);
    if(seen[i] || (r>g+20 && b>g+20)) data.fill(0,i*4,i*4+4);
    else data[i*4+3]=255;
  }
  return {data,w,h};
}

function components(data,w,h) {
  const seen=new Uint8Array(w*h), q=new Int32Array(w*h), out=[];
  for(let start=0;start<w*h;start++){
    if(seen[start]||!data[start*4+3])continue;
    let head=0,tail=1,x0=w,y0=h,x1=0,y1=0; q[0]=start;seen[start]=1;
    while(head<tail){const i=q[head++],x=i%w,y=(i/w)|0;
      x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
      for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
        const xx=x+dx,yy=y+dy,j=yy*w+xx;
        if(xx>=0&&xx<w&&yy>=0&&yy<h&&!seen[j]&&data[j*4+3]){seen[j]=1;q[tail++]=j;}
      }
    }
    if(tail>8)out.push({x0,y0,x1,y1,count:tail,pixels:q.slice(0,tail)});
  }
  return out;
}

async function refinedHero() {
  // Reviewed six-pose boards use 3 columns, and long swords cross a cell boundary.
  // Isolate connected actors before sampling; anchors are the midpoint of the boots.
  const clips = {
    attack: {scale:30/302, x:[243,784,1144,269,803,1233], ground:[423,423,423,897,898,904]},
    attack2: {scale:30/318, x:[286,746,1146,281,695,1152], ground:[448,448,449,895,894,895]},
    heavy: {scale:30/273, x:[266,726,1112,286,747,1208], ground:[459,459,458,853,862,881]},
  };
  const result = {};
  for(const [motion,d] of Object.entries(clips)) {
    const file=path.join(ROOT,'build/qa/motion-refinement',motion+'-source.png');
    assert(fs.existsSync(file),`Missing reviewed hero board: ${file}`);
    const {data,w,h}=await keyed(file);
    const parts=components(data,w,h).filter(c=>c.count>1000);
    assert(parts.length===6,`${motion}: expected six isolated poses`);
    const frames=[];
    for(let f=0;f<6;f++) {
      const part=parts.find(c=>Math.floor((c.x0+c.x1)/2/(w/3))===f%3 && Math.floor((c.y0+c.y1)/2/(h/2))===Math.floor(f/3));
      assert(part,`${motion}/${f}: missing actor`);
      const allowed=new Uint8Array(w*h), rgba=Buffer.alloc(64*64*4);
      for(const i of part.pixels)allowed[i]=1;
      for(let y=0;y<64;y++)for(let x=0;x<64;x++) {
        const sx=Math.floor(d.x[f]+(x+.5-32)/d.scale), sy=Math.floor(d.ground[f]+(y+.5-48)/d.scale);
        if(sx>=0&&sx<w&&sy>=0&&sy<h&&allowed[sy*w+sx])data.copy(rgba,(y*64+x)*4,(sy*w+sx)*4,(sy*w+sx+1)*4);
      }
      frames.push(rgba);
    }
    result[motion]=frames;
  }
  // The generated heavy acceleration reverted to guard. The reviewed raised-sword
  // pose is the correct approach to its downward contact, at the same body scale.
  result.heavy[2]=Buffer.from(result.attack[2]);
  const ready=Buffer.from(result.attack[0]);
  for(const frames of Object.values(result)) {frames[0]=Buffer.from(ready);frames[5]=Buffer.from(ready);}
  result.ready=ready;
  const secondaryDir=path.join(ROOT,'build/qa/motion-refinement/secondary');
  const xs=[200,496,782,1066,1344,1619,207,493,775,1056,1341,1624,176,449,723,1003,1275,1565];
  const ys=[272,272,272,272,272,272,534,534,534,534,534,534,771,796,800,799,803,808];
  const x=[200,207,176],ground=[272,534,771];
  await require('./ImportMonsterExpansion.cjs').extractActor({actor:'valentino_1',
    source:path.join(ROOT,'build/qa/motion-refinement/secondary-source.png'),
    rows:['idle','hurt','death'],scale:30/196,x,ground,step:285,
    offsets:Object.fromEntries(xs.map((sx,i)=>[i,[sx-x[Math.floor(i/6)]-285*(i%6),ys[i]-ground[Math.floor(i/6)]]])),
    palette:PALETTES.valentino_1,outputDir:secondaryDir});
  result.secondary={};
  for(const motion of ['idle','hurt','death']) {
    result.secondary[motion]=await Promise.all(Array.from({length:6},(_,f)=>
      sharp(path.join(secondaryDir,motion,f+'.png')).ensureAlpha().raw().toBuffer()));
  }
  result.secondary.idle[0]=Buffer.from(ready);
  result.secondary.idle[5]=Buffer.from(ready);
  result.secondary.hurt[0]=Buffer.from(ready);
  result.secondary.hurt[5]=Buffer.from(ready);
  result.secondary.death[0]=Buffer.from(ready);
  return result;
}

async function run(actor) {
  const d=defs[actor]; assert(d,'Unknown actor');
  const refined=actor==='valentino_1' ? await refinedHero() : null;
  const {data,w,h}=await keyed(path.join(QA,actor+'-motion-source.png'));
  const grouped=Array.from({length:d.rows.length*6},()=>[]);
  for(const c of components(data,w,h)){
    const col=Math.max(0,Math.min(5,Math.floor((c.x0+c.x1)/2/(w/6))));
    const row=Math.max(0,Math.min(d.rows.length-1,Math.floor((c.y0+c.y1)/2/(h/d.rows.length))));
    grouped[row*6+col].push(c);
  }
  const tiles=[], reports=[];
  for(let r=0;r<d.rows.length;r++)for(let c=0;c<6;c++){
    const parts=grouped[r*6+c]; assert(parts.length,`Missing ${actor}/${r}/${c}`);
    let rgba=Buffer.alloc(64*64*4);
    const allowed=new Uint8Array(w*h);
    for(const part of parts)for(const i of part.pixels)allowed[i]=1;
    // Sample at logical pixel centres, always against the same actor scale and anchors.
    for(let y=0;y<64;y++)for(let x=0;x<64;x++){
      const sx=Math.floor(d.x[r]+d.step*c+(x+0.5-32)/d.scale);
      const sy=Math.floor(d.ground[r]+(y+0.5-48)/d.scale);
      if(sx>=0&&sx<w&&sy>=0&&sy<h&&allowed[sy*w+sx])data.copy(rgba,(y*64+x)*4,(sy*w+sx)*4,(sy*w+sx+1)*4);
    }
    if(actor==='valentino_1' && d.rows[r]==='walk'){
      // Reviewed neutral matte specks along boot soles; armour and blade whites are retained.
      for(let y=44;y<50;y++)for(let x=0;x<64;x++){
        const i=(y*64+x)*4, rgb=[rgba[i],rgba[i+1],rgba[i+2]];
        if(Math.min(...rgb)>=170 && Math.max(...rgb)-Math.min(...rgb)<=15)rgba.fill(0,i,i+4);
      }
      const edits=JSON.parse(fs.readFileSync(path.join(__dirname,'pixel_pilot_sword_patches.json'),'utf8'));
      for(const p of edits.frames[String(c)] || []){
        const i=(p.y*64+p.x)*4;
        assert(rgba[i+3]===0,'Sword addition overlaps a protected body pixel');
        Buffer.from(p.hex.replace('#','')+'ff','hex').copy(rgba,i);
      }
    }
    const replaced=refined && (refined[d.rows[r]] || (d.rows[r]==='special' && [0,5].includes(c)));
    if(replaced)rgba=Buffer.from(refined[d.rows[r]] ? refined[d.rows[r]][c] : refined.ready);
    // Map every frame to the same 24 colours extracted from the approved style roster.
    // This Sharp build rounds PNG colour limits above 16 to 256, so use an explicit map.
    const palette=PALETTES[actor].map(hex=>Buffer.from(hex,'hex'));
    for(let i=0;i<rgba.length;i+=4)if(rgba[i+3]){
      let best=palette[0], distance=Infinity;
      for(const p of palette){
        const error=(rgba[i]-p[0])**2+(rgba[i+1]-p[1])**2+(rgba[i+2]-p[2])**2;
        if(error<distance){distance=error;best=p;}
      }
      best.copy(rgba,i);
    }
    const patch=EDGE_PATCHES[actor]?.[d.rows[r]]?.[String(c)];
    if(patch && !replaced) {
      assert(crypto.createHash('sha256').update(rgba).digest('hex')===patch.source_rgba_sha256,
        `${actor}/${d.rows[r]}/${c}: stale edge patch; review changed source before applying`);
      for(const edit of patch.edits) {
        const i=(edit.y*64+edit.x)*4;
        assert(rgba.subarray(i,i+4).equals(Buffer.from(edit.from)),'Edge patch source pixel changed');
        Buffer.from(edit.to).copy(rgba,i);
      }
    }
    tiles.push(rgba);
    reports.push({motion:d.rows[r],frame:c,parts:parts.map(({pixels,...p})=>p),anchor:[d.x[r]+d.step*c,d.ground[r]],scale:d.scale});
  }
  // Frames already share the actor palette; avoid a second format-level quantization.
  const atlas=await sharp({create:{width:384,height:64*d.rows.length,channels:4,background:'#00000000'}})
    .composite(tiles.map((input,i)=>({input,raw:{width:64,height:64,channels:4},left:(i%6)*64,top:Math.floor(i/6)*64})))
    .png().toBuffer();
  const out=path.join(QA,'motion',actor); fs.mkdirSync(out,{recursive:true});
  if(refined) {
    for(const [motion,frames] of Object.entries(refined.secondary))
    for(const dir of [path.join(out,motion), ...(process.argv.includes('--write-assets') ? [path.join(ROOT,'assets/anim/pixel_pilot',actor,motion)] : [])]) {
      fs.mkdirSync(dir,{recursive:true});
      for(let f=0;f<frames.length;f++) {
        const guard=(motion==='idle' && [0,5].includes(f)) || (motion==='hurt' && [0,5].includes(f)) || (motion==='death' && f===0);
        const raw=guard ? tiles[d.rows.indexOf('attack')*6] : frames[f];
        let img=sharp(raw,{raw:{width:64,height:64,channels:4}});
        if(dir.includes(path.join('assets','anim')))img=img.flop();
        await img.png().toFile(path.join(dir,f+'.png'));
      }
    }
  }
  await sharp(atlas).toFile(path.join(out,'atlas.png'));
  const preview=[];
  for(let r=0;r<d.rows.length;r++){
    const title=Buffer.from(`<svg width="1152" height="24"><text x="12" y="17" fill="#e7ddd0" font-family="Arial" font-size="15">${actor} / ${d.rows[r]} — contact frame 3 for attacks</text></svg>`);
    preview.push({input:title,left:0,top:r*216});
    for(let c=0;c<6;c++){
      let raw=await sharp(atlas).extract({left:c*64,top:r*64,width:64,height:64}).ensureAlpha().raw().toBuffer();
      for(let i=0;i<4096;i++)raw[i*4+3]=raw[i*4+3]>=128?255:0;
      const png=await sharp(raw,{raw:{width:64,height:64,channels:4}}).png().toBuffer();
      const dir=path.join(out,d.rows[r]);fs.mkdirSync(dir,{recursive:true});
      await sharp(png).toFile(path.join(dir,c+'.png'));
      const sized=await sharp(png).resize(192,192,{kernel:'nearest'}).png().toBuffer();
      preview.push({input:sized,left:c*192,top:r*216+24});
      if(process.argv.includes('--write-assets')){
        const dst=path.join(ROOT,'assets/anim/pixel_pilot',actor,d.rows[r]);fs.mkdirSync(dst,{recursive:true});
        let img=sharp(png);if(d.mirror)img=img.flop();await img.png().toFile(path.join(dst,c+'.png'));
      }
    }
  }
  await sharp({create:{width:1152,height:d.rows.length*216,channels:4,background:'#222633'}}).composite(preview).png().toFile(path.join(out,'preview.png'));
  const secondaryFrames=refined ? Object.values(refined.secondary).reduce((n,frames)=>n+frames.length,0) : 0;
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify({actor,source:[w,h],status:'extracted; visual motion review required',frameCount:tiles.length+secondaryFrames,coreFrameCount:tiles.length,secondaryFrameCount:secondaryFrames,frames:reports},null,2));
  console.log(`${actor}: ${tiles.length+secondaryFrames} fixed-anchor 64px frames -> ${out}`);
}
module.exports = {keyed, components};
if(require.main===module)(async()=>{for(const actor of process.argv.slice(2).filter(x=>!x.startsWith('--')))await run(actor);})().catch(e=>{console.error(e);process.exit(1);});
