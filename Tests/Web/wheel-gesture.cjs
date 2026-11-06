const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const s=fs.readFileSync(path.resolve(__dirname,'../../Sources/LumaReader/Resources/Reader.js'),'utf8');
const a=s.indexOf('    let wheelAmount=0,wheelTurned='),b=s.indexOf('    for(const [side,delta]',a);
let handler,time=0;const turns=[];const ctx={window:{addEventListener:(k,f)=>handler=f},performance:{now:()=>time},send:v=>turns.push(v.delta),innerHeight:800};vm.createContext(ctx);vm.runInContext(s.slice(a,b),ctx);
function wheel(delta,advance=30){time+=advance;handler({deltaX:delta,deltaY:0,deltaMode:0,ctrlKey:false})}
wheel(60);wheel(60);for(let i=0;i<60;i++)wheel(12);assert.deepEqual(turns,[1],'Long inertia cannot turn again after 450ms');
wheel(-110,400);assert.deepEqual(turns,[1,-1],'Fresh gesture after quiet interval turns once');
wheel(60,400);wheel(60,400);assert.equal(turns.length,2,'Separate tiny gestures do not accumulate');
console.log('Wheel gesture latch: PASS');
