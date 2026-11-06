const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const resources=path.resolve(__dirname,'../../Sources/LumaReader/Resources');
const script=fs.readFileSync(path.join(resources,'Reader.js'),'utf8'),css=fs.readFileSync(path.join(resources,'Reader.css'),'utf8');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.LUMA_CHROMIUM||'/tmp/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 try{
  const page=await browser.newPage({viewport:{width:1380,height:840}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  const markup='<html data-paged><body><div id="luma-viewport"><main id="luma-content">'+Array.from({length:120},(_,i)=>`<h2 id="s-${i}">第${i}节</h2><p>【段落${i}】${('阅读位置📖应该跟着这句话，而不是页码。'+i+'，').repeat(30)}</p>`).join('')+'</main></div><div id="luma-page-numbers"></div></body></html>';
  async function load(fallback){await page.goto('about:blank');await page.setContent(markup);await page.addStyleTag({content:css});if(fallback)await page.evaluate(()=>window.Highlight=undefined);await page.addScriptTag({content:script});await page.evaluate(()=>{Luma.settings(19,680,false,'paper','serif',{lineHeight:1.75,paragraphSpacing:1.35});Luma.restore(.47)});await page.evaluate(()=>Luma.preparePresentation('loaded'));}
  async function assertVisible(anchor,label){
   const visible=await page.evaluate(a=>{
    const root=document.getElementById('luma-content'),walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let at=0,n,point;
    while(n=walker.nextNode()){if(n.parentElement.closest('script,style,noscript'))continue;if(at+n.length>a.start){point={node:n,offset:a.start-at};break}at+=n.length;}
    if(!point)return false;const r=document.createRange();r.setStart(point.node,point.offset);r.setEnd(point.node,Math.min(point.node.length,point.offset+1));const v=document.getElementById('luma-viewport').getBoundingClientRect();
    return [...r.getClientRects()].some(b=>b.height>0&&b.left>=v.left-1&&b.right<=v.right+1&&b.bottom>v.top&&b.top<v.bottom);
   },anchor);assert(visible,label);
  }
  for(const fallback of [false,true]){
   await load(fallback);
   const saved=await page.evaluate(()=>({offset:Luma.pageState().offset,anchor:Luma.textAnchor()}));assert(saved.anchor.start>0);await assertVisible(saved.anchor,'Original anchor is visible');
   for(let i=0;i<12;i++){
    await page.setViewportSize({width:[740,920,1460,1100][i%4],height:[740,900,810][i%3]});
    await page.evaluate(()=>Luma.preparePresentation('resize'));
    assert.equal((await page.evaluate(()=>Luma.textAnchor())).start,saved.anchor.start,'Window/AI width changes do not drift text anchor');
    await assertVisible(saved.anchor,'Original sentence stays on screen after resize');
   }
   for(const [size,width,font,leading,spacing] of [[28,500,'sans',2.3,2],[16,880,'mono',1.4,.1],[22,620,'serif',1.9,1.5]]){
    await page.evaluate(o=>Luma.settings(o.size,o.width,false,'paper',o.font,{lineHeight:o.leading,paragraphSpacing:o.spacing,indent:true}),{size,width,font,leading,spacing});
    await page.evaluate(()=>Luma.preparePresentation('typeset'));
    assert.equal((await page.evaluate(()=>Luma.textAnchor())).start,saved.anchor.start,'Typography preserves anchor');await assertVisible(saved.anchor,'Sentence visible after typesetting');
   }
   await page.evaluate(()=>Luma.beginViewportChange());const before=await page.evaluate(()=>Luma.diagnostics().layoutMeasures);
   for(const w of [750,850,970,1060,1180,1430])await page.setViewportSize({width:w,height:820});
   await page.waitForTimeout(60);
   assert.equal(await page.evaluate(()=>Luma.diagnostics().layoutMeasures),before,'Drag does not repeatedly repaginate under frozen page');
   await page.evaluate(()=>Luma.endViewportChange('done'));
   assert.equal(await page.evaluate(()=>Luma.diagnostics().layoutMeasures),before+1,'Drag release performs one final layout');
   await assertVisible(saved.anchor,'Anchor preserved after held layout');
   await load(fallback);await page.setViewportSize({width:780,height:740});
   await page.evaluate(s=>Luma.restore(s.offset,s.anchor),saved);await page.evaluate(()=>Luma.preparePresentation('reopen'));
   assert.equal((await page.evaluate(()=>Luma.textAnchor())).start,saved.anchor.start,'Reopen at another width restores exact source offset');await assertVisible(saved.anchor,'Reopened anchor visible');
   const quote=await page.evaluate(a=>{const text=document.getElementById('luma-content').textContent;return text.slice(a.start,a.start+40)},saved.anchor);
   await page.evaluate(a=>Luma.render([{id:'note',start:a.start,end:a.start+40,color:'#E9BE42'}]),saved.anchor);
   await page.evaluate(()=>Luma.jump('note'));assert(await page.locator('#luma-note-focus i').count()>0,'Note jump has visible location cue');
   assert.equal(await page.locator('#luma-note-focus').evaluate(e=>getComputedStyle(e).pointerEvents),'none');
   const noteAnchor=await page.evaluate(()=>Luma.textAnchor());assert.equal(noteAnchor.start,saved.anchor.start);assert(quote.length>0);
   await page.evaluate(()=>Luma.jumpToHeading({fragment:'s-70'}));assert.equal(await page.evaluate(()=>Luma.pageState().headingID),'s-70','Current subheading reported to native outline');
   const headingAnchor=await page.evaluate(()=>Luma.textAnchor());await page.setViewportSize({width:1300,height:810});await page.evaluate(()=>Luma.preparePresentation('heading-resize'));await assertVisible(headingAnchor,'Heading target stays visible');
   await page.evaluate(()=>{window.keyTurns=[];window.addEventListener('luma-reader',e=>{if(e.detail.type==='turn')keyTurns.push(e.detail.delta)});});
   await page.locator('#luma-viewport').click({position:{x:100,y:100}});
   await page.keyboard.press('ArrowLeft');await page.keyboard.press('ArrowRight');
   assert.deepEqual(await page.evaluate(()=>keyTurns),[-1,1],'Plain arrows request exactly one turn each');
   await page.evaluate(()=>{const input=document.createElement('input');input.id='qa-edit';document.body.append(input);input.focus()});
   await page.keyboard.press('ArrowLeft');await page.keyboard.press('ArrowRight');
   assert.deepEqual(await page.evaluate(()=>keyTurns),[-1,1],'Arrows in a text input never turn pages');
   await page.evaluate(()=>document.getElementById('qa-edit').remove());
   // An invalid new-format anchor must still open old progress safely.
   await page.evaluate(()=>Luma.restore(.25,{version:2,start:-1,quote:'invalid'}));assert((await page.evaluate(()=>Luma.pageState().index))>0);
   console.log('PASS semantic location across 12 resizes, typography, reopen, drag batching, current heading and note feedback; fallback='+fallback);
  }
  assert.deepEqual(errors,[]);
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
