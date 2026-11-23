const RESOURCE = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'XS-AirDrops';

const XS = {
    apps: {},
};
window.XS = XS;

XS.esc = function esc(value) {
    if (value === null || value === undefined) return '';
    return String(value).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
};

XS.fix = function fix(value) {
    if (Array.isArray(value)) return value.map(fix);
    if (value && typeof value === 'object') {
        const keys = Object.keys(value);
        if (keys.length === 0) return [];
        const out = {};
        keys.forEach((k) => { out[k] = fix(value[k]); });
        return out;
    }
    return value;
};

XS.list = function list(value) {
    if (Array.isArray(value)) return value;
    if (value && typeof value === 'object') return Object.values(value);
    return [];
};

XS.post = async function post(endpoint, payload) {
    try {
        const res = await fetch(`https://${RESOURCE}/${endpoint}`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload || {}),
        });
        return XS.fix(await res.json());
    } catch (e) {
        return null;
    }
};

XS.rpc = async function rpc(name, payload) {
    const res = await XS.post('rpc', { name, payload: payload || {} });
    if (!res) return { ok: false, error: 'That did not go through.' };
    return res;
};

XS.server = function server(action, payload) {
    return XS.rpc('b:server', { action, payload: payload || {} });
};

XS.close = function close(app) {
    XS.post('close', { app });
};

XS.clock = function clock(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const r = s % 60;
    if (h > 0) return `${h}:${String(m).padStart(2, '0')}:${String(r).padStart(2, '0')}`;
    return `${m}:${String(r).padStart(2, '0')}`;
};

XS.span = function span(seconds) {
    const s = Math.max(0, Math.floor(Number(seconds) || 0));
    if (s < 60) return `${s}s`;
    if (s < 3600) return `${Math.floor(s / 60)}m`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
    return `${Math.floor(s / 86400)}d ${Math.floor((s % 86400) / 3600)}h`;
};

XS.ago = function ago(seconds) {
    const s = Number(seconds);
    if (!Number.isFinite(s) || s < 0) return '—';
    if (s < 60) return 'just now';
    return `${XS.span(s)} ago`;
};

XS.toast = function toast(text, kind) {
    if (!text) return;
    const box = document.getElementById('xsp-toastbox');
    const el = document.createElement('div');
    el.className = `xsp-toast ${kind === 'error' ? 't-err' : (kind === 'ok' ? 't-ok' : '')}`;
    el.textContent = text;
    box.appendChild(el);
    setTimeout(() => el.remove(), 3800);
};

XS.show = function show(id, on) {
    const el = document.getElementById(id);
    if (el) el.classList.toggle('xsp-hidden', !on);
};

function scale() {
    const s = Math.min(window.innerWidth / 1600, window.innerHeight / 900);
    document.documentElement.style.setProperty('--xsp-s', String(s));
}
window.addEventListener('resize', scale);
scale();

window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || typeof msg !== 'object' || !msg.app) return;
    const app = XS.apps[msg.app];
    if (app && app.on) app.on(msg.action, XS.fix(msg.data || {}));
});

window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    const app = XS.apps.builder;
    if (app && app.isOpen && app.isOpen() && app.escape) app.escape();
});

window.addEventListener('load', () => { XS.post('ready', {}); });
