const fs=require('fs'),vm=require('vm'),assert=require('node:assert/strict'),path=require('path');
const source=fs.readFileSync(path.resolve(__dirname,'../../Experiments/PageCurlLab.html'),'utf8');
const a=source.indexOf('function curlPoint('),b=source.indexOf('\nfunction shader(',a),ctx={Math};vm.createContext(ctx);vm.runInContext(source.slice(a,b),ctx);
for(const dir of [-1,1])for(let step=0;step<=100;step++)for(let row=0;row<=20;row++)for(let col=0;col<=20;col++){
 const x=col/10-1,y=row/10-1,p=step/100,r=ctx.curlPoint(x,y,p,dir),mirror=ctx.curlPoint(-x,y,p,-dir);
 assert([r.x,r.y,r.z].every(Number.isFinite));assert(r.z>=-1e-9&&r.z<=.36+1e-9);assert(Math.abs(r.x+mirror.x)<1e-9);assert(Math.abs(r.z-mirror.z)<1e-9);
}
assert.equal(ctx.curlPoint(.5,0,0).x,.5);assert.equal(ctx.curlPoint(.5,0,0).z,0);
console.log('Curl cylinder math: PASS (directions, 101 progress steps, 21×21 points; no GPU validation)');
