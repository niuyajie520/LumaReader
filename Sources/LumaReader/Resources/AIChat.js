(()=>{'use strict';const $=id=>document.getElementById(id);let state={},messageSignature='',quoteSignature='';
const tr=text=>{const source=String(text||'');if(state.language!=='en')return source;const c=window.LumaStrings||{};if(c[source])return c[source];for(const key of Object.keys(c))if(key.endsWith('：')&&source.startsWith(key))return c[key]+source.slice(key.length);return source;};
const staticText=[],staticAttrs=[];
const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let textNode;
while(textNode=walker.nextNode()){if(!textNode.parentElement.closest('script,style,.message,#book-title,#chapter,#quote,#selection-preview,#selection-full,#model,#image-name')){const original=textNode.nodeValue;if(original.trim())staticText.push([textNode,original]);}}
for(const el of document.querySelectorAll('[aria-label],[title],[placeholder]'))for(const attr of ['aria-label','title','placeholder'])if(el.hasAttribute(attr)&&!(['pin','expand','send'].includes(el.id)&&attr!=='placeholder'))staticAttrs.push([el,attr,el.getAttribute(attr)]);
function localizeUI(){document.documentElement.lang=state.language==='en'?'en':'zh-Hans';for(const [node,original]of staticText){const key=original.trim(),value=original.replace(key,tr(key));if(node.nodeValue!==value)node.nodeValue=value;}for(const [el,attr,original]of staticAttrs)el.setAttribute(attr,tr(original));}
const compactQuote=value=>{const text=String(value||'').replace(/\s+/gu,' ').trim();const chars=globalThis.Intl?.Segmenter?[...new Intl.Segmenter('zh',{granularity:'grapheme'}).segment(text)].map(x=>x.segment):Array.from(text);return chars.length>28?chars.slice(0,12).join('')+'…'+chars.slice(-12).join(''):text};
const post=(action,extra={})=>window.webkit?.messageHandlers?.lumaAI?.postMessage({action,...extra});
const icon=()=>{const s=document.createElementNS('http://www.w3.org/2000/svg','svg'),u=document.createElementNS(s.namespaceURI,'use');u.setAttribute('href','#sparkles');s.append(u);return s};
const disclosures=new WeakMap();
const reduced=()=>state.reduceVisualEffects||matchMedia('(prefers-reduced-motion: reduce)').matches;
function messageEntrance(element){
 if(reduced()||!element.animate)return;
 element.animate(state.softMotion?[{opacity:0},{opacity:1}]:[{opacity:0,transform:'translateY(7px)'},{opacity:1,transform:'translateY(0)'}],{duration:state.softMotion?120:200,easing:'cubic-bezier(.22,1,.36,1)'});
}
function settleDisclosure(details){
 const state=disclosures.get(details);if(state){state.animation.cancel();details.open=state.open;disclosures.delete(details)}
 details.style.height='';details.style.overflow='';
}
for(const details of [$('reading'),$('selection-detail')]){
 details.querySelector('summary').addEventListener('click',event=>{
  event.preventDefault();const previous=disclosures.get(details);const open=previous?!previous.open:!details.open;
  const from=details.getBoundingClientRect().height;
  if(previous){previous.animation.cancel();disclosures.delete(details)}
  details.style.height='';details.style.overflow='';
  if(document.documentElement.dataset.reduceVisualEffects==='true'||matchMedia('(prefers-reduced-motion: reduce)').matches||!details.animate){details.open=open;return}
  details.open=open;const to=details.getBoundingClientRect().height;details.open=true;details.style.overflow='hidden';
  const animation=details.animate([{height:from+'px'},{height:to+'px'}],{duration:open?220:170,easing:'cubic-bezier(.22,1,.36,1)',fill:'both'});
  disclosures.set(details,{animation,open});
  animation.finished.then(()=>{if(disclosures.get(details)?.animation!==animation)return;disclosures.delete(details);details.open=open;animation.cancel();details.style.height='';details.style.overflow=''}).catch(()=>{});
 });
}
$('pin').addEventListener('click',()=>post('pin'));$('expand').addEventListener('click',()=>post('expand'));
// Native hosts stay alive; retain a text-coordinate scroll anchor across reflow.
const messageList=$('messages');let scrollAnchor=null,restoringScroll=false,scrollFrame=0,composing=false,manualComposer=0,composerDrag=null,composerHydrated=false;
function rememberScroll(){
 if(restoringScroll)return;
 const box=messageList.getBoundingClientRect();
 const follow=messageList.scrollHeight-messageList.scrollTop-messageList.clientHeight<60;
 const nodes=[...messageList.querySelectorAll('.message:not(.pending-user)')];
 const node=nodes.find(n=>n.getBoundingClientRect().bottom>box.top+4);
 if(!node){scrollAnchor={follow,top:messageList.scrollTop};return;}
 const p=node.querySelector('p');let offset=null,dy=node.getBoundingClientRect().top-box.top;
 const caret=document.caretRangeFromPoint?.(box.left+24,box.top+12);
 if(caret&&p?.contains(caret.startContainer)&&caret.startContainer.nodeType===3){offset=caret.startOffset;const r=caret.cloneRange();r.setEnd(caret.startContainer,Math.min(caret.startContainer.length,offset+1));dy=r.getBoundingClientRect().top-box.top;}
 scrollAnchor={follow,index:nodes.indexOf(node),offset,dy,top:messageList.scrollTop};
}
function restoreScroll(){
 if(!scrollAnchor)return;restoringScroll=true;
 const selected=String(getSelection()?.toString()||'').trim();
 if(scrollAnchor.follow&&!selected){messageList.scrollTop=messageList.scrollHeight;}
 else {
 const node=messageList.querySelectorAll('.message:not(.pending-user)')[scrollAnchor.index];
 if(node){const p=node.querySelector('p');let top=node.getBoundingClientRect().top;
 if(scrollAnchor.offset!==null&&p?.firstChild?.nodeType===3){const text=p.firstChild,r=document.createRange(),at=Math.min(text.length,scrollAnchor.offset);r.setStart(text,at);r.setEnd(text,Math.min(text.length,at+1));top=r.getBoundingClientRect().top;}
 messageList.scrollTop+=top-messageList.getBoundingClientRect().top-scrollAnchor.dy;
 }else messageList.scrollTop=scrollAnchor.top||0;
 }
 requestAnimationFrame(()=>{restoringScroll=false;});
}
messageList.addEventListener('scroll',()=>{if(!restoringScroll)rememberScroll();},{passive:true});
const resizeObserver=new ResizeObserver(()=>{cancelAnimationFrame(scrollFrame);scrollFrame=requestAnimationFrame(restoreScroll);});resizeObserver.observe(messageList);
const draft=$('draft');
function sizeComposer(){
 const limit=Math.max(66,Math.min(360,innerHeight*.42));
 rememberScroll();
 if(manualComposer){draft.style.height=Math.min(limit,Math.max(66,manualComposer))+'px';}
 else {draft.style.height='66px';draft.style.height=Math.min(limit,Math.max(66,draft.scrollHeight))+'px';}
 draft.style.overflowY='auto';restoreScroll();
}
const grip=document.createElement('div');grip.id='composer-resize';grip.setAttribute('role','separator');grip.setAttribute('aria-label','调整输入框高度');grip.tabIndex=0;grip.title='拖动调整高度，双击恢复自动高度';draft.before(grip);
grip.addEventListener('pointerdown',event=>{event.preventDefault();composerDrag={y:event.clientY,height:draft.getBoundingClientRect().height};grip.setPointerCapture(event.pointerId);});
grip.addEventListener('pointermove',event=>{if(!composerDrag)return;manualComposer=Math.max(66,Math.min(360,innerHeight*.42,composerDrag.height+composerDrag.y-event.clientY));sizeComposer();});
function finishComposer(){if(!composerDrag)return;composerDrag=null;post('composerHeight',{value:manualComposer});}
grip.addEventListener('pointerup',finishComposer);grip.addEventListener('pointercancel',finishComposer);
grip.addEventListener('dblclick',()=>{manualComposer=0;post('composerHeight',{value:0});sizeComposer();});
grip.addEventListener('keydown',event=>{if(event.key==='ArrowUp'||event.key==='ArrowDown'){event.preventDefault();manualComposer=Math.min(360,Math.max(66,draft.clientHeight+(event.key==='ArrowUp'?10:-10)));sizeComposer();post('composerHeight',{value:manualComposer});}});
draft.addEventListener('compositionstart',()=>{composing=true;});draft.addEventListener('compositionend',()=>{composing=false;post('draft',{value:draft.value});sizeComposer();});
window.addEventListener('resize',sizeComposer,{passive:true});
window.LumaAI={receive(next){rememberScroll();const completed=state.isSending&&!next.isSending;state=next;localizeUI();if(!composerHydrated){manualComposer=Math.max(0,Math.min(360,Number(next.composerHeight)||0));composerHydrated=true;}$('pin').setAttribute('aria-pressed',String(!!next.pinned));$('pin').title=tr(next.pinned?'取消固定':'固定 AI 面板');$('expand').title=tr(next.expanded?'还原宽度':'放大宽度');document.documentElement.style.setProperty('--glass-opacity',String(Math.min(.85,Math.max(.05,Number(next.glassOpacity)||.32))));const root=document.documentElement;for(const [key,value]of Object.entries(next.colors||{})){if(root.style.getPropertyValue('--'+key)!==value)root.style.setProperty('--'+key,value)};root.style.colorScheme=next.dark?'dark':'light';root.dataset.reduceVisualEffects=next.reduceVisualEffects?'true':'false';root.dataset.glass=next.glassEnabled?'true':'false';
if(reduced()) { for(const details of [$('reading'),$('selection-detail')])settleDisclosure(details); document.getAnimations().forEach(animation=>animation.cancel()); }
if(!$('provider').options.length)for(const p of next.providers){const option=document.createElement('option');option.value=p.id;option.textContent=p.title;$('provider').append(option)}
for(const p of next.providers){const option=[...$('provider').options].find(o=>o.value===p.id);if(option)option.textContent=tr(p.title)}
$('provider').value=next.provider;$('provider').disabled=next.isSending;$('model').textContent=next.model;
if(!composing&&(document.activeElement!==draft||completed)&&draft.value!==next.draft)draft.value=next.draft;
$('draft').disabled=next.isSending;$('include').checked=next.includeReading;$('include').disabled=next.isSending;
$('reading').hidden=!next.includeReading||!next.context;$('book-title').textContent=next.context?.title||'';$('chapter').textContent=next.context?.chapter||'';$('quote').textContent=next.pendingQuote||'';$('quote').hidden=!next.pendingQuote;$('remove').hidden=!next.pendingQuote;$('remove').disabled=next.isSending;
const quote=next.pendingQuote||'';
$('selection-reference').hidden=!next.includeReading||!quote;
$('selection-preview').textContent=compactQuote(quote);$('selection-full').textContent=quote;
$('clear-selection').disabled=next.isSending;
if(quote!==quoteSignature){settleDisclosure($('selection-detail'));settleDisclosure($('reading'));$('selection-detail').open=false;quoteSignature=quote}
$('image-attachment').hidden=!next.pendingImageName;$('image-name').textContent=next.pendingImageName?tr('已附带图片')+' · '+next.pendingImageName:'';$('remove-image').disabled=next.isSending;
$('new').disabled=next.isSending;$('settings').disabled=next.isSending;$('error').hidden=!next.error;$('error').textContent=tr(next.error||'');
$('send').disabled=!next.isSending&&!next.draft.trim();$('send').classList.toggle('stop',next.isSending);$('send').setAttribute('aria-label',tr(next.isSending?'停止':'发送'));$('send').title=tr(next.isSending?'停止':'发送 · ⌘ Enter');sizeComposer();
const signature=JSON.stringify([next.messages,next.isSending,next.isSending?next.draft:'',next.language]);
if(signature!==messageSignature){
 messageSignature=signature;const main=$('messages');
 const follow=main.scrollHeight-main.scrollTop-main.clientHeight<90;
 if(!next.isSending)main.querySelectorAll('.pending,.message.pending-user').forEach(n=>n.remove());
 $('empty').hidden=next.messages.length>0||next.isSending;
 const nodes=[...main.querySelectorAll('.message')];
 for(let index=0;index<next.messages.length;index++){
  const m=next.messages[index];let div=nodes[index];
  const fresh=!div||div.dataset.role!==m.role;
  if(fresh){if(div)div.remove();div=document.createElement('div');div.dataset.role=m.role;div.className='message '+m.role;
   const who=document.createElement('div');who.className='who';const body=document.createElement('p');div.append(who,body);main.append(div);
  }
  const who=div.querySelector('.who'),author=m.role==='user'?tr('你'):tr(m.providerTitle||'阅读助手');
  if(div.dataset.author!==author){who.replaceChildren();if(m.role!=='user')who.append(icon());who.append(document.createTextNode(author));div.dataset.author=author;}
  const body=div.querySelector('p'),text=(m.imageName?'['+tr('图片')+'：'+m.imageName+']\n':'')+m.text;
  if(body.textContent!==text)body.textContent=text;
  if(fresh)messageEntrance(div);
 }
 nodes.slice(next.messages.length).forEach(n=>n.remove());
 if(next.isSending){let div=main.querySelector('.pending-user');if(!div){div=document.createElement('div');div.className='message user pending-user';main.append(div)}if(div.textContent!==next.draft)div.textContent=next.draft;let pending=main.querySelector('.pending');if(!pending){pending=document.createElement('p');pending.className='pending';main.append(pending)}pending.textContent=tr('正在思考…')}
 restoreScroll();
}
}};
// Error events carry only a fixed category: never exception text, URL, rejection reason or user content.
for(const [event,kind] of [['error','script'],['unhandledrejection','promise'],['securitypolicyviolation','csp']])window.addEventListener(event,()=>{if(state.diagnosticsEnabled)post('diagnostic',{kind})});
$('draft').addEventListener('input',()=>{state.draft=$('draft').value;$('send').disabled=!state.draft.trim();sizeComposer();if(!composing)post('draft',{value:state.draft})});
$('draft').addEventListener('blur',()=>{if(!state.isSending)post('draft',{value:$('draft').value})});
$('provider').addEventListener('change',()=>post('provider',{value:$('provider').value}));$('include').addEventListener('change',()=>post('include',{value:$('include').checked}));
$('send').onclick=()=>post(state.isSending?'stop':'send',{value:$('draft').value});$('new').onclick=()=>post('new');$('collapse').onclick=()=>post('collapse');$('settings').onclick=()=>post('settings');$('remove').onclick=()=>post('removeQuote');$('remove-image').onclick=()=>post('removeImage');$('clear-selection').onclick=()=>post('removeQuote');
for(const [id,text]of [['explain','请解释这段话，并结合当前书籍说明。'],['example','请用一个生活中的例子解释当前阅读内容。']])$(id).onclick=()=>{draft.value=tr(text);state.draft=tr(text);sizeComposer();post('draft',{value:tr(text)});draft.focus()};
document.addEventListener('keydown',e=>{if((e.metaKey||e.ctrlKey)&&e.key==='Enter'&&!e.isComposing&&!composing&&!state.isSending){e.preventDefault();post('send',{value:$('draft').value})} });
matchMedia('(prefers-reduced-motion: reduce)').addEventListener('change',event=>{
 if(event.matches){for(const details of [$('reading'),$('selection-detail')])settleDisclosure(details);document.getAnimations().forEach(animation=>animation.cancel())}
});sizeComposer();rememberScroll();post('ready');})();
