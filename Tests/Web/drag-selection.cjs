const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const src=fs.readFileSync(require('node:path').resolve(__dirname,'../../Sources/LumaReader/Resources/Reader.js'),'utf8');
const a=src.indexOf('  let selectionDrag='),b=src.indexOf('  function restorePosition(',a);
const handlers={},node={},selection={rangeCount:1,isCollapsed:false,anchorNode:node,anchorOffset:10,focusNode:node,focusOffset:98,setBaseAndExtent(a,x,b,y){this.anchorOffset=x;this.focusOffset=y;}};
let timer,painted=0,caret=143;
const ctx={pageIndex:0,pageCount:3,pageColumns:1,paged:true,
 nodes:()=>[{end:300}],columnAt:at=>Math.floor(at/100),pointOffset:(n,o)=>o,endpoint:o=>({node,offset:o}),
 getSelection:()=>selection,root:{contains:()=>true},paintPage:()=>painted++,
 setTimeout:f=>{timer=f;return 1},clearTimeout:()=>{timer=null},window:{addEventListener:()=>{}},
 document:{addEventListener:(k,f)=>handlers[k]=f,caretRangeFromPoint:()=>({startContainer:node,startOffset:caret})}};
vm.createContext(ctx);vm.runInContext(src.slice(a,b),ctx);
handlers.pointerdown({button:0,target:node});handlers.pointermove({buttons:1});assert(timer);
timer();assert.equal(ctx.pageIndex,1);assert.equal(selection.anchorOffset,10);assert.equal(selection.focusOffset,100);assert.equal(painted,1);
handlers.pointermove({buttons:1,clientX:20,clientY:20,preventDefault(){}});assert.equal(selection.focusOffset,143,'User picks exact endpoint, not whole paragraph');
handlers.pointerup();caret=180;handlers.pointermove({buttons:0});assert.equal(selection.focusOffset,143,'Release stops extension');
console.log('Drag across pages: PASS (state/UTF-16; native pointer geometry unverified)');
