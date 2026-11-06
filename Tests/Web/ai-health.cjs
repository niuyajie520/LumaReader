// Production read-only probe in a controlled DOM harness. NOT a browser or native UI test.
const fs=require('fs'),path=require('path'),vm=require('vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(path.join(__dirname,'../../Sources/LumaReader/Resources/AIHealth.js'),'utf8');
const ids=['collapse','pin','expand','new','settings','provider','model','messages','draft','include','send'];
function run({missing=[],css=true,icon=20,overflow=0,bridge=true,width=340}={}){
 const context={window:{LumaAI:bridge?{receive(){}}:{}},getComputedStyle:()=>({display:css?'none':'block'}),document:{
  getElementById:id=>missing.includes(id)?null:{value:'sk-PRIVATE',textContent:'PRIVATE_BOOK'},querySelector:()=>({}),
  querySelectorAll:()=>[{closest:()=>null,getBoundingClientRect:()=>({width:icon,height:icon})}],
  documentElement:{clientWidth:width,clientHeight:600},body:{scrollWidth:width+overflow}}};
 return JSON.parse(JSON.stringify(vm.runInNewContext(source,context)));
}
const healthy=run();assert.equal(healthy.missingNodes,0);assert.equal(healthy.stylesReady,1);assert.equal(healthy.oversizedIcons,0);
assert.equal(run({css:false}).stylesReady,0,'Detect missing stylesheet');
assert.equal(run({missing:['draft','send']}).missingNodes,2,'Detect broken input/actions');
assert.equal(run({icon:300}).oversizedIcons,1,'Detect giant icons');
assert.equal(run({overflow:120}).overflow,1,'Detect horizontal overflow');
assert.equal(run({bridge:false}).bridgeReady,0,'Detect missing receive function');
assert.equal(run({width:0}).layoutReady,0,'Do not infer GPU failure from unlaid-out view');
assert(Object.values(healthy).every(Number.isFinite));assert(!JSON.stringify(healthy).includes('PRIVATE'));
assert(!/reload\(|fetch\(|postMessage|\.value|textContent|innerHTML/.test(source));
console.log('AI health probe: 8 controlled fault/privacy scenarios PASS (DOM harness only)');
