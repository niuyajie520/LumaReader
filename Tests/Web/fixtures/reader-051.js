(() => {
  'use strict';
  const root = document.getElementById('luma-content') || document.body;
  let savedSelection = null, lastSelectionKey = '', lastRender = '', lastSettings = '';
  let indexed = null, annotations = [], selectionPending = false;
  const customHighlights = !!(globalThis.CSS?.highlights && globalThis.Highlight);
  const palette = {
    paper: ['#FAF8F3','#24221F','#36332F','#DFDBD3'],
    mint: ['#F3F7F0','#1C2620','#303C32','#DCE7DC'],
    rose: ['#FCF4F7','#2B2026','#45333C','#F0DCE7'],
    midnight: ['#151D2C','#151D2C','#DDE5F4','#DDE5F4'],
    black: ['#000000','#000000','#DEDEDE','#DEDEDE']
  };
  const fonts = {
    serif: "'New York','Iowan Old Style','Songti SC',serif",
    sans: "-apple-system,'SF Pro Text','PingFang SC','Hiragino Sans GB',sans-serif",
    rounded: "ui-rounded,'SF Pro Rounded','PingFang SC',sans-serif",
    mono: "ui-monospace,'SF Mono','Menlo','PingFang SC',monospace"
  };
  function nodes() {
    if (indexed) return indexed;
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: n => n.parentElement.closest('script,style,noscript') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
    });
    indexed = []; let node, at = 0;
    while ((node = walker.nextNode())) { indexed.push({node,start:at,end:at+node.length}); at += node.length; }
    return indexed;
  }
  function pointOffset(node, offset) {
    if (node.nodeType === Node.TEXT_NODE) {
      const item = nodes().find(item=>item.node===node);
      if (item) return item.start+offset;
    }
    const range=document.createRange();range.selectNodeContents(root);range.setEnd(node,offset);
    const fragment=range.cloneContents();fragment.querySelectorAll('script,style,noscript').forEach(n=>n.remove());
    return fragment.textContent.length;
  }
  function capture() {
    const selection=getSelection();
    if (!selection||selection.isCollapsed||!selection.rangeCount) return null;
    const r=selection.getRangeAt(0);
    if (!root.contains(r.startContainer)||!root.contains(r.endContainer)) return null;
    return {start:pointOffset(r.startContainer,r.startOffset),end:pointOffset(r.endContainer,r.endOffset),quote:selection.toString()};
  }
  function send(value) {
    if (window.webkit?.messageHandlers?.reader) window.webkit.messageHandlers.reader.postMessage(value);
    else window.dispatchEvent(new CustomEvent('luma-reader',{detail:value}));
  }
  // Microtask coalescing has no repeating timer and sends only changed selections.
  document.addEventListener('selectionchange',()=>{
    if (selectionPending||document.hidden) return;
    selectionPending=true;
    queueMicrotask(()=>{
      selectionPending=false;
      const value=capture();
      const key=value ? value.start+':'+value.end : '';
      if (key===lastSelectionKey) return;
      lastSelectionKey=key;
      if (value&&value.quote.trim()) {savedSelection=value;send({type:'selection',...value});}
      else {savedSelection=null;send({type:'selectionCleared'});}
    });
  });
  function endpoint(at, end=false) {
    const list=nodes(); let lo=0, hi=list.length;
    while(lo<hi){const mid=(lo+hi)>>1;if(list[mid].end<at||(!end&&list[mid].end===at))lo=mid+1;else hi=mid;}
    const item=list[lo]||list[list.length-1];
    return item ? {node:item.node,offset:Math.min(item.node.length,Math.max(0,at-item.start))} : null;
  }
  function rangeFor(note) {
    const a=endpoint(note.start),b=endpoint(note.end,true);
    if(!a||!b) return null;
    const r=document.createRange();r.setStart(a.node,a.offset);r.setEnd(b.node,b.offset);return r;
  }
  const style=document.createElement('style');document.head.append(style);
  function render(notes) {
    const signature=JSON.stringify(notes);
    if(signature===lastRender) return false;
    lastRender=signature;
    hideDeleteButton();
    annotations=notes.filter(n=>Number.isInteger(n.start)&&Number.isInteger(n.end)&&n.end>n.start&&/^#[0-9a-f]{6}$/i.test(n.color));
    if(customHighlights){
      // Paint ranges without splitting or replacing the chapter DOM.
      for(const key of [...CSS.highlights.keys()])if(key.startsWith('luma-')&&!key.startsWith('luma-search'))CSS.highlights.delete(key);
      const groups=new Map();
      for(const note of annotations){const range=rangeFor(note);if(!range)continue;const key='luma-'+note.color.slice(1).toLowerCase();if(!groups.has(key))groups.set(key,[]);groups.get(key).push(range);}
      style.textContent=[...groups.keys()].map(key=>`::highlight(${key}){background-color:#${key.slice(5)}66;color:inherit}`).join('');
      for(const [key,ranges]of groups)CSS.highlights.set(key,new Highlight(...ranges));
      if(searchQuery)paintSearch();
      return true;
    }
    // Compatibility path for older WebKit; only executed when annotation geometry changes.
    root.querySelectorAll('mark[data-luma-note]').forEach(mark=>mark.replaceWith(...mark.childNodes));
    root.normalize();indexed=null;
    for(const item of [...nodes()].reverse()){
      const hits=annotations.filter(n=>n.end>item.start&&n.start<item.end);
      if(!hits.length)continue;
      const cuts=new Set([0,item.node.length]);
      for(const n of hits){cuts.add(Math.max(0,n.start-item.start));cuts.add(Math.min(item.node.length,n.end-item.start));}
      const boundaries=[...cuts].sort((a,b)=>a-b),fragment=document.createDocumentFragment();
      for(let i=0;i<boundaries.length-1;i++){
        const a=boundaries[i],b=boundaries[i+1],text=item.node.data.slice(a,b);
        const hit=[...hits].reverse().find(n=>n.start<=item.start+a&&n.end>=item.start+b);
        if(hit){const mark=document.createElement('mark');mark.dataset.lumaNote=hit.id;mark.style.backgroundColor=hit.color+'66';mark.style.color='inherit';mark.textContent=text;fragment.append(mark);}
        else fragment.append(document.createTextNode(text));
      }
      item.node.replaceWith(fragment);
    }
    indexed=null;if(searchQuery)paintSearch();return true;
  }
  let deleteButton = null, hoveredNote = null, hoverCorridor = null;
  function hideDeleteButton() {
    if(deleteButton)deleteButton.hidden=true;
    hoveredNote=null;hoverCorridor=null;
  }
  function noteAtPoint(x,y) {
    const caret=document.caretRangeFromPoint?.(x,y);
    if(!caret||!root.contains(caret.startContainer))return null;
    const at=pointOffset(caret.startContainer,caret.startOffset);
    return [...annotations].reverse().find(note=>{
      if(at<note.start||at>note.end)return false;
      const range=rangeFor(note);
      return range && [...range.getClientRects()].some(r=>x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom);
    });
  }
  function showDeleteButton(note,x,y) {
    if(hoveredNote?.id===note.id && deleteButton && !deleteButton.hidden)return;
    if(!deleteButton){
      deleteButton=document.createElement('button');
      deleteButton.className='luma-delete-note';
      deleteButton.type='button';deleteButton.textContent='删除';
      deleteButton.setAttribute('aria-label','删除此划线与批注');
      deleteButton.title='删除此划线与批注 · ⌘Z 撤销';
      deleteButton.addEventListener('pointerdown',event=>event.preventDefault());
      deleteButton.addEventListener('click',event=>{
        event.stopPropagation();const note=hoveredNote;hideDeleteButton();
        if(note)send({type:'deleteNote',id:note.id});
      });
      deleteButton.addEventListener('pointerleave',hideDeleteButton);
      document.body.append(deleteButton);
    }
    hoveredNote=note;deleteButton.hidden=false;
    const range=rangeFor(note),rect=range?.getClientRects()[0];
    deleteButton.style.left=Math.max(8,Math.min(innerWidth-64,x+12))+'px';
    deleteButton.style.top=Math.max(8,Math.min(innerHeight-40,(rect ? Math.max(y,rect.top):y)+18))+'px';
    const buttonRect=deleteButton.getBoundingClientRect();
    hoverCorridor={left:Math.min(x,buttonRect.left)-10,right:Math.max(x,buttonRect.right)+10,top:Math.min(y,buttonRect.top)-10,bottom:Math.max(y,buttonRect.bottom)+10};
  }
  document.addEventListener('pointermove',event=>{
    if(event.target===deleteButton)return;
    if(!getSelection().isCollapsed){hideDeleteButton();return;}
    const note=noteAtPoint(event.clientX,event.clientY);
    if(note)showDeleteButton(note,event.clientX,event.clientY);
    else if(!hoverCorridor || event.clientX<hoverCorridor.left || event.clientX>hoverCorridor.right || event.clientY<hoverCorridor.top || event.clientY>hoverCorridor.bottom)hideDeleteButton();
  },{passive:true});
  window.addEventListener('blur',hideDeleteButton);
  window.addEventListener('scroll',hideDeleteButton,{passive:true});
  root.addEventListener('click',event=>{
    const mark=event.target.closest('[data-luma-note]');
    if(mark){send({type:'note',id:mark.dataset.lumaNote});return;}
    if(!customHighlights||!getSelection().isCollapsed)return;
    const range=document.caretRangeFromPoint?.(event.clientX,event.clientY);
    if(!range||!root.contains(range.startContainer))return;
    const at=pointOffset(range.startContainer,range.startOffset);
    const note=[...annotations].reverse().find(n=>n.start<=at&&n.end>at);
    if(note)send({type:'note',id:note.id});
  });
  let searchQuery='',searchOccurrence=-1,searchRanges=[];
  const searchStyle=document.createElement('style');
  searchStyle.textContent='::highlight(luma-search){background:#e9be4266;color:inherit}::highlight(luma-search-active){background:#4986d9aa;color:inherit}';
  document.head.append(searchStyle);
  const searchOverlay=document.createElement('div');searchOverlay.className='luma-search-overlay';document.body.append(searchOverlay);
  function paintSearch(){
    searchRanges=[];searchOverlay.replaceChildren();
    if(customHighlights){CSS.highlights.delete('luma-search');CSS.highlights.delete('luma-search-active');}
    if(!searchQuery)return;
    const text=nodes().map(item=>item.node.data).join('');
    const escaped=searchQuery.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
    const expression=new RegExp(escaped,'giu');
    let match;
    while((match=expression.exec(text))&&searchRanges.length<1000){
      const range=rangeFor({start:match.index,end:match.index+match[0].length});if(range)searchRanges.push(range);
    }
    if(customHighlights){
      CSS.highlights.set('luma-search',new Highlight(...searchRanges));
      const active=searchRanges[searchOccurrence];if(active)CSS.highlights.set('luma-search-active',new Highlight(active));
    }else{
      searchRanges.forEach((range,index)=>{
        for(const rect of range.getClientRects()){
          if(rect.right<=0||rect.left>=innerWidth||rect.bottom<=0||rect.top>=innerHeight)continue;
          const box=document.createElement('i');box.style.cssText=`position:fixed;left:${rect.left}px;top:${rect.top}px;width:${rect.width}px;height:${rect.height}px;background:${index===searchOccurrence?'#4986d988':'#e9be4266'};border-radius:2px;pointer-events:none;`;
          searchOverlay.append(box);
        }
      });
    }
  }
  function searchBook(query,occurrence=-1){
    searchQuery=String(query||'');searchOccurrence=occurrence;paintSearch();
    const range=searchRanges[occurrence];
    if(range){
      const rect=range.getClientRects()[0];
      if(rect&&paged){
        const at=Math.max(0,Math.floor((rect.left-root.getBoundingClientRect().left)/Math.max(1,pagePitch)));
        pageIndex=Math.floor(at/pageColumns)*pageColumns;paintPage();
      }else if(rect)window.scrollBy(0,rect.top-innerHeight/2);
    }
    return searchRanges.length;
  }
  const paged=!!document.getElementById('luma-viewport');
  let pageIndex=0,pageCount=1,pageColumns=1,pagePitch=0,paginationPending=false;
  const numbers=document.getElementById('luma-page-numbers');
  function pageState(){
    return {index:pageIndex,count:pageCount,columns:pageColumns,canBack:pageIndex>0,
      canForward:pageIndex+pageColumns<pageCount,offset:pageIndex/Math.max(1,Math.floor((pageCount-1)/pageColumns)*pageColumns)};
  }
  function paintPage(){
    if(!paged)return;
    root.style.transform=`translate3d(${-pageIndex*pagePitch}px,0,0)`;
    if(numbers){
      numbers.replaceChildren();
      for(let i=0;i<pageColumns&&pageIndex+i<pageCount;i++){
        const number=document.createElement('span');number.textContent=String(pageIndex+i+1);
        number.style.left=(root.offsetLeft+i*pagePitch+(pagePitch-parseFloat(getComputedStyle(root).columnGap))/2)+'px';
        numbers.append(number);
      }
    }
    if(searchQuery)paintSearch();
    send({type:'pagination',...pageState()});
  }
  function measurePages(offset=null){
    if(!paged)return;
    const fraction=offset===null?pageState().offset:offset;
    root.style.transform='none';
    const style=getComputedStyle(root),gap=parseFloat(style.columnGap)||0;
    pageColumns=Math.max(1,parseInt(style.columnCount)||1);
    pagePitch=(root.clientWidth+gap)/pageColumns;
    const range=document.createRange();range.selectNodeContents(root);
    const left=root.getBoundingClientRect().left;
    const last=[...range.getClientRects()].reduce((end,rect)=>Math.max(end,rect.right),left);
    pageCount=Math.max(1,Math.ceil((last-left+gap-1)/Math.max(1,pagePitch)));
    const lastSpread=Math.floor((pageCount-1)/pageColumns)*pageColumns;
    pageIndex=Math.min(lastSpread,Math.max(0,Math.round(fraction*lastSpread/pageColumns)*pageColumns));
    paintPage();
  }
  function turnPage(direction){
    if(!paged)return false;
    const next=pageIndex+(direction<0?-pageColumns:pageColumns);
    if(next<0||next>=pageCount)return false;
    hideDeleteButton();pageIndex=next;paintPage();return true;
  }
  function restorePosition(offset){
    const bounded=Math.max(0,Math.min(1,Number(offset)||0));
    if(paged){measurePages(bounded);if(document.fonts?.status!=='loaded')document.fonts?.ready.then(()=>measurePages());}
    else{const apply=()=>window.scrollTo(0,Math.max(0,document.documentElement.scrollHeight-innerHeight)*bounded);apply();document.fonts?.ready.then(apply);}
  }
  function jumpToNote(id){
    const note=annotations.find(n=>n.id===id);if(!note)return;
    const range=rangeFor(note);if(!range)return;
    if(paged){
      const rect=range.getClientRects()[0];if(!rect)return;
      const at=Math.max(0,Math.floor((rect.left-root.getBoundingClientRect().left)/Math.max(1,pagePitch)));
      pageIndex=Math.floor(at/pageColumns)*pageColumns;paintPage();
    }else{const rect=range.getBoundingClientRect();window.scrollBy(0,rect.top-innerHeight/2);}
  }
  let scrollTimer;
  if(!paged)window.addEventListener('scroll',()=>{
    clearTimeout(scrollTimer);
    scrollTimer=setTimeout(()=>{
      const span=Math.max(1,document.documentElement.scrollHeight-innerHeight);
      send({type:'location',offset:Math.min(1,Math.max(0,scrollY/span))});
    },250);
  },{passive:true});
  if(paged){
    window.addEventListener('resize',()=>{
      if(paginationPending)return;paginationPending=true;
      requestAnimationFrame(()=>{paginationPending=false;hideDeleteButton();measurePages();});
    });
    document.addEventListener('keydown',event=>{
      if(event.metaKey||event.ctrlKey||event.altKey||event.target.closest('input,textarea,[contenteditable]'))return;
      if(event.key==='ArrowRight'||event.key==='ArrowLeft'){
        event.preventDefault();send({type:'turn',delta:event.key==='ArrowLeft'?-1:1});
      }
    });
    let wheelAmount=0,lastWheelTurn=0;
    window.addEventListener('wheel',event=>{
      if(event.ctrlKey)return;
      const now=performance.now();if(now-lastWheelTurn<450)return;
      wheelAmount+=Math.abs(event.deltaX)>Math.abs(event.deltaY)?event.deltaX:event.deltaY;
      if(Math.abs(wheelAmount)>70){send({type:'turn',delta:wheelAmount<0?-1:1});wheelAmount=0;lastWheelTurn=now;}
    },{passive:true});
    for(const [side,delta]of [['previous',-1],['next',1]]){
      const button=document.createElement('button');button.className='luma-page-edge '+side;
      button.type='button';button.setAttribute('aria-label',delta<0?'上一页':'下一页');button.textContent=delta<0?'‹':'›';
      button.addEventListener('click',()=>send({type:'turn',delta}));document.body.append(button);
    }
  }
  window.Luma={
    search:searchBook,
    dismissHover:hideDeleteButton,
    turn:turnPage,
    pageState,
    preparePresentation:token=>{
      let timeout;
      const ready=Promise.allSettled([document.fonts?.ready,...[...document.images].map(image=>image.complete ? Promise.resolve():new Promise(resolve=>{image.addEventListener('load',resolve,{once:true});image.addEventListener('error',resolve,{once:true});}))]);
      return Promise.race([ready,new Promise(resolve=>{timeout=setTimeout(resolve,800);})]).then(()=>{
        clearTimeout(timeout);
        if(paged)measurePages();
        return new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>{send({type:'painted',token});resolve();})));
      });
    },
    restore:restorePosition,
    render,
    clear:()=>{savedSelection=null;lastSelectionKey='';getSelection().removeAllRanges();send({type:'selectionCleared'});},
    capture:()=>capture()||savedSelection,
    selected:()=>{const value=capture()||savedSelection;if(value)send({type:'highlight',...value});},
    jump:jumpToNote,
    settings:(size,width,dark,theme='paper',font='serif')=>{
      const key=[size,width,dark,theme,font].join(':');if(key===lastSettings)return false;lastSettings=key;
      const html=document.documentElement,p=palette[theme]||palette.paper;
      const isDark=dark||theme==='black'||theme==='midnight';
      html.style.setProperty('--reader-size',size+'px');html.style.setProperty('--reader-width',width+'px');
      html.style.setProperty('--reader-font',fonts[font]||fonts.serif);
      html.style.setProperty('--paper',p[isDark?1:0]);html.style.setProperty('--text',p[isDark?3:2]);
      html.classList.toggle('reader-dark',isDark);html.style.colorScheme=isDark?'dark':'light';if(paged)measurePages();return true;
    },
    diagnostics:()=>({customHighlights,textNodeCount:nodes().length,annotationCount:annotations.length})
  };
  send({type:'ready'});
})();
