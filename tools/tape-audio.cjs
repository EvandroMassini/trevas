// Standard ROM tape pulses, mono PCM16 44100 Hz. No dependency.
const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..'),tap=fs.readFileSync(path.join(root,'build/trevas.tap'));
const rate=44100,clock=3500000,chunks=[];let phase=1,remainder=0,samples=0;
function pulse(t){const exact=t*rate/clock+remainder,n=Math.floor(exact);remainder=exact-n;const b=Buffer.alloc(n*2);for(let i=0;i<n;i++)b.writeInt16LE(phase*22000,i*2);chunks.push(b);samples+=n;phase=-phase}
function silence(s){const n=Math.round(s*rate);chunks.push(Buffer.alloc(n*2));samples+=n}
silence(2);
for(let p=0;p<tap.length;){const len=tap.readUInt16LE(p),b=tap.subarray(p+2,p+2+len);p+=len+2;phase=1;for(let i=0;i<(b[0]<128?8063:3223);i++)pulse(2168);pulse(667);pulse(735);for(let v of b)for(let bit=7;bit>=0;bit--){const t=v&(1<<bit)?1710:855;pulse(t);pulse(t)}silence(1);}
silence(2);const h=Buffer.alloc(44);h.write('RIFF');h.writeUInt32LE(36+samples*2,4);h.write('WAVEfmt ',8);h.writeUInt32LE(16,16);h.writeUInt16LE(1,20);h.writeUInt16LE(1,22);h.writeUInt32LE(rate,24);h.writeUInt32LE(rate*2,28);h.writeUInt16LE(2,32);h.writeUInt16LE(16,34);h.write('data',36);h.writeUInt32LE(samples*2,40);
fs.writeFileSync(path.join(root,'build/trevas.wav'),Buffer.concat([h,...chunks]));console.log('WAV:',(samples/rate).toFixed(1),'seconds');
