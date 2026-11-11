const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const s=fs.readFileSync(path.resolve(__dirname,'../../Sources/LumaReader/Resources/Reader.js'),'utf8');
const a=s.indexOf('  let frozenGeometry='),b=s.indexOf('  let layoutDirty=',a);
function style(){const m=new Map();return {getPropertyValue:k=>m.get(k)?.[0]||'',getPropertyPriority:k=>m.get(k)?.[1]||'',setProperty:(k,v,p)=>m.set(k,[v,p]),removeProperty:k=>m.delete(k)}}
const frames=[],messages=[];let measures=0;
const ctx={innerWidth:1280,innerHeight:800,viewportChanging:false,stableAnchor:null,layoutDirty:false,pageColumns:2,pagePitch:624,pageIndex:0,pageCount:10,
 performance:{now:()=>0},visibleAnchor:()=>({start:123}),hideDeleteButton(){},requestAnimationFrame:f=>{frames.push(f);return 1},send:x=>messages.push(x),
 document:{fonts:{status:'loaded'},getElementById:()=>viewport},getComputedStyle:()=>({columnCount:root.style.getPropertyValue('column-count')||(ctx.innerWidth>=1000?'2':'1'),columnGap:'80px'})};
const viewport={style:style(),getBoundingClientRect:()=>({left:Number.parseFloat(viewport.style.getPropertyValue('left'))||56,top:32,width:Number.parseFloat(viewport.style.getPropertyValue('width'))||(ctx.innerWidth>=1000?ctx.innerWidth-112:Math.min(680,ctx.innerWidth-112)),height:720})};
const root={style:style(),get clientWidth(){return Number.parseFloat(root.style.getPropertyValue('width'))||viewport.getBoundingClientRect().width},get clientHeight(){return 720}};
ctx.root=root;ctx.measurePages=()=>{measures++;ctx.pageColumns=Number(ctx.getComputedStyle().columnCount);ctx.pagePitch=(root.clientWidth+80)/ctx.pageColumns};
vm.createContext(ctx);const api=vm.runInContext('(()=>{'+s.slice(a,b)+'return {begin:beginLayoutTransaction,end:commitLayoutTransaction,diagnostics:()=>({viewportEpoch,viewportTransaction,frozenGeometry,layoutLog})}})()',ctx);
function flush(){while(frames.length)frames.splice(0).forEach(f=>f())}
(async()=>{
for(let i=0;i<20;i++){
 const columns=ctx.pageColumns,width=root.clientWidth,token='turn-'+i;api.begin(token);
 ctx.innerWidth=ctx.innerWidth===1280?800:1280;
 assert.equal(Number(ctx.getComputedStyle().columnCount),columns,'Column count freezes across the 1000px media boundary');assert.equal(root.clientWidth,width,'Viewport and root width remain coherent');
 const done=api.end(token);flush();assert.equal(await done,true);assert.equal(ctx.viewportChanging,false);assert.equal(ctx.pageColumns,ctx.innerWidth>=1000?2:1);assert.equal(ctx.stableAnchor.start,123);
}
assert.equal(measures,20);
api.begin('old');const stale=api.end('old');api.begin('new');flush();assert.equal(await stale,false,'An obsolete async commit cannot restore styles');assert.equal(ctx.viewportChanging,true);
const done=api.end('new');flush();assert.equal(await done,true);assert.equal(measures,21);
assert.equal(messages.filter(m=>m.token==='old').length,0);
assert(api.diagnostics().layoutLog.some(x=>x.event==='cancelled-end'));
console.log('Bidirectional pagination transaction: PASS (20 size switches + stale cancellation; style/geometry fixture)');
})().catch(e=>{console.error(e);process.exit(1)});
