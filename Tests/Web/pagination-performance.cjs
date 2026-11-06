const {chromium}=require('playwright');
const fs=require('node:fs'),path=require('node:path');
const project=path.resolve(__dirname,'../..');
const old=fs.readFileSync(path.join(__dirname,'fixtures/reader-051.js'),'utf8');
const next=fs.readFileSync(path.join(project,'Sources/LumaReader/Resources/Reader.js'),'utf8');
const css=fs.readFileSync(path.join(project,'Sources/LumaReader/Resources/Reader.css'),'utf8');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.LUMA_CHROMIUM||'/tmp/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const results={};
 for(const [label,script]of [['before',old],['after',next]]){
  const runs=[];
  for(let sample=0;sample<3;sample++){
   const page=await browser.newPage({viewport:{width:1280,height:800}});
   await page.setContent('<html data-paged><head></head><body><div id="luma-viewport"><main id="luma-content">'+'<p>阅读与思考。逻辑需要缓慢推敲，每一个段落都能带来新的想法。'.repeat(12)+'</p>'.repeat(0)+'</main></div><div id="luma-page-numbers"></div></body></html>');
   await page.locator('#luma-content').evaluate(root=>root.innerHTML=('<p>'+('阅读与思考。逻辑需要缓慢推敲，每一个段落都能带来新的想法。').repeat(12)+'</p>').repeat(600));
   if(await page.locator('#luma-content p').count()!==600)throw Error('Wrong fixture paragraph count');
   await page.addStyleTag({content:css});await page.addScriptTag({content:script});
   await page.evaluate(()=>{Luma.settings(21,680,true,'black','serif');Luma.restore(0);});
   await page.evaluate(()=>Luma.preparePresentation('warm'));
   const session=await page.context().newCDPSession(page);await session.send('Performance.enable');
   const metrics=async()=>Object.fromEntries((await session.send('Performance.getMetrics')).metrics.map(m=>[m.name,m.value]));
   const before=await metrics();
   await page.evaluate(async()=>{for(let i=0;i<12;i++){if(!Luma.turn(1))throw Error('Not enough pages');await Luma.preparePresentation('turn-'+i);}});
   const after=await metrics();
   if(label==='after'&&after.LayoutCount-before.LayoutCount>24)throw Error('Pagination forces too many layouts');
   runs.push({scriptMs:(after.ScriptDuration-before.ScriptDuration)*1000,layoutMs:(after.LayoutDuration-before.LayoutDuration)*1000,layouts:after.LayoutCount-before.LayoutCount,recalcStyle:after.RecalcStyleCount-before.RecalcStyleCount});
   await page.close();
  }
  results[label]=runs;
 }
 console.log(JSON.stringify({fixture:{paragraphs:600,turnsPerRun:12,runs:3},metrics:results,limits:'Synthetic Chromium profile; excludes macOS WebKit, PDFKit, native animation, energy and battery.'},null,2));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
