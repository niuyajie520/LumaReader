(() => {
  const required = ['collapse','pin','expand','new','settings','provider','model','messages','draft','include','send'];
  const missingNodes = required.filter(id => !document.getElementById(id)).length;
  const symbols = document.querySelector('.symbols');
  const stylesReady = !!symbols && getComputedStyle(symbols).display === 'none';
  const width = document.documentElement.clientWidth;
  const layoutReady = width > 0 && document.documentElement.clientHeight > 0;
  const oversizedIcons = layoutReady ? [...document.querySelectorAll('header svg,footer svg,#empty svg')].filter(el => {
    if (el.closest('[hidden]')) return false;
    const box = el.getBoundingClientRect();
    return box.width > 96 || box.height > 96;
  }).length : 0;
  return {bridgeReady:Number(typeof window.LumaAI?.receive === 'function'),stylesReady:Number(stylesReady),
    missingNodes,oversizedIcons,overflow:Number(layoutReady && document.body.scrollWidth > width + 2),layoutReady:Number(layoutReady)};
})()
