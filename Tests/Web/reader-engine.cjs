const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const project=path.resolve(__dirname,'../..');
const assert=require('node:assert/strict');
const optimized=fs.readFileSync(path.join(project,'Sources/LumaReader/Resources/Reader.js'),'utf8');
const baseline=fs.readFileSync(path.join(__dirname,'baseline-reader-v01.js'),'utf8');
(async()=>{
const browser=await chromium.launch({headless:true,...(process.env.LUMA_CHROMIUM ? {executablePath:process.env.LUMA_CHROMIUM,args:['--no-sandbox','--disable-dev-shm-usage']} : {})});
const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));
async function load(script,fallback=false,large=false){
 await page.goto('about:blank');
 await page.setContent('<html><head></head><body><main id="luma-content">'+(large?'<p>阅读时间是一段安静的日常。标注把想法留在文字旁边。</p>'.repeat(1200):'<p>前言📖阅读 test</p><p>第二段，继续阅读。</p>')+'</main></body></html>');
 if(fallback)await page.evaluate(()=>window.Highlight=undefined);
 await page.evaluate(()=>{window.qa={raf:0,timers:0,messages:[]};const raf=requestAnimationFrame;window.requestAnimationFrame=(...a)=>{qa.raf++;return raf(...a)};const timer=setTimeout;window.setTimeout=(...a)=>{qa.timers++;return timer(...a)};window.addEventListener('luma-reader',e=>qa.messages.push(e.detail));});
 await page.addScriptTag({content:script});
}
await load(optimized);
const notes=[{id:'emoji',start:2,end:4,color:'#e9be42'},{id:'quote',start:4,end:9,color:'#699bd3'}];
const original=await page.locator('#luma-content').innerHTML();
assert.equal(await page.evaluate(n=>Luma.render(n),notes),true);
assert.equal(await page.locator('#luma-content').innerHTML(),original);
assert.equal(await page.evaluate(n=>Luma.render(n),notes),false);
assert.equal(await page.evaluate(()=>Luma.diagnostics().annotationCount),2);
assert.equal(await page.evaluate(()=>[...CSS.highlights.values()][0].values().next().value.toString()),'📖');
await page.evaluate(()=>{const node=document.querySelector('p').firstChild;const r=document.createRange();r.setStart(node,2);r.setEnd(node,4);getSelection().removeAllRanges();getSelection().addRange(r)});
await page.waitForTimeout(20);
assert.equal((await page.evaluate(()=>Luma.capture())).quote,'📖');
for(const [theme,dark,paper,font]of [['paper',false,'rgb(250, 248, 243)','serif'],['mint',false,'rgb(243, 247, 240)','sans'],['rose',false,'rgb(252, 244, 247)','rounded'],['midnight',false,'rgb(21, 29, 44)','mono'],['black',false,'rgb(0, 0, 0)','serif']]){
 await page.evaluate(([theme,dark,font])=>Luma.settings(20,640,dark,theme,font),[theme,dark,font]);
 const result=await page.evaluate(()=>{const a=document.createElement('i');a.style.background='var(--paper)';document.body.append(a);const color=getComputedStyle(a).backgroundColor;a.remove();return color});assert.equal(result,paper);
}
assert.equal(await page.evaluate(()=>Luma.settings(20,640,false,'black','serif')),false);
await page.evaluate(()=>{window.mutationCount=0;new MutationObserver(m=>window.mutationCount+=m.length).observe(document.querySelector('#luma-content'),{subtree:true,attributes:true,childList:true,characterData:true})});
await page.waitForTimeout(400);
assert.equal(await page.evaluate(()=>mutationCount),0);
assert.equal(await page.evaluate(()=>qa.raf),0);
assert.equal(await page.evaluate(()=>qa.timers),0);
await load(optimized,true);
await page.evaluate(n=>Luma.render(n),notes);
assert.equal(await page.locator('mark[data-luma-note="emoji"]').innerText(),'📖');
await page.evaluate(()=>Luma.render([]));assert.equal(await page.locator('mark').count(),0);
await page.evaluate(n=>Luma.render(n),notes);assert.equal(await page.locator('mark').count(),2);
await load(optimized,false,true);
await page.evaluate(()=>Luma.restore(0.6));
await page.waitForTimeout(350);
const position=await page.evaluate(()=>qa.messages.filter(m=>m.type==='location').at(-1));
assert.ok(position && Math.abs(position.offset-0.6)<0.01,'Bookmark restores chapter scroll position');
await page.evaluate(()=>Luma.restore(0));
await page.waitForTimeout(350);
assert.equal(await page.evaluate(()=>scrollY),0);
const runs={before:[],after:[]};
for(const [label,script]of [['before',baseline],['after',optimized]]){
 for(let i=0;i<4;i++){
  await load(script,false,true);
  const time=await page.evaluate(()=>{
   const notes=Array.from({length:600},(_,i)=>({id:String(i),start:i*44,end:i*44+12,color:i%2?'#699bd3':'#e9be42'}));
   const start=performance.now();Luma.render(notes);return performance.now()-start;
  });
  runs[label].push(time);
 }
}
assert.deepEqual(errors,[]);
const median=a=>[...a].sort((a,b)=>a-b).slice(1,3).reduce((a,b)=>a+b)/2;
const result={checks:'PASS',errors,fixture:{paragraphs:1200,annotations:600},javascriptRenderMs:{before:runs.before,after:runs.after,medianBefore:median(runs.before),medianAfter:median(runs.after)},idle:{durationMs:400,scheduledFrames:0,scheduledTimers:0,contentMutations:0},limits:'Synthetic Chromium JavaScript timing, not macOS energy, PDFKit, WebKit or full paint measurements.'};
fs.writeFileSync(path.join(__dirname,'performance-result.json'),JSON.stringify(result,null,2));console.log(JSON.stringify(result,null,2));
await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
