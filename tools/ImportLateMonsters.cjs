const fs=require('fs'),path=require('path'),sharp=require('sharp'),assert=require('assert');
const {keyed,groupComponents,bounds,paletteFrom,extractActor}=require('./ImportMonsterExpansion.cjs');
const ROOT=path.resolve(__dirname,'..'),QA=path.join(ROOT,'build/qa/late-monsters');
const SIZES={moon_moth:32,blood_acolyte:30,blood_raven:32,swamp_leech:17,bog_wisp:30,royal_guard:32,royal_hound:28};
const FLYING=new Set(['moon_moth','blood_raven','bog_wisp']);

function feet(parts,w) {
  const b=bounds(parts),xs=[];
  for(const p of parts)for(const i of p.pixels)if((i/w|0)>=b.y1-3)xs.push(i%w);
  return (Math.min(...xs)+Math.max(...xs))/2;
}

async function run(actor) {
  assert(SIZES[actor],'Unknown late monster: '+actor);
  const original=path.join(QA,actor+'-source.png'),source=path.join(QA,actor+'-keyed.png'),s=await keyed(original);
  // The magenta matte bleeds into a few edge samples. Remove only strongly
  // saturated magenta, preserving the raven's muted purple feather colours.
  let fringe=0;
  for(let i=0;i<s.data.length;i+=4) {
    if(actor==='blood_raven')continue; // Dark purple is the raven's actual feather colour.
    const r=s.data[i],g=s.data[i+1],b=s.data[i+2];
    if(s.data[i+3] && r>65 && b>65 && g<20 && r/b>.6 && r/b<1.8) {s.data.fill(0,i,i+4);fringe++;}
  }
  const alpha=Buffer.from(s.data);
  for(let y=2;y<s.h-2;y++)for(let x=2;x<s.w-2;x++) {
    if(actor==='blood_raven')continue;
    const i=(y*s.w+x)*4,r=alpha[i],g=alpha[i+1],b=alpha[i+2];
    if(!alpha[i+3]||r<=45||b<=45||g>=60||b<=g*1.6||r<=g*1.6||r/b<=.6||r/b>=2.2)continue;
    let edge=false;
    for(let dy=-2;dy<=2&&!edge;dy++)for(let dx=-2;dx<=2;dx++)if(!alpha[((y+dy)*s.w+x+dx)*4+3]){edge=true;break;}
    if(edge){s.data.fill(0,i,i+4);fringe++;}
  }
  if(actor==='moon_moth') {
    // Two source poses include a detached pale-purple afterimage. Body wings
    // are white/blue; remove the purple trail so runtime VFX owns the trail.
    for(const [x0,y0,x1,y1] of [[642,394,750,445],[908,389,1018,445]])
      for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++) {
        const i=(y*s.w+x)*4,r=s.data[i],g=s.data[i+1],b=s.data[i+2];
        if(s.data[i+3] && b>r*1.025 && r>g*1.025) {s.data.fill(0,i,i+4);fringe++;}
      }
  }
  await sharp(s.data,{raw:{width:s.w,height:s.h,channels:4}}).png().toFile(source);
  const groups=groupComponents(s.data,s.w,s.h).map(parts=>{
    // No actor in this set has detached equipment. Exclude small loose matte specks.
    const largest=Math.max(...parts.map(p=>p.count));return parts.filter(p=>p.count>=largest*.015);
  });
  const walkBounds=groups.slice(0,6).map(bounds),first=walkBounds[0];
  const height=FLYING.has(actor)?Math.max(...walkBounds.map(b=>b.y1-b.y0+1)):first.y1-first.y0+1;
  const scale=SIZES[actor]/height,step=s.w/6,x=[],ground=[],offsets={};
  for(let row=0;row<4;row++) {
    const pivot=parts=>actor==='bog_wisp'?(bounds(parts).x0+bounds(parts).x1)/2:feet(parts,s.w);
    const start=pivot(groups[row*6]),end=pivot(groups[row*6+5]),stride=(end-start)/5;
    x.push(start);ground.push(bounds(groups[row*6]).y1+1);
    for(let col=0;col<6;col++) {
      const i=row*6+col,b=bounds(groups[i]);
      offsets[i]=[(stride-step)*col,FLYING.has(actor)||row===1||actor==='royal_hound'&&row===3?0:b.y1+1-ground[row]];
    }
  }
  const cfg={actor,source,scale,x,ground,step,offsets,componentMinFraction:.015,
    palette:await paletteFrom(path.join(ROOT,'assets/enemies',actor+'.png')),
    outputDir:path.join(QA,actor),writeAssets:process.argv.includes('--write-assets')};
  fs.writeFileSync(path.join(QA,actor+'-config.json'),JSON.stringify(cfg,null,2));
  const report=await extractActor(cfg);
  console.log(JSON.stringify({actor,scale,x,ground,fringe,warnings:report.warnings}));
}

if(require.main===module)(async()=>{for(const actor of process.argv.slice(2).filter(a=>!a.startsWith('--')))await run(actor);})().catch(e=>{console.error(e);process.exitCode=1});
