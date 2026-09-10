// Reuse the roster extractor: actor-shared source scale and existing native palette.
const fs=require('fs'),path=require('path'),assert=require('assert');
const {keyed,groupComponents,bounds,paletteFrom,extractActor}=require('./ImportMonsterExpansion.cjs');
const ROOT=path.resolve(__dirname,'..'),QA=path.join(ROOT,'build/qa/event-bosses');
const SIZES={crystal_golem:34,vine_colossus:34,bloodmoon_avatar:34,drowned_king:34,usurper:32,plague_hag:32,bone_choir:34,blood_queen:32,butcher:34,ruin_warden:34,sanctum_guardian:34};
const JUMP=new Set(['drowned_king','ruin_warden','sanctum_guardian']);

function footX(parts,w) {
  const b=bounds(parts),xs=[];
  for(const p of parts)for(const i of p.pixels)if((i/w|0)>=b.y1-3)xs.push(i%w);
  return (Math.min(...xs)+Math.max(...xs))/2;
}

async function run(actor) {
  assert(SIZES[actor],'Unknown event actor: '+actor);
  const source=path.join(QA,actor+'-source.png'),s=await keyed(source);
  const groups=groupComponents(s.data,s.w,s.h,4,8),step=s.w/6;
  const x=[],ground=[],offsets={};
  const b0=bounds(groups[0]),scale=SIZES[actor]/(b0.y1-b0.y0+1);
  for(let row=0;row<4;row++) {
    const start=footX(groups[row*6],s.w),stride=(footX(groups[row*6+5],s.w)-start)/5;
    x.push(start);ground.push(bounds(groups[row*6]).y1+1);
    for(let col=0;col<6;col++) {
      const i=row*6+col,b=bounds(groups[i]);
      offsets[i]=[(stride-step)*col,(row===1||(row===3&&JUMP.has(actor)))?0:b.y1+1-ground[row]];
    }
  }
  if(actor==='vine_colossus') {
    // A small counter-lean keeps the attached whip three pixels inside the canvas.
    for(let c=0;c<6;c++)offsets[18+c][0]-=[0,1,2,3,2,0][c]/scale;
  }
  // Keep the returning rapier's narrow silver core on the native pixel grid.
  if(actor==='usurper')offsets[16][1]-=2;
  const cfg={actor,source,scale,x,ground,step,offsets,
    palette:await paletteFrom(path.join(ROOT,'assets/enemies',actor+'.png')),
    outputDir:path.join(QA,actor),writeAssets:process.argv.includes('--write-assets')};
  fs.writeFileSync(path.join(QA,actor+'-config.json'),JSON.stringify(cfg,null,2));
  const report=await extractActor(cfg);
  console.log(JSON.stringify({actor,frames:report.frameCount,scale,x,ground,warnings:report.warnings}));
}

if(require.main===module)(async()=>{
  for(const actor of process.argv.slice(2).filter(x=>!x.startsWith('--')))await run(actor);
})().catch(error=>{console.error(error);process.exitCode=1});
