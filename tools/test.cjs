const fs=require('fs'),path=require('path'),assert=require('assert');
(async()=>{
const {Z80}=await import(require('url').pathToFileURL(require.resolve('z80-emulator')).href);
const root=path.resolve(__dirname,'..'),bin=fs.readFileSync(path.join(root,'build/trevas.bin'));
const S=JSON.parse(fs.readFileSync(path.join(root,'build/symbols.json')));
const mem=new Uint8Array(65536);mem.set(bin,32768);
const hz=process.env.TEST_HZ==='60'?60:50,period=hz===60?59659:69888;
let held=0,ports=0,writes=0,nextIRQ=period,maxSP=65535,audioEvents=null;
const keyports={1:[0xfb,0],2:[0xfd,0],3:[0xdf,1],4:[0xdf,0],5:[0x7f,0],6:[0x7f,2],7:[0xbf,4]};
const hal={tStateCount:0,readMemory:a=>mem[a],writeMemory(a,v){assert(a>=16384,'write into ROM '+a);mem[a]=v;writes++;},contendMemory(){},contendPort(){},readPort(a){let v=255;if(held){const [row,bit]=keyports[held];if(((a>>8)|row)===row)v&=~(1<<bit);}return v},writePort(a,v){if((a&255)===254){ports++;if(audioEvents)audioEvents.push([hal.tStateCount,v&16]);}}};
const cpu=new Z80(hal);cpu.regs.pc=S.start;
function step(){cpu.step();maxSP=Math.min(maxSP,cpu.regs.sp);if(hal.tStateCount>=nextIRQ){nextIRQ+=period;cpu.maskableInterrupt();}}
function until(predicate,limit=10000000){let n=0;while(!predicate()){step();if(++n>limit)throw Error('Timeout pc='+cpu.regs.pc.toString(16));}}
function frames(n){const target=hal.tStateCount+n*period;while(hal.tStateCount<target)step();}
function call(name){const pc=cpu.regs.pc,sp=cpu.regs.sp,halted=cpu.regs.halted;cpu.regs.halted=0;cpu.regs.sp=64700;mem[64700]=0;mem[64701]=1;cpu.regs.pc=S[name];const t=hal.tStateCount;until(()=>cpu.regs.pc===256);const dt=hal.tStateCount-t;cpu.regs.pc=pc;cpu.regs.sp=sp;cpu.regs.halted=halted;return dt;}
function dump(name){fs.writeFileSync(path.join(root,'build',name+'.scr'),Buffer.from(mem.subarray(16384,23296)));}
function refDist(map,p){let ds=new Uint8Array(256).fill(255),q=[p];ds[p]=0;for(let c of q)for(let d of [-16,1,16,-1])if(map[(c+d)&255]!==1&&ds[(c+d)&255]===255){ds[(c+d)&255]=ds[c]+1;q.push((c+d)&255)}return ds;}
until(()=>cpu.regs.pc===S.wait_space_loop);dump('titulo');held=5;frames(3);held=0;until(()=>cpu.regs.pc===S.main);dump('labirinto');
assert.equal(mem[S.player],17);assert.equal(cpu.regs.im,2);assert(cpu.regs.iff1);assert.equal(mem[S.charges],2);
const report={interruptHz:hz,binaryBytes:bin.length,tests:[],renderCycles:[]};
function ok(s){report.tests.push(s);console.log('PASS',s)}
ok('Boot from entry, own IM2 interrupts, keyboard SPACE starts game');
// TAP block boundaries, XOR checksums and code identity.
const tap=fs.readFileSync(path.join(root,'build/trevas.tap'));let blocks=[];for(let p=0;p<tap.length;){let n=tap.readUInt16LE(p),b=tap.subarray(p+2,p+2+n);assert.equal(b.length,n);assert.equal(b.reduce((a,b)=>a^b,0),0);blocks.push(b);p+=n+2;}assert.equal(blocks.length,4);assert.deepEqual(blocks[3].subarray(1,-1),bin);ok('TAP BASIC loader and binary blocks: lengths and checksums');
const sna=fs.readFileSync(path.join(root,'build/trevas.sna'));assert.equal(sna.length,49179);const sp=sna.readUInt16LE(23);assert.equal(sna.readUInt16LE(27+sp-16384),S.start);assert.deepEqual(sna.subarray(27+16384,27+16384+bin.length),bin);ok('SNA 48K size, stack entry point and embedded binary');
for(let maze=0;maze<3;maze++){
 mem.set(bin.subarray(S['maze_'+maze]-32768,S['maze_'+maze]-32768+256),62464);
 const map=mem.slice(62464,62720),ds=refDist(map,17);
 assert.equal([...map].filter(v=>v===2).length,3);assert.equal([...map].filter(v=>v===3).length,1);
 for(let p=0;p<256;p++){if(!(p&15)||(p&15)===15||p<16||p>=240)assert.equal(map[p],1);if(map[p]!==1)assert.notEqual(ds[p],255);}
 mem[S.player]=17;call('bfs');assert.deepEqual(mem.slice(61952,62208),ds);
 mem[S.monster]=mem[S.spawn_table+maze];const old=ds[mem[S.monster]];call('chase');assert.equal(ds[mem[S.monster]],old-1);
 mem[S.game_over]=0;mem[S.player]=17;mem[S.direction]=0;call('forward');assert.equal(mem[S.player],17);call('backward');assert([17,33].includes(mem[S.player]));
 let worst=0;for(let p=0;p<256;p++)if(map[p]!==1){mem[S.player]=p;for(let d=0;d<4;d++){mem[S.direction]=d;worst=Math.max(worst,call('render'));}}
 report.renderCycles.push(worst);
 // Play a route collecting all seals, then exit, via actual movement routines.
 mem.set(map,62464);mem[S.monster]=0;mem[S.game_over]=0;mem[S.seals]=0;
 const exit=map.indexOf(3),v=[-16,1,16,-1].find(v=>map[exit-v]!==1);mem[S.player]=exit-v;mem[S.direction]=[-16,1,16,-1].indexOf(v);call('forward');assert.equal(mem[S.player],exit);assert.equal(mem[S.game_over],0);
 mem[S.player]=17;
 const goals=[...map.keys()].filter(p=>map[p]===2).concat([...map.keys()].filter(p=>map[p]===3));
 for(let goal of goals){let distances=refDist(map,goal);while(mem[S.player]!==goal){let p=mem[S.player],d=[-16,1,16,-1].findIndex(v=>distances[(p+v)&255]<distances[p]);assert(d>=0);mem[S.direction]=d;call('forward');} }
 assert.equal(mem[S.seals],3);assert.equal(mem[S.game_over],2);
 ok('Maze '+(maze+1)+': connected objectives, BFS, pursuit, walls, 4 views per cell, real movement victory');
}
mem[S.game_over]=0;mem[S.charges]=2;call('repel');assert.equal(mem[S.charges],1);assert.equal(mem[S.stun],110);call('repel');call('repel');assert.equal(mem[S.charges],0);ok('Repel has exactly two charges');
// Capture a staged, genuinely Z80-rendered close encounter.
mem.set(bin.subarray(S.maze_0-32768,S.maze_0-32768+256),62464);mem[S.seals]=0;mem[S.charges]=2;mem[S.stun]=0;mem[S.game_over]=0;
let encounter=false;for(let p=17;p<239&&!encounter;p++)if(mem[62464+p]!==1)for(let d=0;d<4;d++){let q=p+[-16,1,16,-1][d];if(mem[62464+q]!==1){mem[S.player]=p;mem[S.monster]=q;mem[S.direction]=d;call('bfs');call('render');dump('guardiao');encounter=true;break;}}
mem[S.map_mode]=1;call('render');dump('mapa');mem[S.map_mode]=0;
mem[S.player]=mem[S.monster];call('chase');assert.equal(mem[S.game_over],1);ok('Monster contact triggers defeat');
// Full loop: map toggles once while held, pause freezes state, release resumes.
mem[S.game_over]=0;mem[S.player]=17;mem[S.monster]=mem[S.spawn_table];mem[S.enemy_timer]=200;mem[S.last_loop]=mem[S.clock];cpu.regs.pc=S.main;cpu.regs.halted=0;
// Regression for real TK95: one turn per press, even held or bouncing.
mem[S.stun]=255;const heading=mem[S.direction];held=3;frames(24);assert.equal(mem[S.direction],(heading+3)&3);held=3;frames(24);assert.equal(mem[S.direction],(heading+3)&3);
for(let k=0;k<8;k++){held=0;frames(1);held=3;frames(1)}frames(10);assert.equal(mem[S.direction],(heading+3)&3);
held=4;frames(12);assert.equal(mem[S.direction],(heading+3)&3);held=0;frames(6);held=4;frames(24);assert.equal(mem[S.direction],heading);frames(24);assert.equal(mem[S.direction],heading);
held=0;frames(6);held=4;frames(18);assert.equal(mem[S.direction],(heading+1)&3);held=0;frames(6);
ok('TK95 regression: held O/P turns exactly 90 degrees; release bounce ignored; stable release rearms');
mem[S.stun]=255;
held=6;frames(20);assert.equal(mem[S.map_mode],1);held=0;frames(4);held=6;frames(12);assert.equal(mem[S.map_mode],0);held=0;frames(4);
held=7;frames(10);held=0;frames(10);const frozen=mem[S.monster];frames(150);assert.equal(mem[S.monster],frozen);held=7;frames(4);held=0;frames(10);ok('Real keyboard: held M toggles once; H pauses and resumes');
assert(ports>50);ok('Beeper writes recorded on port FE');
const durations={};for(let name of ['music_title','fx_seal','fx_repel','fx_win','fx_loss']){cpu.regs.hl=S[name];audioEvents=[];const t=hal.tStateCount,cycles=call('play_fx');assert(audioEvents.length>80);assert.equal(audioEvents.at(-1)[1],0);durations[name]=cycles;
if(name==='music_title'&&hz===50){const rate=44100,count=Math.ceil(cycles/3500000*rate)+rate/4,pcm=Buffer.alloc(count*2);let j=0,level=0,prev=0,filtered=0;for(let i=0;i<count;i++){let clock=t+i*3500000/rate;while(j<audioEvents.length&&audioEvents[j][0]<=clock)level=audioEvents[j++][1]?0.6:0;filtered=level-prev+0.995*filtered;prev=level;pcm.writeInt16LE(Math.max(-32767,Math.min(32767,Math.round(filtered*26000))),i*2)}const h=Buffer.alloc(44);h.write('RIFF');h.writeUInt32LE(pcm.length+36,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(rate,24);h.writeUInt32LE(rate*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(pcm.length,40);fs.writeFileSync(path.join(root,'build/musica-apresentacao.wav'),Buffer.concat([h,pcm]));}audioEvents=null;}
assert(durations.fx_repel<175000);assert(durations.fx_seal<175000);report.audioCycles=durations;ok('Distinct beeper scores execute and finish silent; pickup and stun effects under 50ms CPU time');
report.note='CPU instruction timing only; no ULA contention or real TK95 measured. Every walkable cell and direction rendered.';
report.portWrites=ports;fs.writeFileSync(path.join(root,'build/test-report-'+hz+'hz.json'),JSON.stringify(report,null,2));console.log(JSON.stringify(report,null,2));
})().catch(e=>{console.error(e);process.exitCode=1});
