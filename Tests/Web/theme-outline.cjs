const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.resolve(__dirname,'../../Sources/LumaReader/Resources');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.LUMA_CHROMIUM||'/tmp/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 try{
  const page=await browser.newPage({viewport:{width:1100,height:800}}),errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  const html='<html data-paged><body><div id="luma-viewport"><main id="luma-content">'+Array.from({length:50},(_,i)=>`<h2 id="section-${i}">小标题 ${i}</h2><p>${'保持正文、批注和当前位置。'.repeat(50)}</p>`).join('')+'</main></div><div id="luma-page-numbers"></div></body></html>';
  await page.setContent(html);await page.addStyleTag({content:fs.readFileSync(path.join(root,'Reader.css'),'utf8')});
  await page.addScriptTag({content:fs.readFileSync(path.join(root,'Reader.js'),'utf8')});
  const options={colors:{paper:'#F9F9EE',ink:'#1B1C15',accent:'#566524',muted:'#45483C',surface:'#EDEEE3',line:'#C6C8B8'},lineHeight:1.75,paragraphSpacing:1.35,indent:false,focus:false};
  await page.evaluate(o=>{window.opts=o;Luma.settings(19,680,false,'black','serif',o);Luma.restore(.45);window.rootBefore=document.querySelector('#luma-content');window.textBefore=rootBefore.firstChild;window.stateBefore=Luma.pageState();},options);
  await page.evaluate(()=>document.fonts.ready);
  // Settle any font-driven measurement before recording position.
  await page.evaluate(()=>{Luma.restore(.45);window.stateBefore=Luma.pageState()});
  await page.evaluate(()=>{opts={...opts,colors:{...opts.colors,paper:'#171B24',ink:'#DFE2EF',accent:'#ADC6FF'}};Luma.settings(19,680,true,'paper','serif',opts)});
  assert.deepEqual(await page.evaluate(()=>({index:Luma.pageState().index,count:Luma.pageState().count})),await page.evaluate(()=>({index:stateBefore.index,count:stateBefore.count})),'Color-only updates must preserve pagination');
  assert(await page.evaluate(()=>rootBefore===document.querySelector('#luma-content')&&textBefore===rootBefore.firstChild),'Color updates preserve original text nodes');
  assert.equal(await page.locator('body').evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(23, 27, 36)');
  assert.equal(await page.locator('#luma-content').evaluate(e=>getComputedStyle(e).color),'rgb(223, 226, 239)');
  assert.equal(await page.evaluate(()=>document.documentElement.style.colorScheme),'dark');
  const before=await page.evaluate(()=>Luma.pageState().count);
  await page.evaluate(()=>{opts={...opts,lineHeight:2.5,paragraphSpacing:2,indent:true,focus:true};Luma.settings(19,680,true,'paper','serif',opts)});
  assert((await page.evaluate(()=>Luma.pageState().count))>before,'Line and paragraph spacing repaginate');
  assert.equal(await page.locator('#luma-content p').first().evaluate(e=>getComputedStyle(e).textIndent),'38px');
  await page.mouse.move(550,790);
  assert.equal(await page.locator('#luma-page-numbers span').count(),0,'Bottom hover must not reveal page numbers');
  assert(await page.evaluate(()=>Luma.jumpToHeading({fragment:'section-30'})),'Fragment resolves');
  assert(await page.locator('#section-30').evaluate(e=>{const r=e.getBoundingClientRect();return r.left>=0&&r.left<innerWidth}),'Fragment jump shows target spread');
  assert(await page.evaluate(()=>Luma.jumpToHeading({headingIndex:5})),'Heading fallback resolves');
  assert(await page.locator('#section-5').evaluate(e=>{const r=e.getBoundingClientRect();return r.left>=0&&r.left<innerWidth}),'Heading index shows target spread');
  assert.equal(await page.evaluate(()=>Luma.jumpToHeading({fragment:'does-not-exist'})),false);
  // Load the real AI document with inline local assets to test live palette updates.
  let ai=fs.readFileSync(path.join(root,'AIChat.html'),'utf8').replace(/<meta http-equiv="Content-Security-Policy"[^>]*>/,'')
   .replace('<link rel="stylesheet" href="AIChat.css">','<style>'+fs.readFileSync(path.join(root,'AIChat.css'),'utf8')+'</style>')
   .replace('<script src="AIChat.js"></script>','');
  await page.setViewportSize({width:340,height:800});await page.setContent(ai);await page.addScriptTag({content:fs.readFileSync(path.join(root,'AIChat.js'),'utf8')});
  const state={provider:'claude',providers:[{id:'claude',title:'Claude'}],model:'fixture',draft:'保留我的问题',messages:[{role:'assistant',text:'已有回答'}],includeReading:false,pendingQuote:'',isSending:false,dark:true,colors:options.colors};
  await page.evaluate(s=>{window.s=s;LumaAI.receive(s);window.answerBefore=document.querySelector('.message');},state);
  await page.evaluate(()=>{s={...s,colors:{...s.colors,paper:'#171B24',ink:'#DFE2EF',accent:'#ADC6FF'}};LumaAI.receive(s)});
  assert.equal(await page.locator('body').evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(23, 27, 36)','AI paper equals reader paper');
  assert.equal(await page.locator('body').evaluate(e=>getComputedStyle(e).color),'rgb(223, 226, 239)','AI ink equals reader ink');
  assert(await page.evaluate(()=>answerBefore===document.querySelector('.message')),'Theme updates preserve answer nodes');
  assert.equal(await page.locator('#draft').inputValue(),'保留我的问题');
  const close=await page.locator('#collapse').boundingBox(),identity=await page.locator('.identity').boundingBox();assert(close.x<identity.x,'AI collapse is on the left');
  assert.equal(await page.locator('header button').first().getAttribute('id'),'collapse','Collapse leads keyboard order');
  assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'340px AI has no horizontal overflow');
  assert.deepEqual(errors,[]);
  console.log('PASS theme parity, stable DOM and reading position, typography repagination, focus progress reveal, fragment/heading navigation, left AI close and draft retention');
 }finally{await browser.close()}
})().catch(e=>{console.error(e);process.exit(1)});
