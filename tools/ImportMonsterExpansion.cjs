// Mechanical extraction: one scale per actor, fixed logical 64px canvas and y48 ground.
const sharp = require('sharp');
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const ROOT = path.resolve(__dirname, '..');
const QA = path.join(ROOT, 'build/qa/monster-expansion');
const ROWS = ['walk', 'dash', 'attack', 'special'];

async function keyed(file) {
  const {data,info} = await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
  let removed=0;
  for(let i=0;i<data.length;i+=4) {
    const r=data[i],g=data[i+1],b=data[i+2];
    // Magenta is the requested non-art matte, including enclosed limb gaps.
    // Dark purple bats, blue armour and warm pink flesh are never keyed by hue alone.
    if(data[i+3]<128 || (r>170 && b>170 && g<90 && r-g>110 && b-g>110)) {
      data.fill(0,i,i+4); removed++;
    } else data[i+3]=255;
  }
  return {data,w:info.width,h:info.height,removed};
}

function components(data,w,h,minPixels=8) {
  const seen=new Uint8Array(w*h),queue=new Int32Array(w*h),out=[];
  for(let start=0;start<w*h;start++) {
    if(seen[start] || !data[start*4+3])continue;
    let head=0,tail=1,x0=w,y0=h,x1=0,y1=0;
    queue[0]=start;seen[start]=1;
    while(head<tail) {
      const i=queue[head++],x=i%w,y=(i/w)|0;
      x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);
      for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++) {
        const xx=x+dx,yy=y+dy,j=yy*w+xx;
        if(xx>=0 && xx<w && yy>=0 && yy<h && !seen[j] && data[j*4+3]) {
          seen[j]=1;queue[tail++]=j;
        }
      }
    }
    if(tail>=minPixels)out.push({x0,y0,x1,y1,count:tail,pixels:queue.slice(0,tail)});
  }
  return out;
}

function groupComponents(data,w,h,rows=4,minPixels=8) {
  const groups=Array.from({length:rows*6},()=>[]);
  for(const c of components(data,w,h,minPixels)) {
    const col=Math.min(5,Math.max(0,Math.floor((c.x0+c.x1)*.5/(w/6))));
    const row=Math.min(rows-1,Math.max(0,Math.floor((c.y0+c.y1)*.5/(h/rows))));
    groups[row*6+col].push(c);
  }
  return groups;
}

function bounds(parts) {
  return {x0:Math.min(...parts.map(p=>p.x0)),y0:Math.min(...parts.map(p=>p.y0)),
    x1:Math.max(...parts.map(p=>p.x1)),y1:Math.max(...parts.map(p=>p.y1))};
}

async function paletteFrom(file,limit=24) {
  const {data}=await keyed(file),freq=new Map();
  for(let i=0;i<data.length;i+=4)if(data[i+3]) {
    const hex=data.subarray(i,i+3).toString('hex');freq.set(hex,(freq.get(hex)||0)+1);
  }
  if(freq.size<=limit)return [...freq.keys()];
  // Retain source identity: select common colours, then farthest source colours for accents.
  const sorted=[...freq].sort((a,b)=>b[1]-a[1]);
  const chosen=sorted.slice(0,Math.min(12,limit)).map(([hex])=>hex);
  while(chosen.length<limit) {
    let best='',score=-1;
    for(const [hex,count] of sorted) {
      if(chosen.includes(hex))continue;
      const rgb=Buffer.from(hex,'hex');
      const distance=Math.min(...chosen.map(c=>{
        const p=Buffer.from(c,'hex');return (rgb[0]-p[0])**2+(rgb[1]-p[1])**2+(rgb[2]-p[2])**2;
      }));
      const value=distance*Math.min(1,count/3);
      if(value>score){best=hex;score=value;}
    }
    if(!best)break;chosen.push(best);
  }
  return chosen;
}

async function extractActor(cfg) {
  const {actor,source}=cfg,rows=cfg.rows||ROWS;
  const {data,w,h,removed}=await keyed(source);
  const groups=groupComponents(data,w,h,rows.length,cfg.minComponentPixels??8),step=cfg.step||w/6;
  assert(cfg.scale>0 && cfg.x.length===rows.length && cfg.ground.length===rows.length);
  const palette=(cfg.palette||await paletteFrom(cfg.reference)).map(p=>Buffer.from(p.replace('#',''),'hex'));
  assert(palette.length>0 && palette.length<=24,'Expected an actor-shared palette <=24 colours');
  const output=cfg.outputDir||path.join(QA,actor),tiles=[],frames=[],warnings=[];
  fs.mkdirSync(output,{recursive:true});
  for(let row=0;row<rows.length;row++)for(let col=0;col<6;col++) {
    const index=row*6+col,sourceFrame=cfg.frameRemap?.[index] ?? index;
    const sourceRow=Math.floor(sourceFrame/6),sourceCol=sourceFrame%6,allParts=groups[sourceFrame];
    // Optional source-only particle exclusion; never used for articulated weapons/limbs.
    const minCount=cfg.componentMinFraction?Math.max(...allParts.map(p=>p.count))*cfg.componentMinFraction:0;
    const parts=allParts.filter(p=>p.count>=minCount);
    assert(parts.length,`Empty source ${actor}/${rows[row]}/${col}`);
    const b=bounds(parts),offset=cfg.offsets?.[sourceFrame]||[0,0];
    const anchor=[cfg.x[sourceRow]+step*sourceCol+offset[0],cfg.ground[sourceRow]+offset[1]];
    const allowed=new Uint8Array(w*h),rgba=Buffer.alloc(64*64*4);
    for(const p of parts)for(const i of p.pixels)allowed[i]=1;
    let mapped=0,lost=0;
    for(const p of parts)for(const i of p.pixels) {
      const nx=Math.floor((i%w-anchor[0])*cfg.scale+32);
      const ny=Math.floor(((i/w|0)-anchor[1])*cfg.scale+48);
      if(nx<0||nx>=64||ny<0||ny>=64)lost++;
    }
    assert(lost===0,`${actor}/${rows[row]}/${col}: ${lost} source pixels outside action canvas`);
    for(let y=0;y<64;y++)for(let x=0;x<64;x++) {
      const sx=Math.floor(anchor[0]+(x+.5-32)/cfg.scale);
      const sy=Math.floor(anchor[1]+(y+.5-48)/cfg.scale);
      if(sx<0||sx>=w||sy<0||sy>=h||!allowed[sy*w+sx])continue;
      const sourceIndex=(sy*w+sx)*4,outIndex=(y*64+x)*4;
      let best=palette[0],distance=Infinity;
      for(const p of palette) {
        const d=(data[sourceIndex]-p[0])**2+(data[sourceIndex+1]-p[1])**2+(data[sourceIndex+2]-p[2])**2;
        if(d<distance){distance=d;best=p;}
      }
      best.copy(rgba,outIndex);rgba[outIndex+3]=255;mapped++;
    }
    assert(mapped>=12,`${actor}/${rows[row]}/${col}: native frame too empty`);
    const nativeParts=components(rgba,64,64,1),nativeBounds=bounds(nativeParts);
    if(nativeBounds.x0<3||nativeBounds.x1>60||nativeBounds.y0<3||nativeBounds.y1>60)
      warnings.push(`${rows[row]}/${col}: close to native canvas edge`);
    const png=await sharp(rgba,{raw:{width:64,height:64,channels:4}}).png().toBuffer();
    const dir=path.join(output,rows[row]);fs.mkdirSync(dir,{recursive:true});
    fs.writeFileSync(path.join(dir,col+'.png'),png);
    if(cfg.writeAssets) {
      const dst=path.join(ROOT,'assets/anim/pixel_pilot',actor,rows[row]);
      fs.mkdirSync(dst,{recursive:true});fs.writeFileSync(path.join(dst,col+'.png'),png);
    }
    tiles.push(png);
    frames.push({motion:rows[row],frame:col,sourceFrame,sourceBounds:b,anchor,scale:cfg.scale,
      opaquePixels:mapped,nativeBounds,components:nativeParts.length,sourceClippedPixels:lost});
  }
  const atlas=await sharp({create:{width:384,height:rows.length*64,channels:4,background:'#00000000'}})
    .composite(tiles.map((input,i)=>({input,left:i%6*64,top:Math.floor(i/6)*64}))).png().toBuffer();
  fs.writeFileSync(path.join(output,'atlas.png'),atlas);
  await sharp(atlas).resize(1152,rows.length*192,{kernel:'nearest'}).flatten({background:'#242834'})
    .png().toFile(path.join(output,'native-3x.png'));
  const preview=[];
  for(let row=0;row<rows.length;row++) {
    const title=Buffer.from(`<svg width="1152" height="24"><text x="12" y="17" font-family="Arial" font-size="14" fill="#ece3cf">${actor} / ${rows[row]} | LEFT / contact 3</text></svg>`);
    preview.push({input:title,left:0,top:row*216});
    for(let col=0;col<6;col++)preview.push({input:await sharp(tiles[row*6+col]).resize(192,192,{kernel:'nearest'}).png().toBuffer(),left:col*192,top:row*216+24});
  }
  await sharp({create:{width:1152,height:rows.length*216,channels:4,background:'#242834'}})
    .composite(preview).png().toFile(path.join(output,'preview.png'));
  for(let row=0;row<rows.length;row++) {
    // Native poses only: GIF does not interpolate or synthesize in-between artwork.
    const rawFrames=await Promise.all(tiles.slice(row*6,row*6+6).map(png=>sharp(png).resize(256,256,{kernel:'nearest'}).flatten({background:'#242834'}).removeAlpha().raw().toBuffer()));
    await sharp(Buffer.concat(rawFrames),{raw:{width:256,height:256*6,channels:3,pageHeight:256}})
      .gif({loop:0,delay:cfg.delays?.[rows[row]]||[80,80,80,80,80,80],colours:32,dither:0})
      .toFile(path.join(output,rows[row]+'.gif'));
  }
  const report={actor,source,sourceSize:[w,h],status:'extracted; visual review required',
    validationScope:'Dimensions/alpha/shared palette/no clipping only; not an animation quality approval.',
    frameCount:tiles.length,scale:cfg.scale,palette:palette.map(p=>p.toString('hex')),
    keyedPixels:removed,warnings,frames};
  fs.writeFileSync(path.join(output,'report.json'),JSON.stringify(report,null,2));
  return report;
}

module.exports={keyed,components,groupComponents,bounds,paletteFrom,extractActor};
if(require.main===module) {
  (async()=>{
    const configs=JSON.parse(fs.readFileSync(path.join(QA,'config.json'),'utf8'));
    for(const actor of process.argv.slice(2).filter(a=>!a.startsWith('--'))) {
      assert(configs[actor],'Unknown actor: '+actor);
      const report=await extractActor({...configs[actor],actor,
        writeAssets:process.argv.includes('--write-assets')});
      console.log(`${actor}: ${report.frameCount} native64 frames, palette ${report.palette.length}, warnings ${report.warnings.length}`);
    }
  })().catch(error=>{console.error(error);process.exitCode=1;});
}
