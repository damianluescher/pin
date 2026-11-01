// Runs before Money's own code. Money reads and saves through fetch('/data'); here that is answered from invented.js,
// in memory only. Nothing is written anywhere, nothing goes online, data.json is never read. Reloading resets the board.
(() => {
  const D = window.MONEY_INVENTED, json = (o, status = 200) => new Response(JSON.stringify(o), { status, headers: { 'content-type': 'application/json' } });
  let version = D.version;
  window.fetch = async (url, init = {}) => {
    const path = String(url).split('?')[0], method = init.method || 'GET';
    if (path === '/data' && method === 'GET') return json({ ...D, version });
    if (path === '/data' && method === 'PUT') return json({ version: ++version });
    // Comments and "cancel it" only pretend: no chat, no mail, no browser.
    if (path === '/note' || path === '/cancel') return new Response('Not sent: this is a Pin board.');
    return new Response('A Pin board never goes online', { status: 403 });
  };
  const no = function () { throw new Error('A Pin board never goes online'); };
  window.XMLHttpRequest = window.WebSocket = window.EventSource = no;
  navigator.sendBeacon = () => false;
  // file: pages may refuse address changes. Money's tabs still work, only the address stays.
  const push = history.pushState.bind(history);
  history.pushState = (...a) => { try { push(...a); } catch {} };
  // Boards showing an open sheet: press the real button once the page has drawn.
  addEventListener('load', () => {
    const open = new URLSearchParams(location.search).get('open'), sel = { edit: '[data-edit]', reorder: '[data-reorder]' }[open];
    if (!sel) return;
    let n = 0;
    const t = setInterval(() => { const e = document.querySelector(sel); if (e || ++n > 50) { clearInterval(t); e?.click(); } }, 40);
  });
})();
