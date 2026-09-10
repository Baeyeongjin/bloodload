const fs=require('fs'),path=require('path'),sharp=require('sharp');
const {keyed,groupComponents,bounds,paletteFrom,extractActor}=require('./ImportMonsterExpansion.cjs');
const ROOT=path.resolve(__dirname,'..'),QA=path.join(ROOT,'build/qa/forest-monsters');
const SIZES={zombie:30,ghoul:30,mushroom:27,fire_imp:29,lava_toad:23,gargoyle:32,demon:32};

function feet(parts,data,w) {
  const b=bounds(parts),allowed=new Set(parts.flatMap(p=>Array.from(p.pixels))),xs=[];
  for(let y=b.y1-3;y<=b.y1;y++)for(let x=b.x0;x<=b.x1;x++)if(allowed.has(y*w+x))xs.push(x);
  return (Math.min(...xs)+Math.max(...xs))/2;
}

async function run(actor) {
  const source=path.join(ROOT,'build/qa/monster-expansion',actor+'-source.png');
  const s=await keyed(source),groups=groupComponents(s.data,s.w,s.h).map(parts=>{
    // These seven actors have no detached equipment. Generated spores/ground grit
    // must not become a neighboring pose's footline or a floating character.
    const max=Math.max(...parts.map(p=>p.count));return parts.filter(p=>p.count>=max*.02);
  }),x=[],ground=[],offsets={};
  const scale=SIZES[actor]/(bounds(groups[0]).y1-bounds(groups[0]).y0+1);
  const step=s.w/6;
  for(let row=0;row<4;row++) {
    const first=groups[row*6],last=groups[row*6+5];
    const start=feet(first,s.data,s.w),stride=(feet(last,s.data,s.w)-start)/5;
    x.push(start);ground.push(bounds(first).y1+1);
    for(let col=0;col<6;col++) {
      const i=row*6+col,b=bounds(groups[i]);
      // Grounded poses share a footline; dash retains the authored airborne arc.
      offsets[i]=[(stride-step)*col,row===1 ? 0 : b.y1+1-ground[row]];
    }
  }
  const cfg={actor,source,scale,x,ground,step,offsets,
    componentMinFraction:.02,
    frameRemap:actor==='zombie'?{21:22,22:18}:{},
    palette:await paletteFrom(path.join(ROOT,'assets/enemies',actor+'.png')),
    outputDir:path.join(QA,actor),writeAssets:process.argv.includes('--write-assets')};
  fs.mkdirSync(QA,{recursive:true});fs.writeFileSync(path.join(QA,actor+'-config.json'),JSON.stringify(cfg,null,2));
  const report=await extractActor(cfg);
  console.log(JSON.stringify({actor,scale,x,ground,warnings:report.warnings}));
}

if(require.main===module)(async()=>{for(const actor of process.argv.slice(2).filter(x=>!x.startsWith('--')))await run(actor);})().catch(e=>{console.error(e);process.exitCode=1});
