// Run inside LibreSprite's JavaScript engine on a transparent 128x64 RGBA canvas.
// Every mark is written with Image.putPixel. No image-generation model, scaling,
// antialiasing, or screenshots are used to create these frames.
// The source anchor is (64,48), forward is +X, and playback is 12 frames at 30fps.
var BOSS_VFX = [
  ['rock','rock','#f6d19b','#b98047','#50392e'],
  ['wraith_knight','soul','#ffe7a5','#c7a455','#635030'],
  ['gargoyle','pillar','#fff0ab','#ef7c36','#852332'],
  ['frost_golem','crack','#dcffff','#78d6ee','#2c5f8b'],
  ['eye_mass','lash','#f0ceff','#a966e3','#482567'],
  ['dark_knight','arc','#fff4d7','#d1c5a0','#6d6453'],
  ['sanctum_guardian','crystal','#dffaff','#79bbf4','#365da1'],
  ['blood_queen','spray','#ffd3db','#e74575','#7c2547'],
  ['bone_choir','sonic','#ffe6f7','#c28eb6','#685075'],
  ['butcher','cross','#ffc6ba','#d7485f','#6c2036'],
  ['plague_hag','boil','#e9ffb0','#8acb47','#38612f'],
  ['ruin_warden','debris','#e4f391','#9fbc43','#53682c'],
  ['crystal_golem','crystal','#edffff','#69e1ec','#255c75'],
  ['vine_colossus','lash','#eaf5d0','#98b19b','#40594d'],
  ['bloodmoon_avatar','pillar','#ffe3d7','#ef8295','#89243c'],
  ['drowned_king','crack','#fff0af','#cfb66a','#667c42'],
  ['usurper','arc','#fff2bf','#e4bd59','#6d3242']
];

function paintBossFrame(image, theme, frame, colors) {
  var alpha = [255,255,255,255,255,255,235,210,170,115,60,0][frame];
  function ink(hex, a) {
    return app.pixelColor.rgba(parseInt(hex.substr(1,2),16), parseInt(hex.substr(3,2),16),
      parseInt(hex.substr(5,2),16), Math.round(a === undefined ? alpha : a));
  }
  var light=ink(colors[0]), mid=ink(colors[1]), dark=ink(colors[2]), white=ink('#fffbe5');
  image.clear(0);
  if (!alpha) return;
  function dot(x,y,c) {
    x=Math.round(x)+64; y=Math.round(y)+48;
    if(x>=0 && x<128 && y>=0 && y<64) image.putPixel(x,y,c);
  }
  function line(a,b,c,w) {
    var x=Math.round(a[0]), y=Math.round(a[1]), ex=Math.round(b[0]), ey=Math.round(b[1]);
    var dx=Math.abs(ex-x), sx=x<ex?1:-1, dy=-Math.abs(ey-y), sy=y<ey?1:-1, err=dx+dy;
    var size=w||1, low=-Math.floor(size/2), high=low+size;
    while(true) {
      for(var yy=low;yy<high;yy++) for(var xx=low;xx<high;xx++) dot(x+xx,y+yy,c);
      if(x===ex&&y===ey)break;
      var e=2*err; if(e>=dy){err+=dy;x+=sx;} if(e<=dx){err+=dx;y+=sy;}
    }
  }
  function path(p,c,w) {for(var i=1;i<p.length;i++)line(p[i-1],p[i],c,w);}
  function polygon(p,c) {
    var lo=50,hi=-50;
    for(var i=0;i<p.length;i++){lo=Math.min(lo,p[i][1]);hi=Math.max(hi,p[i][1]);}
    for(var y=Math.floor(lo);y<=Math.ceil(hi);y++) {
      var xs=[];
      for(var i=0,j=p.length-1;i<p.length;j=i++) {
        var a=p[j],b=p[i],v=y+0.5;
        if((a[1]<=v&&b[1]>v)||(b[1]<=v&&a[1]>v)) xs.push(a[0]+(v-a[1])/(b[1]-a[1])*(b[0]-a[0]));
      }
      xs.sort(function(a,b){return a-b;});
      for(var i=0;i+1<xs.length;i+=2)for(var x=Math.ceil(xs[i]);x<=Math.floor(xs[i+1]);x++)dot(x,y,c);
    }
  }
  function star(x,y,n,c) {
    polygon([[x-n,y],[x-1,y-1],[x,y-n],[x+1,y-1],[x+n,y],[x+1,y+1],[x,y+n],[x-1,y+1]],c);
  }
  function curve(p,t) {
    var u=1-t;
    return [u*u*u*p[0][0]+3*u*u*t*p[1][0]+3*u*t*t*p[2][0]+t*t*t*p[3][0],
      u*u*u*p[0][1]+3*u*u*t*p[1][1]+3*u*t*t*p[2][1]+t*t*t*p[3][1]];
  }
  var heads=[0.16,0.42,0.70,0.94,1,1,1,1,1,1,1,1];
  var tails=[0,0,0,0.08,0.22,0.39,0.55,0.70,0.82,0.91,0.98,1];
  function blade(p,w,delay) {
    var f=frame-delay;if(f<0)return;
    var head=heads[f],tail=tails[f],a=[],b=[],core=[];
    for(var i=0;i<=28;i++){
      var q=i/28,t=tail+(head-tail)*q,pt=curve(p,t);
      var prev=curve(p,Math.max(0,t-0.005)),next=curve(p,Math.min(1,t+0.005));
      var vx=next[0]-prev[0],vy=next[1]-prev[1],length=Math.sqrt(vx*vx+vy*vy)||1;
      var thickness=w*Math.pow(Math.sin(q*Math.PI),0.65)*(0.7+q*0.3);
      a.push([pt[0]-vy/length*thickness,pt[1]+vx/length*thickness]);
      b.push([pt[0]+vy/length*thickness*0.35,pt[1]-vx/length*thickness*0.35]);
      core.push(pt);
    }
    polygon(a.concat(b.slice().reverse()),dark);
    path(core,mid,3);
    path(core.slice(8),light,2);
    path(core.slice(21),white,1);
    if(frame<4){var tip=curve(p,head);star(tip[0],tip[1],2,white);}
  }
  function chip(x,y,s) {
    polygon([[x-s,y],[x-s+1,y-s],[x+1,y-s-1],[x+s,y-1],[x+s-1,y+s],[x-1,y+s]],dark);
    polygon([[x-s+1,y-1],[x-s+2,y-s+1],[x+1,y-s],[x+s-1,y-1],[x,y]],mid);
    line([x-s+2,y-s+1],[x+1,y-s],light,1);
  }
  var rise=[0.18,0.45,0.78,1,1,0.94,0.76,0.54,0.35,0.18,0.06,0][frame];
  if(theme==='soul') {
    blade([[0,-9],[10,-35],[33,-32],[54,-4]],4.5,0);
    blade([[-1,-4],[11,-25],[31,-24],[45,-1]],2.2,1);
  } else if(theme==='arc') {
    blade([[-3,-27],[17,-35],[42,-21],[55,-2]],5,0);
  } else if(theme==='cross') {
    blade([[4,-31],[18,-25],[38,-10],[50,-2]],4,0);
    blade([[7,-2],[21,-9],[32,-25],[45,-31]],3.7,1);
  } else if(theme==='lash') {
    blade([[0,-8],[11,-38],[26,7],[54,-14]],3,0);
    if(frame>=3&&frame<8){var tip=curve([[0,-8],[11,-38],[26,7],[54,-14]],heads[frame]);star(tip[0],tip[1],3,light);}
  } else if(theme==='crack'||theme==='crystal') {
    var spread=theme==='crack'?[-28,0,28]:[-34,-17,0,18,35];
    if(theme==='crack') {
      path([[-47,1],[-35,-1],[-28,1],[-18,-3],[-8,0],[0,-2],[10,0],[19,-2],[29,0],[39,-2],[47,1]],dark,3);
      path([[-47,0],[-35,-2],[-28,0],[-18,-4],[-8,-1],[0,-3],[10,-1],[19,-3],[29,-1],[39,-3],[47,0]],light,1);
    }
    for(var i=0;i<spread.length;i++) {
      var x=spread[i],h=(theme==='crack'?[13,19,15][i]:[11,20,26,18,13][i])*rise;
      var w=theme==='crack'?5:4,lean=i%2?2:-2;
      polygon([[x-w,0],[x-w+1,-h*0.45],[x+lean,-h],[x+w,-h*0.25],[x+w-1,0]],dark);
      polygon([[x-w+1,-1],[x+lean,-h+1],[x+1,-h*0.3],[x+1,-1]],mid);
      line([x+lean,-h+1],[x+1,-2],light,1);
      if(frame<5)line([x-7,1],[x+7,1],light,1);
    }
  } else if(theme==='pillar') {
    for(var i=0;i<2;i++){
      var x=i?10:-10,h=(i?26:20)*rise,w=5+Math.round(2*rise);
      var flame=[[x-w,0],[x-w-2,-h*0.32],[x-w+2,-h*0.29],[x-w+1,-h*0.69],
        [x-1,-h*0.56],[x+1,-h],[x+4,-h*0.66],[x+3,-h*0.49],[x+w+2,-h*0.65],
        [x+w,-h*0.17],[x+w+2,0]];
      polygon(flame,dark);
      polygon([[x-w+2,-1],[x-3,-h*0.53],[x,-h*0.42],[x+1,-h*0.86],[x+3,-h*0.46],[x+w-1,-1]],mid);
      polygon([[x-2,-1],[x-2,-h*0.28],[x,-h*0.55],[x+3,-1]],light);
    }
    if(frame<5)star(0,-2,6-frame,white);
  } else if(theme==='sonic') {
    for(var i=0;i<2;i++) {
      var f=frame-i*2;if(f<0||f>8)continue;
      var x=8+f*5,h=7+f;
      var arc=[[x-5,-14-h],[x+1,-11-h],[x+5,-14-h*0.45],[x+7,-14],
        [x+5,-14+h*0.45],[x+1,-17+h],[x-5,-14+h]];
      path(arc,dark,4);path(arc,mid,2);path(arc.slice(1,6),light,1);
      line([x+8,-17],[x+8,-11],white,1);
    }
  } else if(theme==='spray') {
    for(var i=0;i<3;i++) {
      var f=Math.max(0,frame-i),t=Math.min(1,f/7),x=8+t*(30+i*7),y=-4-Math.sin(t*Math.PI)*(10+i*5);
      if(frame<7) {
        var length=(7-frame)*0.6+2;
        polygon([[x-length*2,y+2],[x-2,y-3],[x+2,y-2],[x+3,y],[x+1,y+3]],dark);
        line([x-length,y+1],[x,y-1],mid,3);dot(x+1,y-1,light);
      } else {dot(x,y,mid);dot(x-1,y-1,light);}
    }
  } else if(theme==='boil') {
    for(var i=0;i<3;i++) {
      var f=Math.max(0,frame-i),x=(i-1)*19,y=-2-Math.sin(Math.min(1,f/10)*Math.PI)*10;
      var r=[2,3,5,6,6,5,4,3,2,1,0,0][f];
      if(f<7) {
        var ring=[[x-r+1,y-3],[x-2,y-r],[x+2,y-r],[x+r,y-2],[x+r,y+1],
          [x+2,y+r-2],[x-2,y+r-2],[x-r,y+1],[x-r,y-2],[x-r+1,y-3]];
        path(ring,dark,3);path(ring,mid,1);path(ring.slice(0,4),light,1);
      } else {star(x-r-3,y-3,r,mid);dot(x+r+3,y+1,light);}
    }
  } else {
    for(var i=0;i<3;i++) {
      var t=frame/10,x=(i-1)*(8+t*31),y=-Math.sin(Math.min(1,t)*Math.PI)*(theme==='debris'?20-i*3:9+i*2);
      chip(x,y,theme==='debris'?3:4);
      if(frame>2&&frame<9){dot(x+6,y+3,mid);dot(x-4,y-4,light);}
    }
  }
  // The contact star is separate from the travelling silhouette and is gone in 2 frames.
  if(frame<2 && ['soul','arc','cross','lash','spray'].indexOf(theme)>=0)star(7,-15,3-frame,white);
}

// The caller opens a transparent seed PNG; saveAs writes each native pixel image.
// Explicit document handles also work without a GUI editor in batch mode.
var document=app.open('build/qa/libresprite-vfx-seed.png');
var sprite=document.sprite;
var canvas=sprite.layer(0).cel(0).image;
if(!canvas || canvas.width!==128 || canvas.height!==64)throw new Error('Open a 128x64 RGBA seed canvas first');
for(var k=0;k<BOSS_VFX.length;k++) {
  var spec=BOSS_VFX[k];
  for(var f=0;f<12;f++) {
    paintBossFrame(canvas,spec[1],f,spec.slice(2));
    sprite.commit();
    sprite.saveAs('assets/anim/boss_vfx/'+spec[0]+'/'+f+'.png',true);
  }
  console.log('Boss VFX pixels saved: '+spec[0]);
}
