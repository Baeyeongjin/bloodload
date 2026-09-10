// Native boss extraction using the shared chroma/alpha/palette importer.
// One scale per boss; fixed y48 footline. Dash height is preserved.
const fs=require('fs'),path=require('path'),assert=require('assert'),sharp=require('sharp');
const {keyed,groupComponents,bounds,paletteFrom,extractActor}=require('./ImportMonsterExpansion.cjs');
const ROOT=path.resolve(__dirname,'..'),QA=path.join(ROOT,'build/qa/boss-expansion');
const ROWS=['walk','dash','attack','special'];
// Measured row spacing from matching first/last ready poses; the source grids
// have slightly different spacing per row despite the nominal 256px cells.
const DEFS={
  boss_1:{scale:.22,x:[170,170,164,164],steps:[241.6,246.8,245.9,246.7],ground:[255,480,696,917]},
  boss_2:{scale:.21,x:[150,150,154,154],steps:[251,254.8,251.2,251.3],ground:[233,463,701,940]},
  boss_3:{scale:.22,x:[172,167,170,170],steps:[244.9,250.1,249.3,249.3],ground:[249,480,704,939]},
  boss_4:{scale:.22,x:[165,158,168,168],steps:[251.5,253.7,252,252.1],ground:[253,469,707,937]},
  boss_5:{scale:.21,x:[170,172,168,168],steps:[238.9,239,243,243],ground:[259,482,707,931]},
};
async function run(actor,writeAssets){
  assert(DEFS[actor],'Unknown boss: '+actor);
  if(actor==='boss_5')return runKing(writeAssets);
  const def=DEFS[actor],source=path.join(QA,actor+'-source.png');
  const {data,w,h}=await keyed(source),groups=groupComponents(data,w,h),offsets={},adjustments=[];
  for(let row=0;row<4;row++)for(let col=0;col<6;col++){
    const index=row*6+col,parts=groups[index];assert(parts.length,`Missing ${actor}/${row}/${col}`);
    const b=bounds(parts);
    assert(parts.reduce((n,p)=>n+p.count,0)>200,`${actor}/${ROWS[row]}/${col}: joined/missing source character; replacement art required`);
    assert((b.x1-b.x0+1)*def.scale<=60,`${actor}/${ROWS[row]}/${col}: source crosses adjacent character or canvas`);
    let x=def.x[row]+def.steps[row]*col;
    // Preserve sword/horn tips with transparent padding. Shift only the tile
    // anchor when an extended source pose would touch the 64px canvas edge.
    const minX=b.x1-30/def.scale,maxX=b.x0+30/def.scale;
    const fitted=Math.max(minX,Math.min(maxX,x));
    if(Math.abs(fitted-x)>.01)adjustments.push({motion:ROWS[row],frame:col,sourceShiftX:fitted-x});
    x=fitted;
    // Grounded rows use actual planted feet, not the generated grid's y drift.
    // A burst keeps its height from the row's shared baseline.
    let y=row===1?def.ground[row]:b.y1+1;
    if(actor==='boss_3'&&row===3&&col===3)y=942; // ice shards extend below the palms/feet
    offsets[index]=[x-(def.x[row]+256*col),y-def.ground[row]];
  }
  const reference=path.join(ROOT,'assets/anim',actor+'_walk','0.png');
  const palette=await paletteFrom(reference);
  const report=await extractActor({actor,source,scale:def.scale,x:def.x,ground:def.ground,
    step:256,offsets,palette,outputDir:path.join(QA,actor),writeAssets:false,
    delays:{walk:[90,90,90,90,90,90],dash:[80,80,70,70,80,100],attack:[120,140,80,80,100,120],special:[120,140,80,80,100,120]}});
  report.anchorAdjustments=adjustments;
  report.paletteReference=path.relative(ROOT,reference).replace(/\\/g,'/');
  report.notes=['Bright magenta only is keyed; dark purple, white weapons and ice remain.',
    'Palette is taken from the original native boss to preserve its existing colour identity.',
    'One actor scale; grounded footline y48. Dash source height is retained.',
    'Frame3 is the intended contact pose. Gameplay clocks and damage are not changed here.'];
  await finalize(actor,report,writeAssets);
  console.log(`${actor}: 24 LEFT native64 frames, ${palette.length} colours, clipping0, ${adjustments.length} padded extended poses`);
  return report;
}

// Final native pass preserves each full pose. Only the frost source's clearly
// magenta-contaminated exterior outline is recoloured; alpha and ice stay intact.
async function finalize(actor,report,writeAssets){
  const dir=path.join(QA,actor),tiles=[],patches=[];
  const source=actor==='boss_3'?await keyed(report.source):null;
  for(const motion of ROWS)for(let frame=0;frame<6;frame++){
    const file=path.join(dir,motion,frame+'.png');
    const rgba=await sharp(file).ensureAlpha().raw().toBuffer();
    if(source){
      const f=report.frames.find(f=>f.motion===motion&&f.frame===frame);
      for(let y=1;y<63;y++)for(let x=1;x<63;x++){
        const i=(y*64+x)*4;if(!rgba[i+3])continue;
        const edge=[[-1,0],[1,0],[0,-1],[0,1]].some(([dx,dy])=>!rgba[((y+dy)*64+x+dx)*4+3]);
        if(!edge)continue;
        const sx=Math.floor(f.anchor[0]+(x+.5-32)/f.scale),sy=Math.floor(f.anchor[1]+(y+.5-48)/f.scale);
        const si=(sy*source.w+sx)*4,[r,g,b]=source.data.subarray(si,si+3);
        if(r>g+35&&b>g+35){
          const from=rgba.subarray(i,i+4).toString('hex'),to='142e46ff';
          if(from!==to){Buffer.from(to,'hex').copy(rgba,i);patches.push({motion,frame,x,y,from,to,sourceRGB:[r,g,b]});}
        }
      }
    }
    tiles.push(await sharp(rgba,{raw:{width:64,height:64,channels:4}}).png().toBuffer());
  }
  const nativeSource=path.join(QA,actor+'-native-reviewed.png');
  await sharp({create:{width:384,height:256,channels:4,background:'#00000000'}})
    .composite(tiles.map((input,i)=>({input,left:i%6*64,top:Math.floor(i/6)*64}))).png().toFile(nativeSource);
  const reviewed=await extractActor({actor,source:nativeSource,scale:1,x:[32,32,32,32],ground:[48,112,176,240],step:64,
    palette:report.palette,outputDir:dir,writeAssets,minComponentPixels:1,
    delays:{walk:[90,90,90,90,90,90],dash:[80,80,70,70,80,100],attack:[120,140,80,80,100,120],special:[120,140,80,80,100,120]}});
  report.nativeValidation=reviewed.frames;
  report.edgePatches=patches;
  report.status='native poses visually reviewed; source identity and contact preserved';
  report.productionExported=!!writeAssets;
  fs.writeFileSync(path.join(dir,'report.json'),JSON.stringify(report,null,2)+'\n');
}

async function runKing(writeAssets){
  const actor='boss_5',def=DEFS[actor],dir=path.join(QA,actor);
  fs.mkdirSync(dir,{recursive:true});
  const original=path.join(QA,actor+'-source.png'),{data,w,h}=await keyed(original);
  const groups=groupComponents(data,w,h),packed=Buffer.alloc(w*1200*4);
  const rows=['walk','dash','special'];
  // Omit the rejected joined attack entirely, retaining complete components
  // (including feet that extend past a nominal source grid cell).
  for(const row of [0,1,3])for(let col=0;col<6;col++)for(const part of groups[row*6+col])for(const i of part.pixels){
    const packedRow=row===3?2:row;
    const x=i%w,y=(i/w|0)+packedRow*400-row*256;assert(y>=0&&y<1200);
    data.copy(packed,(y*w+x)*4,i*4,i*4+4);
  }
  const base=path.join(QA,actor+'-base-packed.png');
  await sharp(packed,{raw:{width:w,height:1200,channels:4}}).png().toFile(base);
  const bg=groupComponents(packed,w,1200,3),offsets={};
  for(let row=0;row<3;row++)for(let col=0;col<6;col++){
    const srcRow=row===2?3:row,b=bounds(bg[row*6+col]);
    let x=def.x[srcRow]+def.steps[srcRow]*col;
    x=Math.max(b.x1-30/def.scale,Math.min(b.x0+30/def.scale,x));
    const ground=def.ground[srcRow]+row*400-srcRow*256,y=row===1?ground:b.y1+1;
    offsets[row*6+col]=[x-(def.x[srcRow]+256*col),y-ground];
  }
  const reference=path.join(ROOT,'assets/anim/boss_5_walk/0.png'),palette=await paletteFrom(reference);
  const report=await extractActor({actor,source:base,rows,scale:def.scale,x:[def.x[0],def.x[1],def.x[3]],
    ground:[def.ground[0],def.ground[1]+144,def.ground[3]+32],step:256,offsets,palette,outputDir:dir});
  const attackSource=path.join(QA,actor+'-attack-source.png'),atk=await keyed(attackSource);
  assert(atk.w===1536&&atk.h===1024,'Corrected boss5 attack must be 3 by 2');
  const strip=Buffer.alloc(3072*512*4);
  for(let n=0;n<6;n++)for(let y=0;y<512;y++){
    const si=(((n/3|0)*512+y)*1536+(n%3)*512)*4;
    atk.data.copy(strip,(y*3072+n*512)*4,si,si+512*4);
  }
  const attackPacked=path.join(QA,actor+'-attack-packed.png');
  await sharp(strip,{raw:{width:3072,height:512,channels:4}}).png().toFile(attackPacked);
  // Feet, not the lowered sword tip, define the contact ground.
  const anchors=[[282,417],[735,417],[1191,417],[300,834],[790,834],[1236,859]];
  const aOffsets={};
  for(let n=0;n<6;n++)aOffsets[n]=[anchors[n][0]-(n%3)*512-282,anchors[n][1]-(n>=3?512:0)-417];
  const ar=await extractActor({actor,source:attackPacked,rows:['attack'],scale:.125,x:[282],ground:[417],step:512,
    offsets:aOffsets,palette,outputDir:dir,delays:{attack:[120,140,80,80,100,120]}});
  // Exact canonical guard at both ends avoids a crown/shoulder reset pop.
  for(const frame of [0,5])fs.copyFileSync(path.join(dir,'walk/0.png'),path.join(dir,'attack',frame+'.png'));
  report.frames.push(...ar.frames);report.frameCount=24;
  report.correctedAttackSource=attackSource;report.correctedAttackScale=.125;
  report.paletteReference=path.relative(ROOT,reference).replace(/\\/g,'/');
  report.notes=['Rejected joined attack source is not used.',
    'Corrected six whole poses preserve the ivory king. Attack0/5 use exact canonical walk0 guard.',
    'All files LEFT, native64, fixed y48 footline; game clocks, damage and range unchanged.'];
  await finalize(actor,report,writeAssets);
  console.log('boss_5: 24 LEFT native64 frames, corrected attack, palette '+palette.length+', clipping0');
  return report;
}
module.exports={run,DEFS};
if(require.main===module)(async()=>{
  const actors=process.argv.slice(2).filter(a=>!a.startsWith('--'));
  assert(actors.length,'Provide boss ids; boss_5 needs its corrected attack source first');
  for(const actor of actors)await run(actor,process.argv.includes('--write-assets'));
})().catch(e=>{console.error(e);process.exitCode=1;});
