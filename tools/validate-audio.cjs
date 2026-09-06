// Decode the generated PCM pulses back into TAP blocks, independently.
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.resolve(__dirname,'../build'),wav=fs.readFileSync(path.join(root,'trevas.wav')),tap=fs.readFileSync(path.join(root,'trevas.tap'));
assert.equal(wav.toString('ascii',0,4),'RIFF');assert.equal(wav.readUInt32LE(24),44100);assert.equal(wav.readUInt32LE(40),wav.length-44);
const groups=[];let runs=[],last=0,n=0;for(let i=44;i<wav.length;i+=2){let s=Math.sign(wav.readInt16LE(i));if(s===last){n++;continue}if(last)runs.push(n);if(!s&&runs.length){groups.push(runs);runs=[]}last=s;n=1;}
let index=0;for(let p=0;p<tap.length;index++){const len=tap.readUInt16LE(p),b=tap.subarray(p+2,p+2+len);p+=len+2;const r=groups[index],pilot=b[0]<128?8063:3223;assert.equal(r.length,pilot+2+len*16);assert(r.slice(0,pilot).every(n=>n>=27&&n<=28));assert(r[pilot]>=8&&r[pilot]<=9);assert(r[pilot+1]>=9&&r[pilot+1]<=10);const decoded=Buffer.alloc(len);let j=pilot+2;for(let x=0;x<len;x++)for(let bit=7;bit>=0;bit--){let a=r[j++],c=r[j++];assert(Math.abs(a-c)<=1);assert((a>=10&&a<=11)||(a>=21&&a<=22));decoded[x]|=(a>16?1:0)<<bit;}assert.deepEqual(decoded,b);}
assert.equal(index,groups.length);console.log('PASS WAV decoded back to all '+index+' original TAP blocks');
