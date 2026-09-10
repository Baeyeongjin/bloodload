const fs=require('fs'),path=require('path'),sharp=require('sharp'),assert=require('assert');
const ROOT=path.resolve(__dirname,'..'),ART=path.join(ROOT,'assets/anim/pixel_pilot');
const skins=[...fs.readFileSync(path.join(ROOT,'SkinDefs.gd'),'utf8').matchAll(/"id":\s*"([a-z_0-9]+)"/g)].map(m=>m[1]);
const tiers=fs.readFileSync(path.join(ROOT,'FoeTiers.gd'),'utf8').split('const TIERS := {')[1].split('\n}')[0];
const monsters=[...tiers.matchAll(/"([a-z_0-9]+)":\s*\{/g)].map(m=>m[1]);
const actors=[...skins,...monsters,...Array.from({length:5},(_,i)=>'boss_'+(i+1))];

(async()=>{
  assert(skins.length===9&&monsters.length===43&&new Set(actors).size===57,'Roster IDs changed; review production scope');
  const report={actors:{},missing:[],originalMissing:[],frames:0,expectedFrames:1638};
  for(const actor of actors){
    const hero=skins.includes(actor),motions=hero?['idle','walk','dash','attack','attack2','heavy','special','hurt','death']:['walk','dash','attack','special'];
    const palette=new Set(),row={frames:0,colors:0};
    for(const motion of motions)for(let f=0;f<6;f++){
      const file=path.join(ART,actor,motion,f+'.png');
      if(!fs.existsSync(file)){report.missing.push(actor+'/'+motion+'/'+f);continue;}
      const {data,info}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      assert(info.width===64&&info.height===64,file+': not native64');
      let ink=0;
      for(let i=0;i<data.length;i+=4){
        assert(data[i+3]===0||data[i+3]===255,file+': soft alpha');
        if(!data[i+3]){assert(data[i]===0&&data[i+1]===0&&data[i+2]===0,file+': hidden matte RGB');continue;}
        ink++;palette.add(data.subarray(i,i+3).toString('hex'));
      }
      assert(ink>10,file+': empty pose');row.frames++;report.frames++;
    }
    row.colors=palette.size;assert(row.colors<=24,actor+': exceeded shared 24-colour palette');
    row.complete=row.frames===motions.length*6;report.actors[actor]=row;
    if(row.complete&&process.argv.includes('--write-portraits')){
      const file=path.join(ART,actor,hero?'idle':'walk','0.png');
      const {data}=await sharp(file).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      let x0=64,x1=0,y0=64,y1=0;
      for(let y=0;y<64;y++)for(let x=0;x<64;x++)if(data[(y*64+x)*4+3]){x0=Math.min(x0,x);x1=Math.max(x1,x);y0=Math.min(y0,y);y1=Math.max(y1,y);}
      await sharp(file).extract({left:x0,top:y0,width:x1-x0+1,height:y1-y0+1})
        .extend({top:2,bottom:2,left:2,right:2,background:'#00000000'}).png().toFile(path.join(ART,actor,'portrait.png'));
    }
    if(!hero)for(const motion of ['walk','attack','special'])if(!fs.existsSync(path.join(ROOT,'assets/anim',actor+'_'+motion,'0.png')))report.originalMissing.push(actor+'/'+motion);
  }
  const out=path.join(ROOT,'build/qa/pixel-roster');fs.mkdirSync(out,{recursive:true});
  fs.writeFileSync(path.join(out,'report.json'),JSON.stringify(report,null,2));
  console.log(JSON.stringify({complete:Object.values(report.actors).filter(a=>a.complete).length,total:57,frames:report.frames,missing:report.missing.length,originalMissing:report.originalMissing}));
  if(report.missing.length)process.exitCode=2;
})().catch(e=>{console.error(e);process.exitCode=1});
