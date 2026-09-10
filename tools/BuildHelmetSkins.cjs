// Approved roster helmets on the reviewed Valentino body. No pose interpolation.
// Default: QA only. --write-assets exports LEFT-facing 64px frames for eight skins.
const fs = require('fs'), path = require('path'), sharp = require('sharp'), assert = require('assert');
const ROOT = path.resolve(__dirname, '..');
const QA = path.join(ROOT, 'build/qa/helmet-skins');
const BASE = path.join(ROOT, 'assets/anim/pixel_pilot/valentino_1');
const ROSTER = path.join(ROOT, 'build/qa/redesign-32');
const SKINS = ['demon_king','dragon','shadow','emperor','grim','abyss','hawaii','pink'];
const CLIPS = ['idle','walk','dash','attack','attack2','heavy','special','hurt','death'];
// Inclusive native source rows: [y0,y1,x0,x1]. These cut at the helmet/neck,
// excluding the roster's different body, weapons, cape and summer parrot.
const HELMETS = {
  demon_king: {neck:[15,16], rows:[[3,8,3,27],[9,10,11,21],[11,13,10,21],[14,15,12,20]]},
  dragon: {neck:[16,16], rows:[[1,5,7,19],[6,10,6,22],[11,15,6,24]]},
  shadow: {neck:[17,16], rows:[[4,9,7,23],[10,14,6,23],[15,15,11,21]]},
  emperor: {neck:[15,16], rows:[[1,6,8,20],[7,15,9,20]]},
  grim: {neck:[15,18], rows:[[1,5,12,17],[6,10,9,19],[11,14,8,20],[15,17,10,19]]},
  abyss: {neck:[16,16], rows:[[2,5,10,20],[6,11,4,24],[12,15,10,20]]},
  hawaii: {neck:[13,16], rows:[[3,6,7,16],[7,9,3,20],[10,15,7,17]]},
  pink: {neck:[16,16], rows:[[3,10,7,24],[11,15,12,21]]},
};
// Tiny matte remnants reviewed against the full approved roster. Ivory wings,
// the skull face, metal reflections and eye colours are deliberately untouched.
const HELMET_EDITS = {
  demon_king:[[26,3,null]], dragon:[[7,3,null],[8,9,null]],
  shadow:[[7,10,null],[6,13,null],[22,11,'020101'],[22,12,'020101']],
  emperor:[[15,1,'fdc614'],[20,3,'deba51'],[20,5,'deba51']],
  grim:[[12,1,'020202'],[19,15,'1a1815']],
  abyss:[[19,5,'152c2e'],[20,13,'152c2e']], hawaii:[[17,10,'5e4124']],
};
// Reviewed on the actual final 64px frames in RIGHT-facing coordinates.
// Each item has the old head ROI and the exclusive neck attachment anchor.
const READY = {roi:[28,18,39,32],neck:[33,32]};
const POSES = {
  idle:[READY,
    {roi:[28,18,39,31],neck:[34,31]},
    {roi:[28,17,39,31],neck:[34,31]},
    {roi:[28,18,39,31],neck:[34,31]},
    {roi:[27,18,40,31],neck:[34,31]},READY],
  hurt:[READY,
    {roi:[25,19,37,33],neck:[31,33]},
    {roi:[29,20,41,33],neck:[35,33]},
    {roi:[31,20,42,33],neck:[37,33]},
    {roi:[29,20,42,33],neck:[36,33]},READY],
  death:[READY,
    {roi:[30,21,41,34],neck:[35,34],turn:.08},
    {roi:[34,24,46,37],neck:[40,37],turn:.18},
    {roi:[36,27,48,40],neck:[43,40],turn:.32},
    {roi:[40,32,51,44],neck:[45,43],turn:.5},
    {roi:[40,35,51,46],neck:[45,46],turn:.64,front:[[49,47,60,50]]}],
  walk:[
    {roi:[29,15,40,30],neck:[35,30]},{roi:[30,15,41,30],neck:[36,30]},
    {roi:[28,15,41,30],neck:[35,30]},{roi:[29,15,40,30],neck:[35,30]},
    {roi:[32,15,43,30],neck:[38,30]},{roi:[27,15,40,31],neck:[34,31]},
  ],
  dash:[
    {roi:[32,25,43,40],neck:[38,40]},{roi:[31,28,43,43],neck:[37,43]},
    {roi:[32,30,44,43],neck:[38,43]},{roi:[33,31,46,43],neck:[40,43]},
    {roi:[31,27,44,41],neck:[37,41]},{roi:[22,27,35,41],neck:[29,41]},
  ],
  attack:[READY,
    {roi:[22,20,34,33],neck:[28,33],front:[[7,24,22,28]]},
    {roi:[34,22,43,35],neck:[38,35],front:[[21,13,34,26]]},
    {roi:[30,20,41,32],neck:[35,32],front:[[40,29,61,34]]},
    {roi:[33,21,45,34],neck:[39,34]},READY],
  attack2:[READY,
    {roi:[28,23,40,37],neck:[34,37]},
    {roi:[27,18,38,32],neck:[32,32]},
    {roi:[28,20,39,31],neck:[33,31],front:[[38,16,50,29]]},
    {roi:[27,19,38,30],neck:[32,30],front:[[37,16,50,29]]},READY],
  heavy:[READY,
    {roi:[31,19,40,33],neck:[35,33],front:[[21,5,31,31]]},
    {roi:[34,22,43,35],neck:[38,35],front:[[21,13,34,26]]},
    {roi:[35,23,46,37],neck:[41,37]},
    {roi:[31,22,42,36],neck:[37,36]},READY],
  special:[READY,
    {roi:[24,18,36,32],neck:[30,32]},
    {roi:[31,19,42,33],neck:[37,33]},
    {roi:[33,19,45,33],neck:[39,33]},
    {roi:[27,19,39,33],neck:[33,33]},READY],
};
const METAL = new Set(['33312e','55534f','6a6762','97918a','e3e1d8','7f7d78','a6a5a2','babdbd','f8f7f7']);
const inRect=(x,y,[x0,y0,x1,y1])=>x>=x0&&x<=x1&&y>=y0&&y<=y1;
const hexAt=(d,i)=>d.subarray(i*4,i*4+3).toString('hex');
function headMask(data,pose) {
  const mask=new Uint8Array(4096),seeds=[];
  const [x0,y0,x1,y1]=pose.roi;
  for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
    const i=y*64+x;if(!data[i*4+3])continue;
    const eye=x>=pose.neck[0]&&y<pose.neck[1]-2&&data[i*4]>180&&data[i*4+1]<75;
    if(METAL.has(hexAt(data,i))||eye){mask[i]=1;seeds.push(i);}
  }
  assert(seeds.length>=16,'Head seed missing; review changed base art');
  // Include the existing black rim, never flood into body/cape outlines.
  for(const i of seeds){const x=i%64,y=i/64|0;
    for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){
      const xx=x+dx,yy=y+dy,j=yy*64+xx;
      if(inRect(xx,yy,pose.roi)&&data[j*4+3]&&hexAt(data,j)==='040302')mask[j]=1;
    }
  }
  // Fill the dark visor between rim pixels without taking the rectangular ROI.
  for(let y=y0;y<=y1;y++){
    const xs=[];for(let x=x0;x<=x1;x++)if(mask[y*64+x])xs.push(x);
    if(xs.length>1)for(let x=xs[0];x<=xs.at(-1);x++)if(data[(y*64+x)*4+3])mask[y*64+x]=1;
  }
  return mask;
}
function nearest(rgb,palette){
  let out=palette[0],distance=Infinity;
  for(const p of palette){const e=(rgb[0]-p[0])**2+(rgb[1]-p[1])**2+(rgb[2]-p[2])**2;
    if(e<distance){out=p;distance=e;}}
  return out;
}
async function main(){
  fs.mkdirSync(QA,{recursive:true});
  const rosterReport=JSON.parse(fs.readFileSync(path.join(ROSTER,'report.json')));
  const palettes={},helmets={},base={},masks={},report={actors:{},frames:[],limitations:[
    'Approved helmets keep their three-quarter view. Neck anchors follow the body; death poses tilt the helmet on the native pixel grid without blending.',
    'Raised foreground arms and weapons stay in front of wide horns/crowns.'
  ]};
  for(const skin of SKINS){
    const def=HELMETS[skin];const d=await sharp(path.join(ROSTER,'tiles',skin+'.png')).ensureAlpha().raw().toBuffer();
    const helmet=Buffer.alloc(32*32*4);
    for(const [y0,y1,x0,x1]of def.rows)for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++)d.copy(helmet,(y*32+x)*4,(y*32+x)*4,(y*32+x+1)*4);
    for(const [x,y,hex]of HELMET_EDITS[skin]||[]){
      const i=(y*32+x)*4;assert(helmet[i+3],'Reviewed helmet edge pixel disappeared');
      if(hex)Buffer.from(hex+'ff','hex').copy(helmet,i);else helmet.fill(0,i,i+4);
    }
    if(skin==='hawaii'){
      // The source shirt collar is not part of the hat/face. Do not carry it
      // onto the common body when cutting the approved helmet above its neck.
      for(let i=0;i<1024;i++)if(['128d80','33c0a3','79deac','085a53'].includes(hexAt(helmet,i)))helmet.fill(0,i*4,i*4+4);
    }
    palettes[skin]=rosterReport.actors.find(a=>a.id===skin).palette;
    assert(palettes[skin].length>=16&&palettes[skin].length<=24,'Expected approved roster palette of at most 24 colours');
    helmets[skin]=helmet;
    await sharp(helmet,{raw:{width:32,height:32,channels:4}}).png().toFile(path.join(QA,skin+'-helmet.png'));
  }
  for(const motion of CLIPS){base[motion]=[];masks[motion]=[];
    for(let f=0;f<POSES[motion].length;f++){
      const data=await sharp(path.join(BASE,motion,f+'.png')).flop().ensureAlpha().raw().toBuffer();
      assert(data.length===64*64*4,'Base frame must stay 64x64');
      base[motion].push(data);masks[motion].push(headMask(data,POSES[motion][f]));
    }
  }
  const results={valentino_1:base};
  for(const skin of SKINS){
    const palette=palettes[skin].map(h=>[...Buffer.from(h,'hex')]);
    const lookup=new Map(),frames={};let written=0,clipped=0;
    for(const motion of CLIPS){frames[motion]=[];
      for(let f=0;f<base[motion].length;f++){
        const src=base[motion][f],mask=masks[motion][f],pose=POSES[motion][f],out=Buffer.from(src),helm=helmets[skin];
        for(let i=0;i<4096;i++){
          if(mask[i]){out.fill(0,i*4,i*4+4);continue;}
          if(!out[i*4+3])continue;
          const h=hexAt(out,i);if(!lookup.has(h))lookup.set(h,nearest([...out.subarray(i*4,i*4+3)],palette));
          Buffer.from(lookup.get(h)).copy(out,i*4);
        }
        const cos=Math.cos(pose.turn||0),sin=Math.sin(pose.turn||0),neck=HELMETS[skin].neck;
        let drawn=0;
        // Inverse nearest sampling keeps a tilted helmet solid, with no soft edge.
        for(let yy=0;yy<64;yy++)for(let xx=0;xx<64;xx++){
          const dx=xx-pose.neck[0],dy=yy-pose.neck[1];
          const x=Math.round(cos*dx+sin*dy+neck[0]),y=Math.round(-sin*dx+cos*dy+neck[1]);
          if(x<0||x>=32||y<0||y>=32)continue;
          const i=(y*32+x)*4;if(!helm[i+3])continue;
          assert(xx>=1&&xx<=62&&yy>=1&&yy<=62,`${skin}/${motion}/${f}: helmet touches ${xx},${yy}`);
          const j=yy*64+xx;
          // Full source foreground pixels, not detached hand/weapon fragments.
          if(!mask[j]&&src[j*4+3]&&(pose.front||[]).some(r=>inRect(xx,yy,r)))continue;
          helm.copy(out,j*4,i,i+4);drawn++;
        }
        const allowed=new Set(palettes[skin]);
        for(let i=0;i<4096;i++){assert(out[i*4+3]===0||out[i*4+3]===255,'Soft alpha introduced');if(out[i*4+3])assert(allowed.has(hexAt(out,i)),'Unapproved colour');}
        assert(drawn>50,'Helmet missing or fully occluded');
        frames[motion].push(out);
        const qaDir=path.join(QA,'frames',skin,motion);fs.mkdirSync(qaDir,{recursive:true});
        await sharp(out,{raw:{width:64,height:64,channels:4}}).png().toFile(path.join(qaDir,f+'.png'));
        if(process.argv.includes('--write-assets')){
          const dst=path.join(ROOT,'assets/anim/pixel_pilot',skin,motion);fs.mkdirSync(dst,{recursive:true});
          await sharp(out,{raw:{width:64,height:64,channels:4}}).flop().png().toFile(path.join(dst,f+'.png'));written++;
        }
        report.frames.push({skin,motion,frame:f,neck:pose.neck,oldHeadPixels:mask.reduce((a,b)=>a+b,0),helmetPixels:drawn});
      }
    }
    assert(clipped===0,'Helmet touched canvas border; review anchors');
    for(const motion of ['attack','attack2','heavy']){
      assert(frames[motion][0].equals(frames.idle[0])&&frames[motion][5].equals(frames.idle[0]),'Shared ready pose lost at clip boundary');
    }
    results[skin]=frames;report.actors[skin]={frames:54,written,clipped,palette:palettes[skin]};
  }
  for(const motion of ['walk','attack','heavy','hurt','death']){
    const tiles=[];const ids=['valentino_1',...SKINS];
    for(let r=0;r<ids.length;r++)for(let f=0;f<6;f++){
      const png=await sharp(results[ids[r]][motion][f],{raw:{width:64,height:64,channels:4}}).resize(192,192,{kernel:'nearest'}).png().toBuffer();
      tiles.push({input:png,left:f*192,top:r*216+24});
      if(!f)tiles.push({input:Buffer.from(`<svg width="1152" height="24"><text x="8" y="17" fill="white" font-family="Arial" font-size="16">${ids[r]} / ${motion} / RIGHT 3x</text></svg>`),left:0,top:r*216});
    }
    await sharp({create:{width:1152,height:216*ids.length,channels:4,background:'#222633'}}).composite(tiles).png().toFile(path.join(QA,'nine-skins-'+motion+'.png'));
  }
  fs.writeFileSync(path.join(QA,'palettes.json'),JSON.stringify(palettes,null,2)+'\n');
  fs.writeFileSync(path.join(QA,'report.json'),JSON.stringify(report,null,2)+'\n');
  console.log(JSON.stringify({skins:SKINS.length,frames:54*SKINS.length,written:process.argv.includes('--write-assets'),clipped:0,qa:QA}));
}
main().catch(e=>{console.error(e);process.exitCode=1;});
