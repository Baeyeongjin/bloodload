// Isotropic nearest-neighbor sampling, ground-aware crop, and a discrete tile seam.
const fs=require('fs'),path=require('path'),sharp=require('sharp'),assert=require('assert');
const ROOT=path.resolve(__dirname,'..'),QA=path.join(ROOT,'build/qa/background-refresh');
const W=768,H=208,OVERLAP=24,OUT_W=W-OVERLAP,GROUND=145;
// Native ground rows reviewed from the resized source; no vertical stretching.
const GROUNDS={};

function groundRow(data,h){
  const lum=[];
  for(let y=0;y<h;y++){
    const row=[];for(let x=0;x<W;x++) {const i=(y*W+x)*3;row.push(data[i]*.3+data[i+1]*.59+data[i+2]*.11);}
    row.sort((a,b)=>a-b);lum.push(row[W/2]);
  }
  let best=-Infinity,at=GROUND;
  for(let y=GROUND;y<=h-(H-GROUND);y++){
    const score=lum[y-3]-lum[y+3];if(score>best){best=score;at=y;}
  }
  return at;
}

function stitch(data){
  // Minimum-error overlap cut chooses existing pixels; it never blends or blurs.
  const costs=[],prev=[];
  for(let y=0;y<H;y++){
    costs[y]=Array(OVERLAP).fill(Infinity);prev[y]=Array(OVERLAP).fill(0);
    for(let x=1;x<OVERLAP-1;x++){
      let colorCost=0;for(let c=0;c<3;c++)colorCost+=Math.abs(data[(y*W+x)*3+c]-data[(y*W+OUT_W+x)*3+c]);
      let parent=x;
      if(y)for(let p=Math.max(1,x-1);p<=Math.min(OVERLAP-2,x+1);p++)if(costs[y-1][p]<costs[y-1][parent])parent=p;
      costs[y][x]=colorCost+(y?costs[y-1][parent]:0);prev[y][x]=parent;
    }
  }
  const seam=Array(H);seam[H-1]=costs[H-1].indexOf(Math.min(...costs[H-1]));
  for(let y=H-2;y>=0;y--)seam[y]=prev[y+1][seam[y+1]];
  const result=Buffer.alloc(OUT_W*H*3);
  for(let y=0;y<H;y++)for(let x=0;x<OUT_W;x++){
    const sx=x<seam[y]?OUT_W+x:x;data.copy(result,(y*OUT_W+x)*3,(y*W+sx)*3,(y*W+sx)*3+3);
  }
  return {data:result,seam};
}

async function run(name){
  const source=path.join(QA,name+'-source.png'),dir=path.join(QA,name);
  fs.mkdirSync(dir,{recursive:true});
  const original=await sharp(source).metadata();
  const {data,info}=await sharp(source).resize({width:W,kernel:'nearest'}).removeAlpha().raw().toBuffer({resolveWithObject:true});
  assert(info.height>=H,'Source does not contain enough vertical crop room');
  const ground=GROUNDS[name]??groundRow(data,info.height),top=ground-GROUND;
  assert(top>=0&&top+H<=info.height,'Ground crop would leave a gap');
  const cropped=Buffer.from(data.subarray(top*W*3,(top+H)*W*3)),tile=stitch(cropped);
  const quantized=await sharp(tile.data,{raw:{width:OUT_W,height:H,channels:3}}).png({palette:true,colours:48,dither:0}).toBuffer();
  const png=await sharp(quantized).ensureAlpha().png({palette:false}).toBuffer();
  fs.writeFileSync(path.join(dir,'native.png'),png);
  await sharp(png).resize(OUT_W*2,H*2,{kernel:'nearest'}).png().toFile(path.join(dir,'native-2x.png'));
  const tripled=await sharp({create:{width:OUT_W*3,height:H,channels:4,background:'#000000'}}).composite([0,1,2].map(i=>({input:png,left:i*OUT_W,top:0}))).png().toBuffer();
  await sharp(tripled).extract({left:OUT_W-180,top:0,width:360,height:H}).resize(720,H*2,{kernel:'nearest'}).png().toFile(path.join(dir,'seam-2x.png'));
  const {data:rgba}=await sharp(png).raw().toBuffer({resolveWithObject:true});
  const colors=new Set();for(let i=0;i<rgba.length;i+=4){assert(rgba[i+3]===255);colors.add(rgba.subarray(i,i+3).toString('hex'));}
  assert(colors.size<=48);
  const report={name,source,sourceSize:[original.width,original.height],isotropicScale:W/original.width,resizedHeight:info.height,cropTop:top,sourceNativeGround:ground,finalSize:[OUT_W,H],ground:GROUND,colors:colors.size,seamMin:Math.min(...tile.seam),seamMax:Math.max(...tile.seam),alpha:'fully opaque',seamMethod:'minimum-error discrete overlap cut; no blending'};
  fs.writeFileSync(path.join(dir,'report.json'),JSON.stringify(report,null,2));
  if(process.argv.includes('--write-assets'))fs.writeFileSync(path.join(ROOT,'assets/bg','wide_'+name+'.png'),png);
  console.log(JSON.stringify(report));
}
if(require.main===module)(async()=>{for(const name of process.argv.slice(2).filter(x=>!x.startsWith('--')))await run(name);})().catch(e=>{console.error(e);process.exitCode=1});
