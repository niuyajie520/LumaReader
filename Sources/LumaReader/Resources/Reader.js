(() => {
  'use strict';
  const root = document.getElementById('luma-content') || document.body;
  let interfaceLanguage='zh-Hans';
  const readerLabels={'标注操作':'Annotation actions','问 AI':'Ask AI','删除此划线与批注':'Delete highlight and note','上一页':'Previous page','下一页':'Next page'};
  const uiText=label=>interfaceLanguage==='en'?(readerLabels[label]||label):label;
  function localizeReader(language){
    interfaceLanguage=language||'zh-Hans';
    // Only labels on app-owned controls; never touch the book's DOM or annotations.
    for(const element of document.querySelectorAll('.luma-note-actions,.luma-note-actions button,.luma-page-edge')){
      for(const attr of ['aria-label','title']){
        const original=element.dataset['lumaOriginal'+(attr==='title'?'Title':'Label')]||element.getAttribute(attr);
        if(!original)continue;element.dataset['lumaOriginal'+(attr==='title'?'Title':'Label')]=original;element.setAttribute(attr,uiText(original));
      }
    }
  }
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
      // Native palette/menu focus must not discard the user's range.
      // Empty selections are cleared by an explicit click in the book, Escape, or a page turn.
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
  let deleteButton = null, noteActions = null, hoveredNote = null, hoverCorridor = null;
  function hideDeleteButton() {
    if(noteActions)noteActions.hidden=true;
    hoveredNote=null;hoverCorridor=null;
  }
  function noteAtPoint(x,y) {
    const caret=document.caretRangeFromPoint?.(x,y);
    if(!caret||!root.contains(caret.startContainer))return null;
    const at=pointOffset(caret.startContainer,caret.startOffset);
    return [...annotations].reverse().find(note=>{
      if(at<note.start||at>=note.end)return false;
      return [...(rangeFor(note)?.getClientRects()||[])].some(r=>x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom);
    });
  }
  function actionButton(symbol,label,action,className){
    const button=document.createElement('button');button.type='button';button.className=className;
    button.dataset.lumaOriginalLabel=label;button.dataset.lumaOriginalTitle=label;button.setAttribute('aria-label',uiText(label));button.title=uiText(label);
    const svg=document.createElementNS('http://www.w3.org/2000/svg','svg');svg.setAttribute('viewBox','0 0 24 24');svg.setAttribute('aria-hidden','true');
    const path=document.createElementNS(svg.namespaceURI,'path');path.setAttribute('d',symbol);svg.append(path);button.append(svg);
    button.addEventListener('pointerdown',event=>event.preventDefault());
    button.addEventListener('click',event=>{event.stopPropagation();const note=hoveredNote;if(note)action(note);hideDeleteButton()});return button;
  }
  function showDeleteButton(note,x,y) {
    if(hoveredNote?.id===note.id && noteActions && !noteActions.hidden)return;
    if(!noteActions){
      noteActions=document.createElement('div');noteActions.className='luma-note-actions';noteActions.setAttribute('role','group');noteActions.dataset.lumaOriginalLabel='标注操作';noteActions.setAttribute('aria-label',uiText('标注操作'));
      const ai=actionButton('M12 3 14.5 9.5 21 12 14.5 14.5 12 21 9.5 14.5 3 12 9.5 9.5Z M20 2v4m-2-2h4','问 AI',note=>{const quote=rangeFor(note)?.toString()||'';if(quote)send({type:'askAI',quote})},'luma-note-ai');
      deleteButton=actionButton('M4 6h16M9 6V3h6v3M6 6l1 15h10l1-15M10 10v7m4-7v7','删除此划线与批注',note=>send({type:'deleteNote',id:note.id}),'luma-delete-note');
      noteActions.append(ai,deleteButton);document.body.append(noteActions);
      noteActions.addEventListener('pointerleave',event=>{const r=noteActions.getBoundingClientRect();if(event.clientX<r.left-14||event.clientX>r.right+14||event.clientY<r.top-14||event.clientY>r.bottom+14)hideDeleteButton()});
    }
    hoveredNote=note;noteActions.hidden=false;
    const rect=[...(rangeFor(note)?.getClientRects()||[])].find(r=>x>=r.left&&x<=r.right&&y>=r.top&&y<=r.bottom);
    const size=noteActions.getBoundingClientRect();
    noteActions.style.left=Math.max(8,Math.min(innerWidth-size.width-8,x-size.width/2))+'px';
    const below=(rect?rect.bottom:y)+8,above=(rect?rect.top:y)-size.height-8;
    noteActions.style.top=(above>=8 ? above:Math.max(8,Math.min(innerHeight-size.height-8,below)))+'px';
    const bounds=noteActions.getBoundingClientRect();
    hoverCorridor={left:Math.min(x,bounds.left)-16,right:Math.max(x,bounds.right)+16,top:Math.min(y,bounds.top)-16,bottom:Math.max(y,bounds.bottom)+16};
  }
  document.addEventListener('pointermove',event=>{
    if(noteActions?.contains(event.target))return;
    if(!getSelection().isCollapsed){hideDeleteButton();return;}
    const note=noteAtPoint(event.clientX,event.clientY);
    if(note)showDeleteButton(note,event.clientX,event.clientY);
    else if(!hoverCorridor || event.clientX<hoverCorridor.left || event.clientX>hoverCorridor.right || event.clientY<hoverCorridor.top || event.clientY>hoverCorridor.bottom)hideDeleteButton();
  },{passive:true});
  window.addEventListener('blur',hideDeleteButton);
  window.addEventListener('scroll',hideDeleteButton,{passive:true});
  root.addEventListener('pointerup',event=>{
    if(event.button!==0)return;
    requestAnimationFrame(()=>{if(!capture()){savedSelection=null;lastSelectionKey='';send({type:'selectionCleared'})}});
  });
  document.addEventListener('keydown',event=>{if(event.key==='Escape'){savedSelection=null;lastSelectionKey='';getSelection().removeAllRanges();hideDeleteButton();send({type:'selectionCleared'})}});
  root.addEventListener('click',event=>{
    const image=event.target.closest('img,svg');
    if(image){
      if(image.tagName.toLowerCase()==='img'&&!/\.svg(?:[?#]|$)|^data:image\/svg\+xml/i.test(image.currentSrc||image.src)){event.preventDefault();send({type:'image',source:image.currentSrc||image.src,alt:image.alt||''});return;}
      const rect=image.getBoundingClientRect();event.preventDefault();send({type:'illustration',x:rect.x,y:rect.y,width:rect.width,height:rect.height});return;
    }
    const note=noteAtPoint(event.clientX,event.clientY);
    if(note&&getSelection().isCollapsed)showDeleteButton(note,event.clientX,event.clientY);
  });
  document.addEventListener('contextmenu',event=>{
    if(!root.contains(event.target))return;
    const note=noteAtPoint(event.clientX,event.clientY);
    const value=note?{start:note.start,end:note.end,quote:rangeFor(note)?.toString()||''}:(capture()||savedSelection);
    if(!value||!value.quote.trim())return;
    event.preventDefault();savedSelection=value;
    send({type:'contextMenu',...value,noteID:note?.id,x:event.clientX,y:event.clientY});
  });
  let blankPointer=null;
  root.addEventListener('pointerdown',event=>{
    if(event.button!==0)return;
    blankPointer={x:event.clientX,y:event.clientY,hadSelection:!!(capture()||savedSelection),target:event.target};
  });
  root.addEventListener('pointerup',event=>{
    const down=blankPointer;blankPointer=null;
    if(event.button!==0||!down)return;
    const moved=Math.hypot(event.clientX-down.x,event.clientY-down.y);
    if(moved>5||down.hadSelection||capture()?.quote.trim())return;
    if(event.target.closest('a,img,svg,button,input,textarea,[data-luma-note]')||noteAtPoint(event.clientX,event.clientY))return;
    send({type:'readerBlankClicked'});
  });
  function readingContext(){
    const selected=capture()||savedSelection;
    const viewport=document.getElementById('luma-viewport')?.getBoundingClientRect()||{left:0,right:innerWidth,top:0,bottom:innerHeight};
    const offsets=[];
    for(let row=0;row<12;row++){
      const y=viewport.top+8+(viewport.bottom-viewport.top-16)*row/11;
      for(let column=0;column<8;column++){
        const x=viewport.left+16+(viewport.right-viewport.left-32)*column/7;
        const caret=document.caretRangeFromPoint?.(x,y);
        if(caret&&root.contains(caret.startContainer)){
          const rect=caret.getBoundingClientRect();
          if(rect.height>0&&rect.left>=viewport.left-2&&rect.right<=viewport.right+2&&rect.bottom>viewport.top&&rect.top<viewport.bottom)
            offsets.push(pointOffset(caret.startContainer,caret.startOffset));
        }
      }
    }
    let visibleText='';
    if(offsets.length){const range=rangeFor({start:Math.min(...offsets),end:Math.max(...offsets)});visibleText=range?.toString().slice(0,6000)||'';}
    return {selection:(selected?.quote||'').slice(0,4000),visibleText};
  }
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
    const next=String(query||'');const changed=next!==searchQuery||occurrence!==searchOccurrence;
    searchQuery=next;searchOccurrence=occurrence;if(changed)paintSearch();
    const range=searchRanges[occurrence];
    if(range){
      const rect=range.getClientRects()[0];
      if(rect&&paged){
        const at=Math.max(0,Math.floor((rect.left-root.getBoundingClientRect().left)/Math.max(1,pagePitch)));
        const target=Math.floor(at/pageColumns)*pageColumns;if(target!==pageIndex){pageIndex=target;paintPage();}
      }else if(rect)window.scrollBy(0,rect.top-innerHeight/2);
    }
    return searchRanges.length;
  }
  const paged=!!document.getElementById('luma-viewport');
  let pageIndex=0,pageCount=1,pageColumns=1,pagePitch=0,pageGap=0,paginationPending=false;
  let frozenGeometry=null,viewportTransaction=null,viewportEpoch=0,committingViewport=false,deferredSettings=null;
  let fontEpoch=0,imageEpoch=0,cacheHits=0;
  const layoutCache=new Map(),layoutLog=[];
  function traceLayout(event,extra={}){layoutLog.push({event,at:Math.round(performance.now()),epoch:viewportEpoch,width:innerWidth,height:innerHeight,...extra});if(layoutLog.length>120)layoutLog.shift();}
  function snapshotStyles(element,properties){return properties.map(key=>[key,element.style.getPropertyValue(key),element.style.getPropertyPriority(key)]);}
  function restoreStyles(element,rows){for(const [key,value,priority]of rows){if(value)element.style.setProperty(key,value,priority);else element.style.removeProperty(key);}}
  function beginLayoutTransaction(token){
    viewportTransaction=token;viewportEpoch++;hideDeleteButton();
    if(!frozenGeometry){
      stableAnchor=visibleAnchor()||stableAnchor;
      const viewport=document.getElementById('luma-viewport'),rect=viewport.getBoundingClientRect(),style=getComputedStyle(root);
      frozenGeometry={viewport,viewportStyle:snapshotStyles(viewport,['width','height','left','top','bottom','transform']),rootStyle:snapshotStyles(root,['width','height','column-count','column-gap'])};
      for(const [key,value]of Object.entries({width:rect.width+'px',height:rect.height+'px',left:rect.left+'px',top:rect.top+'px',bottom:'auto',transform:'none'}))viewport.style.setProperty(key,value,'important');
      for(const [key,value]of Object.entries({width:root.clientWidth+'px',height:root.clientHeight+'px','column-count':style.columnCount,'column-gap':style.columnGap}))root.style.setProperty(key,value,'important');
    }
    viewportChanging=true;traceLayout('begin',{token,columns:pageColumns,pitch:pagePitch});
  }
  async function commitLayoutTransaction(token){
    if(token!==viewportTransaction){traceLayout('stale-end',{token});return false;}
    const epoch=viewportEpoch;
    if(document.fonts?.status==='loading')await document.fonts.ready;
    await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
    if(epoch!==viewportEpoch||token!==viewportTransaction){traceLayout('cancelled-end',{token});return false;}
    const frozen=frozenGeometry;frozenGeometry=null;
    if(frozen){restoreStyles(frozen.viewport,frozen.viewportStyle);restoreStyles(root,frozen.rootStyle);}
    committingViewport=true;
    if(deferredSettings){const apply=deferredSettings;deferredSettings=null;apply();}
    layoutDirty=true;measurePages();committingViewport=false;viewportChanging=false;viewportTransaction=null;
    traceLayout('commit',{token,columns:pageColumns,pitch:pagePitch,index:pageIndex,count:pageCount});
    send({type:'viewportSettled',token,epoch});return true;
  }
  let layoutDirty=true,lastTypography='',footerPositions=[],stableAnchor=null,viewportChanging=false;
  let layoutMeasures=0,headingStarts=[],visibleTextStart=null,visibleTextEnd=null;
  function chapterText(){return nodes().map(item=>item.node.data).join('');}
  function makeAnchor(at){
    const text=chapterText();if(!text.length)return null;
    const start=Math.max(0,Math.min(text.length-1,Math.trunc(at)));
    return {version:1,start,quote:text.slice(start,start+64),prefix:text.slice(Math.max(0,start-24),start)};
  }
  function resolveAnchor(anchor){
    if(!anchor||anchor.version!==1||!Number.isInteger(anchor.start)||typeof anchor.quote!=='string'||!anchor.quote)return null;
    const text=chapterText();if(!text.length)return null;
    if(anchor.start>=0&&text.slice(anchor.start,anchor.start+anchor.quote.length)===anchor.quote)return anchor.start;
    // Check context before relocating a quote; ambiguous edited content uses the legacy fraction.
    const matches=[];let at=text.indexOf(anchor.quote);
    while(at>=0&&matches.length<100){
      if(!anchor.prefix||text.slice(Math.max(0,at-anchor.prefix.length),at)===anchor.prefix)matches.push(at);
      at=text.indexOf(anchor.quote,at+1);
    }
    return matches.length===1 ? matches[0]:null;
  }
  function characterRect(at){
    const textLength=nodes().at(-1)?.end||0;
    if(!textLength)return null;
    for(let shift=0;shift<32;shift++){
      const n=Math.min(textLength-1,at+shift),r=rangeFor({start:n,end:n+1});
      const rect=r&&[...r.getClientRects()].find(rect=>rect.height>0);
      if(rect)return rect;
    }
    return null;
  }
  function columnAt(at){
    const rect=characterRect(at);if(!rect)return 0;
    return Math.max(0,Math.floor((rect.left-root.getBoundingClientRect().left+0.5)/Math.max(1,pagePitch)));
  }
  function visibleAnchor(){
    const length=nodes().at(-1)?.end||0;if(!length)return null;
    if(paged){
      let low=0,high=length-1;
      while(low<high){const mid=(low+high)>>1;if(columnAt(mid)<pageIndex)low=mid+1;else high=mid;}
      const column=columnAt(low);
      return column>=pageIndex&&column<pageIndex+pageColumns ? makeAnchor(low):null;
    }
    const view=root.getBoundingClientRect();
    for(let row=0;row<8;row++){
      const caret=document.caretRangeFromPoint?.(Math.max(16,view.left+8),16+row*12);
      if(caret&&root.contains(caret.startContainer))return makeAnchor(pointOffset(caret.startContainer,caret.startOffset));
    }
    return null;
  }
  function activeHeading(){
    const at=stableAnchor?.start??0;
    return headingStarts.filter(h=>h.start<=at).at(-1)||null;
  }
  function restoreAnchorPage(anchor){
    const at=resolveAnchor(anchor);if(at===null)return false;
    const lastSpread=Math.floor((pageCount-1)/pageColumns)*pageColumns;
    pageIndex=Math.min(lastSpread,Math.floor(columnAt(at)/pageColumns)*pageColumns);
    stableAnchor=makeAnchor(at);return true;
  }
  const numbers=document.getElementById('luma-page-numbers');
  function pageState(){
    return {index:pageIndex,count:pageCount,columns:pageColumns,canBack:pageIndex>0,
      canForward:pageIndex+pageColumns<pageCount,offset:pageIndex/Math.max(1,Math.floor((pageCount-1)/pageColumns)*pageColumns),
      anchor:stableAnchor,textStart:visibleTextStart,textEnd:visibleTextEnd,headingIndex:activeHeading()?.index??-1,headingID:activeHeading()?.id||''};
  }
  function paintPage(preserveAnchor=false){
    if(!paged)return;
    document.getElementById('luma-note-focus')?.remove();
    root.style.transform=`translate3d(${-pageIndex*pagePitch}px,0,0)`;
    if(numbers){
      while(numbers.children.length<pageColumns)numbers.append(document.createElement('span'));
      while(numbers.children.length>pageColumns)numbers.lastElementChild.remove();
      for(let i=0;i<pageColumns;i++){
        const number=numbers.children[i];number.hidden=pageIndex+i>=pageCount;
        const label=String(pageIndex+i+1);if(number.textContent!==label)number.textContent=label;
        const left=footerPositions[i]+'px';if(number.style.left!==left)number.style.left=left;
      }
    }
    const firstVisible=visibleAnchor();
    visibleTextStart=firstVisible?.start??null;visibleTextEnd=nextSpreadOffset();
    if(!preserveAnchor)stableAnchor=firstVisible;
    if(searchQuery)paintSearch();
    send({type:'pagination',...pageState()});
  }
  function measurePages(offset=null,anchor=null){
    if(!paged||viewportChanging&&!committingViewport)return;
    const keep=anchor||(offset===null?stableAnchor:null);
    const fraction=offset===null?pageState().offset:offset;
    if(!layoutDirty&&offset===null)return;
    if(layoutDirty){
      layoutMeasures++;root.style.transform='none';
      const style=getComputedStyle(root);pageGap=parseFloat(style.columnGap)||0;
      pageColumns=Math.max(1,parseInt(style.columnCount)||1);
      pagePitch=(root.clientWidth+pageGap)/pageColumns;
      const key=JSON.stringify([root.clientWidth,root.clientHeight,innerHeight,pageColumns,pageGap,lastTypography,fontEpoch,imageEpoch]);
      const reusable=document.fonts?.status!=='loading'&&[...document.images].every(image=>image.complete);
      const cached=reusable?layoutCache.get(key):null;
      if(cached){pageCount=cached;cacheHits++;}
      else {
        const range=document.createRange();range.selectNodeContents(root);
        const left=root.getBoundingClientRect().left;
        const last=[...range.getClientRects()].reduce((end,rect)=>Math.max(end,rect.right),left);
        pageCount=Math.max(1,Math.ceil((last-left+pageGap-1)/Math.max(1,pagePitch)));
        if(reusable){layoutCache.set(key,pageCount);if(layoutCache.size>8)layoutCache.delete(layoutCache.keys().next().value);}
      }
      const origin=root.getBoundingClientRect().left;
      footerPositions=Array.from({length:pageColumns},(_,i)=>origin+i*pagePitch+(pagePitch-pageGap)/2);
      headingStarts=[...root.querySelectorAll('h1,h2,h3,h4,h5,h6')].map((h,index)=>({index,id:h.id,start:nodes().find(n=>h.contains(n.node))?.start??0}));
      layoutDirty=false;
    }
    const lastSpread=Math.floor((pageCount-1)/pageColumns)*pageColumns;
    if(!keep||!restoreAnchorPage(keep)){
      pageIndex=Math.min(lastSpread,Math.max(0,Math.round(fraction*lastSpread/pageColumns)*pageColumns));
      paintPage();
    }else{paintPage(true);}
  }
  function turnPage(direction){
    if(!paged)return false;
    const next=pageIndex+(direction<0?-pageColumns:pageColumns);
    if(next<0||next>=pageCount)return false;
    hideDeleteButton();savedSelection=null;lastSelectionKey='';getSelection().removeAllRanges();pageIndex=next;paintPage();return true;
  }
  // A drag keeps its original UTF-16 anchor across CSS-column spreads.
  // No whole-paragraph inference: the user chooses the exact endpoint.
  let selectionDrag=null, selectionEdgeTimer=null;
  function cancelSelectionEdge(){clearTimeout(selectionEdgeTimer);selectionEdgeTimer=null;}
  function nextSpreadOffset(){
    let low=0,high=nodes().at(-1)?.end||0;
    while(low<high){const mid=(low+high)>>1;if(columnAt(mid)<pageIndex+pageColumns)low=mid+1;else high=mid;}
    return low;
  }
  document.addEventListener('pointerdown',event=>{
    cancelSelectionEdge();selectionDrag=null;
    if(event.button===0&&root.contains(event.target))selectionDrag={anchor:null,extended:false};
  });
  document.addEventListener('pointermove',event=>{
    if(!selectionDrag||!(event.buttons&1)||!paged)return;
    const selection=getSelection();
    if(!selection?.rangeCount||selection.isCollapsed)return;
    if(selectionDrag.anchor===null)selectionDrag.anchor=pointOffset(selection.anchorNode,selection.anchorOffset);
    if(selectionDrag.extended){
      const caret=document.caretRangeFromPoint?.(event.clientX,event.clientY);
      const anchor=endpoint(selectionDrag.anchor);
      if(caret&&anchor&&root.contains(caret.startContainer)){
        event.preventDefault();selection.setBaseAndExtent(anchor.node,anchor.offset,caret.startContainer,caret.startOffset);
      }
    }
    const next=nextSpreadOffset(),focus=pointOffset(selection.focusNode,selection.focusOffset);
    const forward=focus>=selectionDrag.anchor;
    if(!forward||pageIndex+pageColumns>=pageCount||focus<next-2){cancelSelectionEdge();return;}
    if(selectionEdgeTimer)return;
    selectionEdgeTimer=setTimeout(()=>{
      selectionEdgeTimer=null;if(!selectionDrag)return;
      const a=endpoint(selectionDrag.anchor),b=endpoint(next);
      if(!a||!b)return;
      pageIndex+=pageColumns;paintPage(true);selectionDrag.extended=true;
      selection.setBaseAndExtent(a.node,a.offset,b.node,b.offset);
    },450);
  },{passive:false});
  document.addEventListener('pointerup',()=>{cancelSelectionEdge();selectionDrag=null;});
  document.addEventListener('pointercancel',()=>{cancelSelectionEdge();selectionDrag=null;});
  window.addEventListener('blur',()=>{cancelSelectionEdge();selectionDrag=null;});
  function restorePosition(offset,anchor=null){
    const bounded=Math.max(0,Math.min(1,Number(offset)||0));
    if(paged){measurePages(bounded,anchor);if(document.fonts?.status!=='loaded')document.fonts?.ready.then(()=>{fontEpoch++;layoutCache.clear();layoutDirty=true;if(!viewportChanging)measurePages();});}
    else{
      const apply=()=>{const at=resolveAnchor(anchor);const rect=at===null?null:characterRect(at);if(rect){window.scrollBy(0,rect.top-16);stableAnchor=makeAnchor(at);}else{window.scrollTo(0,Math.max(0,document.documentElement.scrollHeight-innerHeight)*bounded);stableAnchor=visibleAnchor();}};
      apply();document.fonts?.ready.then(()=>{if(anchor&&stableAnchor?.start===anchor.start)apply();});
    }
  }
  function jumpToNote(id){
    const note=annotations.find(n=>n.id===id);if(!note)return;
    const range=rangeFor(note);if(!range)return;
    if(paged){
      const rect=range.getClientRects()[0];if(!rect)return;
      const at=Math.max(0,Math.floor((rect.left-root.getBoundingClientRect().left)/Math.max(1,pagePitch)));
      const target=Math.floor(at/pageColumns)*pageColumns;pageIndex=target;stableAnchor=makeAnchor(note.start);paintPage(true);
    }else{const rect=range.getBoundingClientRect();window.scrollBy(0,rect.top-innerHeight/2);}
    showNoteFocus(range);

  }
  let focusTimer;
  function showNoteFocus(range){
    document.getElementById('luma-note-focus')?.remove();clearTimeout(focusTimer);
    const layer=document.createElement('div');layer.id='luma-note-focus';layer.setAttribute('aria-hidden','true');
    const viewport=document.getElementById('luma-viewport')?.getBoundingClientRect()||{left:0,right:innerWidth,top:0,bottom:innerHeight};
    for(const rect of range.getClientRects()){
      if(rect.right<=viewport.left||rect.left>=viewport.right||rect.bottom<=viewport.top||rect.top>=viewport.bottom)continue;
      const mark=document.createElement('i');Object.assign(mark.style,{left:Math.max(viewport.left,rect.left)+'px',top:Math.max(viewport.top,rect.top)+'px',width:(Math.min(viewport.right,rect.right)-Math.max(viewport.left,rect.left))+'px',height:(Math.min(viewport.bottom,rect.bottom)-Math.max(viewport.top,rect.top))+'px'});layer.append(mark);
    }
    document.body.append(layer);focusTimer=setTimeout(()=>layer.remove(),1300);
  }
  let scrollTimer;
  if(!paged)window.addEventListener('scroll',()=>{
    clearTimeout(scrollTimer);
    scrollTimer=setTimeout(()=>{
      const span=Math.max(1,document.documentElement.scrollHeight-innerHeight);
      stableAnchor=visibleAnchor();send({type:'location',offset:Math.min(1,Math.max(0,scrollY/span)),anchor:stableAnchor});
    },250);
  },{passive:true});
  if(paged){
    root.addEventListener('load',event=>{if(event.target.tagName==='IMG'){imageEpoch++;layoutCache.clear();layoutDirty=true;if(!viewportChanging)measurePages();}},{capture:true,passive:true});
    document.fonts?.addEventListener('loadingdone',()=>{fontEpoch++;layoutCache.clear();layoutDirty=true;if(!viewportChanging)measurePages();});
    window.addEventListener('resize',()=>{
      if(paginationPending)return;paginationPending=true;
      requestAnimationFrame(()=>{paginationPending=false;layoutDirty=true;hideDeleteButton();if(!viewportChanging)measurePages();});
    });
    document.addEventListener('keydown',event=>{
      if(event.metaKey||event.ctrlKey||event.altKey||event.target.closest('input,textarea,[contenteditable]'))return;
      if(event.key==='ArrowRight'||event.key==='ArrowLeft'){
        event.preventDefault();send({type:'turn',delta:event.key==='ArrowLeft'?-1:1});
      }
    });
    // Browser fallback: latch through the entire event stream, including inertia.
    // macOS PagedWebView consumes native wheel events using NSEvent phases instead.
    let wheelAmount=0,wheelTurned=false,lastWheelEvent=null;
    window.addEventListener('wheel',event=>{
      if(event.ctrlKey)return;
      const now=performance.now();
      if(lastWheelEvent===null||now-lastWheelEvent>350){wheelAmount=0;wheelTurned=false;}
      lastWheelEvent=now;
      if(wheelTurned)return;
      let delta=Math.abs(event.deltaX)>Math.abs(event.deltaY)?event.deltaX:event.deltaY;
      if(event.deltaMode===1)delta*=16;
      else if(event.deltaMode===2)delta*=innerHeight;
      wheelAmount+=delta;
      if(Math.abs(wheelAmount)>=100){wheelTurned=true;send({type:'turn',delta:wheelAmount<0?-1:1});}
    },{passive:true});
    for(const [side,delta]of [['previous',-1],['next',1]]){
      const button=document.createElement('button');button.className='luma-page-edge '+side;
      button.type='button';button.setAttribute('aria-label',delta<0?'上一页':'下一页');button.textContent=delta<0?'‹':'›';
      button.addEventListener('click',()=>send({type:'turn',delta}));document.body.append(button);
    }
  }
  window.Luma={
    readingContext,
    search:searchBook,
    dismissHover:hideDeleteButton,
    turn:turnPage,
    pageState,
    textAnchor:()=>stableAnchor||visibleAnchor(),
    beginViewportChange:token=>beginLayoutTransaction(token),
    endViewportChange:token=>commitLayoutTransaction(token),
    preparePresentation:token=>{
      let timeout;
      const pendingLayout=document.fonts?.status==='loading'||[...document.images].some(image=>!image.complete);
      const ready=Promise.allSettled([document.fonts?.ready,...[...document.images].map(image=>image.complete ? Promise.resolve():new Promise(resolve=>{image.addEventListener('load',resolve,{once:true});image.addEventListener('error',resolve,{once:true});}))]);
      return Promise.race([ready,new Promise(resolve=>{timeout=setTimeout(resolve,800);})]).then(()=>{
        clearTimeout(timeout);
        if(paged){if(pendingLayout)layoutDirty=true;measurePages();}
        return new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(()=>{send({type:'painted',token});resolve();})));
      });
    },
    restore:restorePosition,
    render,
    clear:()=>{savedSelection=null;lastSelectionKey='';getSelection().removeAllRanges();send({type:'selectionCleared'});},
    capture:()=>capture()||savedSelection,
    selected:()=>{const value=capture()||savedSelection;if(value)send({type:'highlight',...value});},
    jump:jumpToNote,
    jumpToHeading:({fragment='',headingIndex=-1}={})=>{
      const target=(fragment ? document.getElementById(fragment)||document.getElementsByName(fragment)[0]:null) || root.querySelectorAll('h1,h2,h3,h4,h5,h6')[headingIndex];
      if(!target || !root.contains(target))return false;
      if(paged){
        measurePages();const rect=target.getBoundingClientRect();
        const at=Math.max(0,Math.floor((rect.left-root.getBoundingClientRect().left)/Math.max(1,pagePitch)));
        pageIndex=Math.min(Math.floor(at/pageColumns)*pageColumns,Math.floor((pageCount-1)/pageColumns)*pageColumns);stableAnchor=makeAnchor(nodes().find(n=>target.contains(n.node))?.start??nodes().find(n=>target.compareDocumentPosition(n.node)&Node.DOCUMENT_POSITION_FOLLOWING)?.start??0);paintPage(true);
      }else{target.scrollIntoView({block:'start',behavior:'instant'});}
      return true;
    },
    settings:(size,width,dark,theme='paper',font='serif',options=null)=>{
      if(viewportChanging&&!committingViewport){deferredSettings=()=>window.Luma.settings(size,width,dark,theme,font,options);return false;}
      localizeReader(options?.language);
      const key=JSON.stringify([size,width,dark,theme,font,options]);if(key===lastSettings)return false;lastSettings=key;
      const typography=JSON.stringify([size,width,font,options?.lineHeight,options?.paragraphSpacing,options?.indent,options?.customFontKey]);const typographyChanged=typography!==lastTypography;
      if(typographyChanged){layoutDirty=true;lastTypography=typography;hideDeleteButton();}
      const html=document.documentElement,p=palette[theme]||palette.paper;
      const isDark=options?.colors ? dark : dark||theme==='black'||theme==='midnight';
      if(typographyChanged){
        html.style.setProperty('--reader-size',size+'px');html.style.setProperty('--reader-width',width+'px');
        let face=document.getElementById('luma-custom-font');
        if(!face){face=document.createElement('style');face.id='luma-custom-font';document.head.append(face);}
        if(face.textContent!==(options?.customFontCSS||''))face.textContent=options?.customFontCSS||'';
        html.dataset.customFont=options?.customFontCSS ? 'true':'false';
        html.style.setProperty('--reader-font',(options?.customFontCSS ? 'LumaImported,':'')+(fonts[font]||fonts.serif));
        html.style.setProperty('--reader-leading',Math.min(2.6,Math.max(1.2,Number(options?.lineHeight)||1.75)));
        html.style.setProperty('--reader-paragraph',Math.min(2.5,Math.max(0,Number(options?.paragraphSpacing ?? 1.35)))+'em');
        html.style.setProperty('--reader-indent',options?.indent ? '2em':'0');
      }
      html.style.setProperty('--paper',options?.colors?.paper || p[isDark?1:0]);html.style.setProperty('--text',options?.colors?.ink || p[isDark?3:2]);
      html.dataset.focus=options?.focus ? 'true':'false';
      html.classList.toggle('reader-dark',isDark);html.style.colorScheme=isDark?'dark':'light';if(paged&&!viewportChanging)measurePages();return true;
    },
    diagnostics:()=>({customHighlights,textNodeCount:nodes().length,annotationCount:annotations.length,layoutMeasures,viewportChanging,viewportEpoch,cacheHits,cacheEntries:layoutCache.size,layoutLog:[...layoutLog]})
  };
  send({type:'ready'});
})();
