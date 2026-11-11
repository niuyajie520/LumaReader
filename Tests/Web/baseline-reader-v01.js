(() => {
  'use strict';
  const root = document.getElementById('luma-content') || document.body;
  let savedSelection = null;
  function nodes() {
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
      acceptNode: n => n.parentElement.closest('script,style,noscript') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT
    });
    const result = []; let node; let at = 0;
    while ((node = walker.nextNode())) { result.push({node, start: at, end: at + node.length}); at += node.length; }
    return result;
  }
  function pointOffset(node, offset) {
    const range = document.createRange(); range.selectNodeContents(root); range.setEnd(node, offset);
    const fragment = range.cloneContents();
    fragment.querySelectorAll('script,style,noscript').forEach(n => n.remove());
    return fragment.textContent.length;
  }
  function capture() {
    const selection = getSelection();
    if (!selection || selection.isCollapsed || !selection.rangeCount) return null;
    const range = selection.getRangeAt(0);
    if (!root.contains(range.startContainer) || !root.contains(range.endContainer)) return null;
    return { start: pointOffset(range.startContainer, range.startOffset), end: pointOffset(range.endContainer, range.endOffset), quote: selection.toString() };
  }
  function send(value) {
    if (window.webkit?.messageHandlers?.reader) window.webkit.messageHandlers.reader.postMessage(value);
    else window.dispatchEvent(new CustomEvent('luma-reader', {detail: value}));
  }
  document.addEventListener('selectionchange', () => {
    const value = capture();
    if (value && value.quote.trim()) { savedSelection = value; send({type: 'selection', ...value}); }
    else { savedSelection = null; send({type:'selectionCleared'}); }
  });
  root.addEventListener('click', event => {
    const mark = event.target.closest('[data-luma-note]');
    if (mark) send({type: 'note', id: mark.dataset.lumaNote});
  });
  function render(notes) {
    root.querySelectorAll('mark[data-luma-note]').forEach(mark => mark.replaceWith(...mark.childNodes));
    root.normalize();
    const textNodes = nodes();
    for (const item of [...textNodes].reverse()) {
      const hits = notes.filter(n => n.start != null && n.end > item.start && n.start < item.end);
      if (!hits.length) continue;
      const cuts = new Set([0, item.node.length]);
      for (const note of hits) { cuts.add(Math.max(0, note.start-item.start)); cuts.add(Math.min(item.node.length,note.end-item.start)); }
      const boundaries = [...cuts].sort((a,b)=>a-b), fragment = document.createDocumentFragment();
      for (let i=0; i<boundaries.length-1; i++) {
        const a=boundaries[i], b=boundaries[i+1];
        const text = item.node.data.slice(a,b);
        // Latest overlapping annotation is visible; all records remain in the inspector.
        const hit = [...hits].reverse().find(n=>n.start<=item.start+a && n.end>=item.start+b);
        if (hit) {
          const mark=document.createElement('mark'); mark.dataset.lumaNote=hit.id;
          mark.style.backgroundColor=hit.color+'66'; mark.style.color='inherit';
          mark.style.borderRadius='3px'; mark.textContent=text; fragment.append(mark);
        } else fragment.append(document.createTextNode(text));
      }
      item.node.replaceWith(fragment);
    }
  }
  window.Luma = {
    render,
    clear: () => { savedSelection=null; getSelection().removeAllRanges(); send({type:'selectionCleared'}); },
    capture: () => capture() || savedSelection,
    selected: () => { const value=capture()||savedSelection; if(value) send({type:'highlight',...value}); },
    jump: id => { root.querySelector('[data-luma-note="'+CSS.escape(id)+'"]')?.scrollIntoView({block:'center',behavior:'auto'}); },
    settings: (size,width,dark) => {
      document.documentElement.style.setProperty('--reader-size',size+'px');
      document.documentElement.style.setProperty('--reader-width',width+'px');
      document.documentElement.classList.toggle('reader-dark',dark);
    }
  };
  send({type:'ready'});
})();
