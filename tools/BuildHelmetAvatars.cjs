// Native helmet-only HUD portraits. Reuse reviewed pixels; no new image generation.
const fs=require('fs'),path=require('path'),sharp=require('sharp'),assert=require('assert');
const ROOT=path.resolve(__dirname,'..'),QA=path.join(ROOT,'build/qa/helmet-skins');
const SKINS=['valentino_1','demon_king','dragon','shadow','emperor','grim','abyss','hawaii','pink'];
(async()=>{
  const tiles=[];
  for(const skin of SKINS){
    let input;
    if(skin==='valentino_1'){
      const source=await sharp(path.join(ROOT,'assets/anim/pixel_pilot/valentino_1/idle/0.png')).flop().ensureAlpha().raw().toBuffer();
      const helmet=Buffer.alloc(64*64*4);
      // Follow the actual curved rim, leaving the shoulder/cape below it out.
      const rows=[[31,34],[30,35],[29,37],[29,37],[29,37],[29,38],[29,38],[29,38],[29,38],[31,38],[32,38],[32,37],[33,36]];
      for(let r=0;r<rows.length;r++)for(let x=rows[r][0];x<=rows[r][1];x++){const i=((18+r)*64+x)*4;source.copy(helmet,i,i,i+4);}
      input=await sharp(helmet,{raw:{width:64,height:64,channels:4}}).png().toBuffer();
    }else input=fs.readFileSync(path.join(QA,skin+'-helmet.png'));
    const {data,info}=await sharp(input).ensureAlpha().raw().toBuffer({resolveWithObject:true});
    let x0=info.width,y0=info.height,x1=0,y1=0;
    for(let y=0;y<info.height;y++)for(let x=0;x<info.width;x++)if(data[(y*info.width+x)*4+3]){x0=Math.min(x0,x);y0=Math.min(y0,y);x1=Math.max(x1,x);y1=Math.max(y1,y);}
    assert(x1>=x0&&y1>=y0);
    const png=await sharp(input).extract({left:x0,top:y0,width:x1-x0+1,height:y1-y0+1})
      .extend({top:1,bottom:1,left:1,right:1,background:'#00000000'}).png().toBuffer();
    fs.writeFileSync(path.join(ROOT,'assets/anim/pixel_pilot',skin,'avatar.png'),png);
    tiles.push({input:await sharp(png).resize(96,96,{fit:'contain',kernel:'nearest',background:'#242834'}).png().toBuffer(),left:tiles.length*96,top:0});
  }
  await sharp({create:{width:SKINS.length*96,height:96,channels:4,background:'#242834'}}).composite(tiles).png().toFile(path.join(QA,'nine-avatars.png'));
  console.log('9 helmet-only native avatars exported');
})().catch(e=>{console.error(e);process.exitCode=1});
