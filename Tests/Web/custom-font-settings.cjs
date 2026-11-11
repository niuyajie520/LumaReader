// Execute the real settings handler without a browser. Pagination geometry still requires Web tests on Mac.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(path.resolve(__dirname,'../../Sources/LumaReader/Resources/Reader.js'),'utf8');
const start=source.indexOf('settings:(')+'settings:'.length,end=source.indexOf(',\n    diagnostics:',start);
assert(start>0&&end>start);
const properties=new Map(),sheets=new Map(),classes=new Set();let appended=0,measured=0;
const html={style:{setProperty:(k,v)=>properties.set(k,v)},dataset:{},classList:{toggle:(key,on)=>on?classes.add(key):classes.delete(key)}};
const context={lastSettings:'',lastTypography:'',layoutDirty:false,paged:true,viewportChanging:false,
 palette:{paper:['#fafafa','#222','#222','#eee']},localizeReader(){},fonts:{serif:'serif',sans:'sans-serif'},hideDeleteButton(){},measurePages(){measured++},
 document:{documentElement:html,getElementById:id=>sheets.get(id),createElement:()=>({textContent:''}),head:{append(node){sheets.set(node.id,node);appended++}}}};
const settings=vm.runInNewContext('('+source.slice(start,end)+')',context);
const css="@font-face{font-family:LumaImported;src:url('file:///fixture.ttf');font-display:swap;}";
const options={customFontCSS:css,customFontKey:'fixture',lineHeight:1.75,paragraphSpacing:1.35};
assert.equal(settings(19,680,false,'paper','serif',options),true);
assert.equal(properties.get('--reader-font'),'LumaImported,serif');assert.equal(sheets.get('luma-custom-font').textContent,css);
const sheet=sheets.get('luma-custom-font');
assert.equal(settings(19,680,false,'paper','serif',options),false,'Identical updates do not repaginate');assert.equal(measured,1);
settings(19,680,true,'paper','serif',{...options,colors:{paper:'#151515',ink:'#eeeeee'}});
assert.equal(sheets.get('luma-custom-font'),sheet);assert.equal(appended,1,'Theme updates retain the font style node');
settings(19,680,true,'paper','sans',{customFontCSS:'',customFontKey:''});
assert.equal(properties.get('--reader-font'),'sans-serif');assert.equal(sheet.textContent,'','Built-in selection clears custom font');
assert.equal(appended,1);assert.equal(html.dataset.customFont,'false');
console.log('Custom font settings: PASS (handler unit test, no browser geometry)');
