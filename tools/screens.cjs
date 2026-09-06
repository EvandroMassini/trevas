// Convert real Z80 test screenshots to PNG, using only Node's zlib.
const fs=require('fs'),path=require('path'),zlib=require('zlib');
const root=path.resolve(__dirname,'../build');
function crc32(b){let c=0xffffffff;for(let v of b){c^=v;for(let k=0;k<8;k++)c=(c>>>1)^(c&1?0xedb88320:0)}return(c^0xffffffff)>>>0}
function chunk(type,b){const t=Buffer.from(type),n=Buffer.alloc(4),c=Buffer.alloc(4);n.writeUInt32BE(b.length);c.writeUInt32BE(crc32(Buffer.concat([t,b])));return Buffer.concat([n,t,b,c])}
function png(w,h,data){const head=Buffer.alloc(13);head.writeUInt32BE(w);head.writeUInt32BE(h,4);head[8]=8;head[9]=2;return Buffer.concat([Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',head),chunk('IDAT',zlib.deflateSync(data)),chunk('IEND',Buffer.alloc(0))])}
for(let name of ['titulo','labirinto','guardiao','mapa']){let scr=fs.readFileSync(path.join(root,name+'.scr')),w=768,h=576,data=Buffer.alloc(h*(w*3+1));for(let y=0;y<h;y++)for(let x=0;x<w;x++){let X=Math.floor(x/3),Y=Math.floor(y/3),b=scr[((Y&192)<<5)|((Y&7)<<8)|((Y&56)<<2)|(X>>3)],a=scr[6144+(Y>>3)*32+(X>>3)],c=b&(128>>(X&7))?a&7:(a>>3)&7,v=a&64?255:205,o=y*(w*3+1)+1+x*3;data[o]=c&2?v:0;data[o+1]=c&4?v:0;data[o+2]=c&1?v:0;}fs.writeFileSync(path.join(root,name+'.png'),png(w,h,data));}
