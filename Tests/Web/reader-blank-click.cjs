const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const s=fs.readFileSync(path.resolve(__dirname,'../../Sources/LumaReader/Resources/Reader.js'),'utf8');
const a=s.indexOf('  let blankPointer=null;'),b=s.indexOf('  function readingContext()',a);
const handlers={},sent=[];let selection=null,annotation=null;
const ctx={root:{addEventListener:(k,f)=>handlers[k]=f},capture:()=>selection,savedSelection:null,noteAtPoint:()=>annotation,send:x=>sent.push(x)};
vm.createContext(ctx);vm.runInContext(s.slice(a,b),ctx);
const target={closest:()=>false};function down(){handlers.pointerdown({button:0,clientX:10,clientY:10,target})}function up(x=10){handlers.pointerup({button:0,clientX:x,clientY:10,target})}
down();assert.equal(sent.length,0,'Never collapse on pointerdown');up();assert.equal(sent.length,1);
down();up(20);assert.equal(sent.length,1,'Dragging must not dismiss AI');
selection={quote:'selected'};down();selection=null;up();assert.equal(sent.length,1,'First click clears old selection only');
down();selection={quote:'new selection'};up();assert.equal(sent.length,1,'New selection keeps AI open');
selection=null;annotation={id:'note'};down();up();assert.equal(sent.length,1,'Annotation clicks keep AI');
console.log('Reader click/selection guard: PASS');
