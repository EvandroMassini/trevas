const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
require('./assets.cjs')(root);
const Module=require('pasmo/dist/pasmo.js');
const asmInput=fs.readFileSync(path.join(root,'trevas.asm'),'utf8');
const out=[];
new Promise((resolve,reject)=>Module({arguments:['--tapbas','input.asm','output.tap'],asmInput,files:{'assets.inc':fs.readFileSync(path.join(root,'assets.inc'),'utf8')},out,resolve,reject,print:s=>out.push(s),printErr:s=>out.push(s)})).then(result=>{
 if(!ArrayBuffer.isView(result)&&!Array.isArray(result)){console.log(result);throw Error('Unexpected assembler output')}
 const tap=Buffer.from(result);fs.mkdirSync(path.join(root,'build'),{recursive:true});fs.writeFileSync(path.join(root,'build/trevas.tap'),tap);
 const blocks=[];for(let p=0;p<tap.length;){const len=tap.readUInt16LE(p);blocks.push(tap.subarray(p+2,p+2+len));p+=len+2;}
 const bin=blocks.at(-1).subarray(1,-1);if(32768+bin.length>57344)throw Error('Code overlaps video buffer');
 fs.writeFileSync(path.join(root,'build/trevas.bin'),bin);
 const names='start main player monster direction seals charges stun game_over render bfs chase forward backward turn_left turn_right repel maze_0 maze_1 maze_2 spawn_table clock irq new_game ending visible_monster map_mode enemy_timer dirty last_loop wait_space_loop'.split(' ');
 const pos=bin.lastIndexOf('TREVASDBG');if(pos<0)throw Error('No debug footer');const symbols={};names.forEach((n,i)=>symbols[n]=bin.readUInt16LE(pos+9+i*2));fs.writeFileSync(path.join(root,'build/symbols.json'),JSON.stringify(symbols,null,2));
 // SNA starts at entry with a minimal self-contained RAM image (no ROM calls).
 const ram=Buffer.alloc(49152);bin.copy(ram,16384);ram.writeUInt16LE(32768,64766-16384);
 const header=Buffer.alloc(27);header[19]=0;header.writeUInt16LE(64766,23);header[25]=1;
 fs.writeFileSync(path.join(root,'build/trevas.sna'),Buffer.concat([header,ram]));
 console.log(`Built ${bin.length} bytes at 32768; end ${32768+bin.length}. TAP ${tap.length} bytes.`);
}).catch(e=>{console.error(out,e);process.exitCode=1});
