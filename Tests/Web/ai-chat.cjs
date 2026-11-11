// Exercises the exact WKWebView UI resources. The bridge and answers are fixtures, not paid API calls.
const {chromium}=require('playwright'),fs=require('fs'),path=require('path'),http=require('http'),assert=require('assert');
const root=path.resolve(__dirname,'../../Sources/LumaReader/Resources');
const fixtureDir=process.env.LUMA_AI_FIXTURES || path.resolve(__dirname,'fixtures/ai');
const checks=[]; const ok=(label,value)=>{assert(value,label);checks.push(label);if(process.env.LUMA_QA_PROGRESS)console.error(label)};
(async()=>{const server=http.createServer((req,res)=>{const pathname=new URL(req.url,'http://localhost').pathname;const base=pathname.startsWith('/app/')?root:fixtureDir;const name=pathname.startsWith('/app/')?pathname.slice(5):pathname.slice(1)||'index.html';if(!/^[A-Za-z0-9.-]+$/.test(name)){res.writeHead(404).end();return}try{if(name==='AIChat-seeded.html'&&process.env.LUMA_THEMED_HTML){res.setHeader('Content-Type','text/html; charset=utf-8');res.end(fs.readFileSync(process.env.LUMA_THEMED_HTML));return}const types={'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript'};res.setHeader('Content-Type',types[path.extname(name)]||'text/plain');res.end(fs.readFileSync(path.join(base,name)))}catch{res.writeHead(404).end()}});await new Promise(r=>server.listen(0,'127.0.0.1',r));let browser;
try{browser=await chromium.launch({executablePath:process.env.LUMA_CHROMIUM||'/tmp/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});const page=await browser.newPage({viewport:{width:1080,height:900},deviceScaleFactor:2});page.setDefaultTimeout(12000);const errors=[];page.on('pageerror',e=>errors.push(e.message));if(process.env.LUMA_THEMED_HTML){
await page.goto(`http://127.0.0.1:${server.address().port}/app/AIChat-seeded.html`);
ok('initial AI background is black before receiving native state',await page.evaluate(()=>getComputedStyle(document.body).backgroundColor==='rgb(0, 0, 0)'));
ok('initial AI document retains dark color scheme',await page.evaluate(()=>getComputedStyle(document.documentElement).colorScheme==='dark'));
await page.evaluate(()=>{document.documentElement.style.setProperty('--paper','#F3F7F0');document.documentElement.style.colorScheme='light'});
ok('seeded AI document can still change theme without reloading',await page.evaluate(()=>getComputedStyle(document.body).backgroundColor==='rgb(243, 247, 240)'));

}
await page.goto(`http://127.0.0.1:${server.address().port}/index.html`);await page.frameLocator('#mint').locator('#provider option').first().waitFor({state:'attached'});const mint=page.frameLocator('#mint'),black=page.frameLocator('#black');
await page.locator('#mint').evaluate(el=>{const w=el.contentWindow;w.__fixture.state.pendingImageName='figure.png';w.LumaAI.receive(structuredClone(w.__fixture.state))});
ok('pending image filename is visible',await mint.locator('#image-attachment').isVisible() && (await mint.locator('#image-attachment').textContent()).includes('figure.png'));
await mint.locator('#remove-image').click();ok('pending image can be removed',!await mint.locator('#image-attachment').isVisible());
const longQuote='这是完全虚构的测试段落，只用于检查引用预览与文本选择，不对应任何真实图书、私人笔记或聊天记录。';
await page.locator('#mint').evaluate((el,quote)=>{const w=el.contentWindow;w.__fixture.state.pendingQuote=quote;w.LumaAI.receive(structuredClone(w.__fixture.state))},longQuote);
ok('composer reference shows beginning and end',await mint.locator('#selection-preview').textContent()===Array.from(longQuote).slice(0,12).join('')+'…'+Array.from(longQuote).slice(-12).join(''));
ok('reference starts folded',!await mint.locator('#selection-full').isVisible());
await mint.locator('#selection-detail summary').click();ok('reference expands to the complete selection',await mint.locator('#selection-full').isVisible()&&await mint.locator('#selection-full').textContent()===longQuote);
await mint.getByLabel('移除选文',{exact:true}).click();ok('reference clears through native bridge',!await mint.locator('#selection-reference').isVisible());
await page.locator('#mint').evaluate(el=>{const w=el.contentWindow;w.__fixture.state.pendingQuote='判断是一种我们对事物之间关系的认识。';w.LumaAI.receive(structuredClone(w.__fixture.state))});
ok('selection updates leave the question blank',await mint.locator('#draft').inputValue()==='');
await mint.locator('#selection-detail').evaluate(el=>{const summary=el.querySelector('summary');summary.click();setTimeout(()=>summary.click(),40);setTimeout(()=>summary.click(),80)});
await page.waitForTimeout(360);
ok('reference animation reverses on rapid clicks and settles',await mint.locator('#selection-detail').evaluate(el=>el.open&&el.getAnimations().length===0));
await page.emulateMedia({reducedMotion:'reduce'});await mint.locator('#selection-detail summary').click();
ok('reduced motion changes reference state immediately',await mint.locator('#selection-detail').evaluate(el=>!el.open&&el.getAnimations().length===0));
await page.emulateMedia({reducedMotion:'no-preference'});

await mint.locator('#draft').fill('我自己输入的问题');
await mint.locator('#draft').blur();
await page.locator('#mint').evaluate(el=>{const w=el.contentWindow;w.__fixture.state.pendingQuote='另一段引用，保持用户自己输入的问题。';w.LumaAI.receive(structuredClone(w.__fixture.state))});
ok('new reference preserves the users typed draft',await mint.locator('#draft').inputValue()==='我自己输入的问题');
await mint.locator('#draft').fill('');await mint.locator('#draft').blur();
ok('six providers are listed',await mint.locator('#provider option').count()===6);
for(const provider of ['deepseek','claude','gemini','openai','grok','qwen']){await mint.getByLabel('AI 服务商').selectOption(provider);ok('provider switches: '+provider,await mint.locator('#provider').inputValue()===provider)}
await mint.getByLabel('AI 服务商').selectOption('claude');await mint.getByLabel('设置 API').click();ok('settings action reaches native bridge',await page.locator('#mint').evaluate(el=>el.contentWindow.__fixture.actions.some(a=>a.action==='settings')));
await mint.getByText('虚构测试读本',{exact:true}).click();ok('quote expands',await mint.locator('#quote').isVisible());await mint.getByRole('button',{name:'移除引用'}).click();ok('quote can be removed',!await mint.locator('#quote').isVisible());
await mint.getByLabel('附带当前阅读').uncheck();ok('context can be excluded',!await mint.locator('#reading').isVisible());await mint.getByLabel('附带当前阅读').check();
await mint.getByLabel('给 AI 的问题').fill('这句话是什么意思？请举一个例子。');await mint.getByRole('button',{name:'发送',exact:true}).click();await mint.locator('.message.assistant').waitFor();ok('send returns a fixture answer',await mint.locator('.message').count()===2);ok('provider attribution is retained',(await mint.locator('.message.assistant .who').innerText()).includes('Claude'));
await mint.getByLabel('给 AI 的问题').fill('停止测试');await mint.getByRole('button',{name:'发送',exact:true}).click();await mint.getByRole('button',{name:'停止',exact:true}).click();ok('stop reenables composer',await mint.locator('#draft').isEnabled());
await mint.getByRole('button',{name:'新对话'}).click();ok('new conversation clears history',await mint.locator('.message').count()===0);await mint.getByRole('button',{name:'解释这段话',exact:true}).click();ok('suggestion populates draft',(await mint.locator('#draft').inputValue()).includes('解释这段话'));
await mint.getByRole('button',{name:'发送',exact:true}).click();await mint.locator('.message.assistant').waitFor();await mint.getByLabel('给 AI 的问题').fill('这里的“判断”和“概念”有什么不同？');
// Restore a quote for a reviewable screenshot using the same native-state receiver.
await page.locator('#mint').evaluate(el=>{const w=el.contentWindow;w.__fixture.state.pendingQuote='判断是一种我们对事物之间关系的认识。';w.LumaAI.receive(w.__fixture.state)});
await black.getByLabel('AI 服务商').selectOption('gemini');
ok('mint icon uses theme color',(await mint.locator('.brand').evaluate(el=>getComputedStyle(el).color))==='rgb(110, 146, 119)');ok('black uses a black background',(await black.locator('body').evaluate(el=>getComputedStyle(el).backgroundColor))==='rgb(0, 0, 0)');
// Untrusted response text must never create HTML or execute scripts.
await page.locator('#black').evaluate(el=>{const w=el.contentWindow;w.__fixture.state.messages=[{role:'assistant',text:'<img src=x onerror="window.pwned=true">'}];w.LumaAI.receive(w.__fixture.state)});ok('AI output is rendered as plain text',await black.locator('.message img').count()===0);await black.getByRole('button',{name:'新对话'}).click();
// Explicit malicious network attempt is blocked by the shipped UI CSP.
const blocked=await page.locator('#mint').evaluate(async el=>{try{await el.contentWindow.fetch('https://example.com/unwanted');return false}catch{return true}});ok('UI cannot send network requests',blocked);
await mint.locator('#reading').evaluate(el=>el.open=false);await mint.locator('#messages').evaluate(el=>el.scrollTop=0);
await page.screenshot({path:process.env.LUMA_AI_SCREENSHOT||'/tmp/luma-ai-ui.png',fullPage:true});
await page.setViewportSize({width:780,height:900}); // Iframes now ~380px; check minimum-width usability.
for(const f of [mint,black])ok('narrow window has no horizontal overflow',await f.locator('body').evaluate(el=>el.scrollWidth<=el.clientWidth));
// Paired reading/AI layout: real resource files, simulated native split container.
await page.setViewportSize({width:1280,height:840});
await page.goto(`http://127.0.0.1:${server.address().port}/workspace.html`);
const ai=page.frameLocator('#ai'),reader=page.frameLocator('#book');
await ai.locator('#provider option').first().waitFor({state:'attached'});
await reader.locator('#luma-page-numbers span').first().waitFor();
const before=await page.locator('#book').boundingBox(),side=await page.locator('#ai').boundingBox();
ok('reading is left of AI',before.x+before.width<=side.x+2);
await ai.getByLabel('给 AI 的问题').fill('概念和判断有什么区别？');
await ai.getByRole('button',{name:'发送',exact:true}).click();await ai.locator('.message.assistant').waitFor();
await ai.locator('#messages').evaluate(el=>el.scrollTop=0);
await page.screenshot({path:process.env.LUMA_WORKSPACE_SCREENSHOT||'/tmp/luma-workspace-open.png',fullPage:true});
const textBefore=await reader.locator('#luma-content').innerText();
await ai.getByRole('button',{name:'折叠 AI 助手',exact:true}).click();
ok('AI folds from its header',!await page.locator('#ai').isVisible());
ok('folding returns width to reading',(await page.locator('#book').boundingBox()).width>before.width+300);
ok('reader document survives folding',await reader.locator('#luma-content').innerText()===textBefore);
await page.screenshot({path:process.env.LUMA_COLLAPSED_SCREENSHOT||'/tmp/luma-workspace-collapsed.png',fullPage:true});
await page.getByRole('button',{name:'展开 AI 助手',exact:true}).click();
ok('AI reopens with conversation retained',await ai.locator('.message').count()===2);
await reader.locator('#luma-content').evaluate(el=>el.__identityMarker=crypto.randomUUID());
const markerBefore=await reader.locator('#luma-content').evaluate(el=>el.__identityMarker);
for(let i=0;i<12;i++){
 await ai.getByRole('button',{name:'折叠 AI 助手',exact:true}).click();
 await page.getByRole('button',{name:'展开 AI 助手',exact:true}).click();
 if(await reader.locator('#luma-content').evaluate(el=>el.__identityMarker)!==markerBefore)throw Error('Reader was recreated');
}
ok('12 fold/reopen cycles retain reader DOM and conversation',await ai.locator('.message').count()===2);

const separator=page.getByRole('separator');await separator.focus();await page.keyboard.press('ArrowLeft');
ok('split width can be adjusted',(await page.locator('#ai').boundingBox()).width>side.width);
// New messages animate once; retained messages must preserve DOM identity and the reading position.
await ai.locator('.message.assistant').evaluate(el=>el.__motionMarker='retained-answer');
const retained=await page.locator('#ai').evaluate(el=>{
 const w=el.contentWindow;const state=structuredClone(w.__fixture.state);
 state.messages.push({role:'user',text:'另一个问题'},{role:'assistant',text:'补充解释。',providerTitle:'阅读助手'});
 w.__fixture.state=state;w.LumaAI.receive(state);
 return w.document.querySelector('.message.assistant').__motionMarker;
});
ok('message append preserves existing answer nodes',retained==='retained-answer');
await ai.locator('#selection-detail summary').click();
await page.locator('#ai').evaluate(el=>{
 const w=el.contentWindow;w.__fixture.state.reduceVisualEffects=true;w.__fixture.state.glassEnabled=false;
 w.LumaAI.receive(structuredClone(w.__fixture.state));
});
ok('energy saving immediately settles running web animations',await page.locator('#ai').evaluate(el=>el.contentWindow.document.getAnimations().length===0));
ok('energy saving removes chrome blur',await ai.locator('header').evaluate(el=>getComputedStyle(el).backdropFilter==='none'));
await page.locator('#ai').evaluate(el=>{
 const w=el.contentWindow;w.__fixture.state.reduceVisualEffects=false;w.__fixture.state.glassEnabled=true;
 w.LumaAI.receive(structuredClone(w.__fixture.state));
});
ok('glass preference restores chrome material',await ai.locator('header').evaluate(el=>getComputedStyle(el).backdropFilter.includes('blur')));
ok('no JavaScript exceptions',errors.length===0);console.log(JSON.stringify({checks:checks.length,passed:checks,errors,screenshot:process.env.LUMA_AI_SCREENSHOT||'/tmp/luma-ai-ui.png'},null,2));
}finally{if(browser)await browser.close();server.close()}})().catch(e=>{console.error(e);process.exit(1)});
