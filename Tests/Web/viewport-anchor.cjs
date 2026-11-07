const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const source=fs.readFileSync(path.resolve(__dirname,'../../Sources/LumaReader/Resources/Reader.js'),'utf8');
const begin=source.slice(source.indexOf('  function beginLayoutTransaction('),source.indexOf('  async function commitLayoutTransaction('));
function fixture(anchor){
 const viewport={style:{setProperty(){}},getBoundingClientRect:()=>({width:500,height:600,left:0,top:32})};
 let snapshots=0;
 const context={viewportTransaction:null,viewportEpoch:0,frozenGeometry:null,viewportChanging:false,stableAnchor:anchor,
  hideDeleteButton(){},visibleAnchor:()=>({start:900,quote:'new layout first line'}),
  document:{getElementById:()=>viewport},getComputedStyle:()=>({columnCount:'1',columnGap:'80px'}),
  root:{clientWidth:500,clientHeight:600,style:{setProperty(){}}},snapshotStyles(){snapshots++;return [];},traceLayout(){},pageColumns:1,pagePitch:580};
 vm.createContext(context);vm.runInContext(begin,context);
 return {context,snapshots:()=>snapshots};
}
const saved={start:400,quote:'the reader actual position'};
const a=fixture(saved);
a.context.beginLayoutTransaction('open');
assert.equal(a.context.stableAnchor,saved,'A resize may have changed visible geometry before the transaction; retain the last painted reading anchor');
a.context.beginLayoutTransaction('close');
assert.equal(a.context.stableAnchor,saved,'Interrupted AI toggles must retain the same anchor');
assert.equal(a.snapshots(),2,'Freeze the viewport/root styles only once across interruptions');
const b=fixture(null);b.context.beginLayoutTransaction('first');
assert.equal(b.context.stableAnchor.start,900,'Capture visible text only when no established anchor exists');
console.log('Viewport reading anchor: PASS (resize-before-begin and interrupted-toggle regressions)');
