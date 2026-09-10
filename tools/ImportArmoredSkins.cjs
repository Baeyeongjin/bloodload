// Reviewed whole-body skin boards -> QA only. No production export here.
const fs=require('fs'),path=require('path'),sharp=require('sharp'),assert=require('assert');
const {extractActor}=require('./ImportMonsterExpansion.cjs');
const ROOT=path.resolve(__dirname,'..');
const BOARDS={core:['walk','dash','attack','attack2','heavy','special'],secondary:['idle','hurt','death'],walk12:['walk_a','walk_b']};
const CLIPS=['idle','walk','dash','attack','attack2','heavy','special','hurt','death'];

async function extractSkin(cfg){
  const qa=path.resolve(ROOT,cfg.outputDir||`build/qa/armor-redesign/${cfg.actor}`),native=path.join(qa,'native');
  const reports={};
  for(const [name,rows] of Object.entries(BOARDS)){
    assert(cfg[name],`${cfg.actor}: missing ${name} board config`);
    const b=cfg[name];
    reports[name]=await extractActor({...cfg,...b,actor:cfg.actor,source:path.resolve(ROOT,b.source),rows,
      outputDir:path.join(qa,'extract',name),writeAssets:false});
  }
  const report={actor:cfg.actor,frames:60,status:'QA only; native visual review required',boards:reports,clips:{}};
  const allColors=new Set(),preview=[],thumb=128,line=152;
  let row=0;
  for(const motion of CLIPS){
    const count=motion==='walk'?12:6,dir=path.join(native,motion),tiles=[];
    fs.mkdirSync(dir,{recursive:true});
    for(let f=0;f<count;f++){
      const board=motion==='walk'?'walk12':BOARDS.core.includes(motion)?'core':'secondary';
      const sourceMotion=motion==='walk'?(f<6?'walk_a':'walk_b'):motion;
      const src=path.join(qa,'extract',board,sourceMotion,(f%6)+'.png');
      let png=fs.readFileSync(src);
      if(cfg.flip)png=await sharp(png).flop().png().toBuffer();
      const {data,info}=await sharp(png).ensureAlpha().raw().toBuffer({resolveWithObject:true});
      assert(info.width===64&&info.height===64);
      let opaque=0;
      for(let i=0;i<data.length;i+=4){
        assert(data[i+3]===0||data[i+3]===255,'Soft alpha');
        if(data[i+3]){allColors.add(data.subarray(i,i+3).toString('hex'));opaque++;}
        else assert(data[i]===0&&data[i+1]===0&&data[i+2]===0,'Nonzero transparent RGB');
      }
      assert(opaque>=12,'Empty motion frame');
      fs.writeFileSync(path.join(dir,f+'.png'),png);tiles.push(png);
    }
    report.clips[motion]={frames:count};
    for(let start=0;start<count;start+=6){
      preview.push({input:Buffer.from(`<svg width="768" height="24"><text x="8" y="17" fill="#eee5d7" font-family="Arial" font-size="13">${cfg.actor} / ${motion} / ${start}–${start+5} / LEFT</text></svg>`),left:0,top:row*line});
      for(let i=0;i<6;i++)preview.push({input:await sharp(tiles[start+i]).resize(thumb,thumb,{kernel:'nearest'}).png().toBuffer(),left:i*thumb,top:row*line+24});
      row++;
    }
    const raw=await Promise.all(tiles.map(p=>sharp(p).resize(256,256,{kernel:'nearest'}).flatten({background:'#242834'}).removeAlpha().raw().toBuffer()));
    await sharp(Buffer.concat(raw),{raw:{width:256,height:256*count,channels:3,pageHeight:256}})
      .gif({loop:0,delay:motion==='walk'?[30,30,40,30,30,40,30,30,40,30,30,40]:[90,70,50,65,70,100],colours:32,dither:0})
      .toFile(path.join(qa,motion+'.gif'));
  }
  assert(allColors.size<=24,`${cfg.actor}: ${allColors.size} total colours, expected actor-shared <=24`);
  report.colors=allColors.size;
  await sharp({create:{width:768,height:row*line,channels:4,background:'#242834'}}).composite(preview).png().toFile(path.join(qa,'preview.png'));
  fs.writeFileSync(path.join(qa,'report.json'),JSON.stringify(report,null,2));
  return report;
}

module.exports={extractSkin};
if(require.main===module)(async()=>{
  for(const arg of process.argv.slice(2)){
    const file=arg.endsWith('.json')?arg:`build/qa/armor-redesign/${arg}/config.json`;
    const cfg=JSON.parse(fs.readFileSync(path.resolve(ROOT,file),'utf8'));
    const report=await extractSkin(cfg);console.log(`${cfg.actor}: ${report.frames} QA frames, ${report.colors} colours`);
  }
})().catch(e=>{console.error(e);process.exitCode=1});
