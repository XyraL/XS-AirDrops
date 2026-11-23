(() => {
    const root = document.getElementById('xsp-builder');
    const esc = XS.esc;
    const I = (name, size) => XS.icon(name, size || 16);
    const copy = (v) => JSON.parse(JSON.stringify(v === undefined ? null : v));
    const fx = (n) => (Number(n) || 0).toFixed(1);
    const num = (v, d) => (Number.isFinite(Number(v)) ? Number(v) : d);

    const ANNOUNCE = {
        inbound: 'Supply drop inbound{near}. It lands in {seconds} seconds.',
        landed: 'The crate has landed{near}.',
        opened: '{name} has opened the crate.',
        emptied: 'The crate has been emptied.',
    };
    const STATE = {
        announced: ['Announced', 'warn', 'Lands in'],
        inbound: ['Plane inbound', 'warn', 'Lands in'],
        landed: ['On the ground', 'bad', 'Gives up in'],
        open: ['Open', 'ok', 'Closes in'],
    };
    const OUTCOME = {
        abandoned: ['Abandoned', 'off'], 'looted out': ['Timed out open', 'warn'], emptied: ['Emptied', 'ok'],
        cancelled: ['Cancelled', 'off'], running: ['Running', 'blue'], ended: ['Ended', 'off'],
    };
    const COMPASS = [['N', 0], ['NE', 315], ['E', 270], ['SE', 225], ['S', 180], ['SW', 135], ['W', 90], ['NW', 45]];
    const CRATE_MODELS = ['prop_mil_crate_01', 'prop_mil_crate_02', 'prop_drop_armscrate_01', 'prop_drop_crate_01', 'prop_box_wood02a_pu', 'ex_prop_adv_case_sm', 'gr_prop_gr_crates_weapon_mix_01a', 'gr_prop_gr_crates_rifles_01a', 'prop_air_cargo_01a', 'prop_cash_crate_01'];
    const PLANES = ['titan', 'cargoplane', 'bombushka', 'cuban800', 'duster', 'mammatus', 'velum', 'velum2', 'nimbus', 'luxor', 'miljet', 'seabreeze', 'alphaz1', 'avenger'];
    const PALETTE = ['#9aa0a8', '#4c9aff', '#c084fc', '#f5a524', '#ff5c64', '#2fcf8a', '#2dd4bf', '#f472b6'];

    const S = {
        open: false, page: 'overview', zones: [], crates: [], loot: [], live: { drops: [], schedule: {}, stats: {} }, system: {}, access: {},
        items: [], itemSet: new Set(), jobs: [], gangs: [], me: {}, here: null,
        cur: null, curId: null, kind: null, tab: 'general', dirty: false, busy: false, keepScroll: false,
        zq: '', zFilter: 'all', zCrate: 0, start: { zone: 0, crate: 0, loot: 0, silent: false },
        history: [], hstats: {}, hOutcome: 'all', hOpen: null, overlay: null, pick: null, roll: null,
    };

    const pageEl = () => root.querySelector('#bx-page');
    const crateById = (id) => S.crates.find((c) => c.id === Number(id));
    const lootById = (id) => S.loot.find((l) => l.id === Number(id));
    const zoneById = (id) => S.zones.find((z) => z.id === Number(id));
    const defaultCrate = () => S.crates.find((c) => c.data.isDefault) || S.crates[0];
    const zoneCrate = (z) => (z.crate && crateById(z.crate)) || defaultCrate();
    const zoneLoot = (z, c) => (z.loot && lootById(z.loot)) || (c && c.data.loot && lootById(c.data.loot)) || S.loot[0];
    const crateLoot = (c) => (c.loot && lootById(c.loot)) || S.loot[0];
    const pt = (p) => (p ? `${fx(p.x)}, ${fx(p.y)}, ${fx(p.z)}` : '—');
    const setting = (key) => (XS.BuilderSettings ? XS.BuilderSettings.saved(key) : undefined);
    const hourName = (n) => (Number(n) < 0 ? 'Any time' : `${String(n).padStart(2, '0')}:00`);

    function percent(v) {
        const n = Number(v) || 0;
        if (n <= 0) return '0%';
        if (n < 0.1) return '<0.1%';
        return `${n >= 10 ? Math.round(n) : n.toFixed(1)}%`;
    }

    function setPath(obj, path, value) {
        const parts = path.split('.');
        let node = obj;
        for (let i = 0; i < parts.length - 1; i++) {
            const k = /^\d+$/.test(parts[i]) ? Number(parts[i]) : parts[i];
            if (node[k] === undefined || node[k] === null || typeof node[k] !== 'object') node[k] = {};
            node = node[k];
        }
        const last = parts[parts.length - 1];
        node[/^\d+$/.test(last) ? Number(last) : last] = value;
    }

    function getPath(obj, path) {
        return path.split('.').reduce((n, k) => (n === undefined || n === null ? undefined : n[/^\d+$/.test(k) ? Number(k) : k]), obj);
    }

    function blankZone() {
        return { label: '', enabled: true, points: [], radius: 0, approx: 0, crate: 0, loot: 0, weight: 5, minPlayers: 0, minPolice: 0, hours: { from: -1, to: -1 }, heading: -1, see: { rule: 'default', jobs: [], gangs: [] }, notes: '' };
    }

    function normZone(d) {
        const out = Object.assign(blankZone(), d || {});
        out.points = XS.list(out.points).map((p) => ({ x: num(p.x, 0), y: num(p.y, 0), z: num(p.z, 0) }));
        out.hours = Object.assign({ from: -1, to: -1 }, (d && d.hours) || {});
        const see = (d && d.see && !Array.isArray(d.see)) ? d.see : {};
        out.see = { rule: ['everyone', 'only', 'except'].includes(see.rule) ? see.rule : 'default', jobs: XS.list(see.jobs), gangs: XS.list(see.gangs) };
        return out;
    }

    function groupNames(jobs, gangs) {
        const names = XS.list(jobs).map((n) => (S.jobs.find((j) => j.name === n) || { label: n }).label)
            .concat(XS.list(gangs).map((n) => (S.gangs.find((g) => g.name === n) || { label: n }).label));
        return names.length > 3 ? `${names.slice(0, 3).join(', ')} +${names.length - 3}` : names.join(', ');
    }

    function seeText(see) {
        const rule = see.rule === 'default' ? (setting('Access.See.Mode') || 'everyone') : see.rule;
        const jobs = see.rule === 'default' ? setting('Access.See.Jobs') : see.jobs;
        const gangs = see.rule === 'default' ? setting('Access.See.Gangs') : see.gangs;
        if (rule === 'only') return `Only ${groupNames(jobs, gangs) || 'nobody'}`;
        if (rule === 'except') return groupNames(jobs, gangs) ? `Hidden from ${groupNames(jobs, gangs)}` : 'Everyone';
        return 'Everyone';
    }

    function blankCrate() {
        return {
            label: '', isDefault: false, model: 'prop_mil_crate_01', crackTime: 25, stacksPerSearch: 2, searchesPerPlayer: 0, slots: 12, maxWeight: 80000, loot: 0,
            access: { rule: 'default', jobs: [], gangs: [], police: 'default' }, flyover: true, parachute: true, flare: true, smoke: true, plane: 'titan', altitude: 320,
            police: { alert: true, delay: 45 }, announce: Object.assign({}, ANNOUNCE), blip: { sprite: 478, colour: 5, label: 'Supply Drop' }, notes: '',
        };
    }

    function normCrate(d) {
        const b = blankCrate();
        const out = Object.assign(b, d || {});
        ['access', 'police', 'announce', 'blip'].forEach((k) => { out[k] = Object.assign(b[k], (d && d[k]) || {}); });
        out.access.jobs = XS.list(out.access.jobs);
        out.access.gangs = XS.list(out.access.gangs);
        return out;
    }

    function blankLoot() {
        return { label: '', minStacks: 4, maxStacks: 7, guarantee: '', tiers: [{ name: 'common', weight: 60, colour: PALETTE[0], enabled: true, items: [] }], notes: '' };
    }

    function normLoot(d) {
        const out = Object.assign(blankLoot(), d || {});
        out.tiers = XS.list(out.tiers).map((t, i) => Object.assign({ name: `tier ${i + 1}`, weight: 10, colour: PALETTE[i % PALETTE.length], enabled: true }, t, {
            items: XS.list(t.items).map((it) => Object.assign({ item: '', min: 1, max: 1, weight: 10, enabled: true }, it)),
        }));
        return out;
    }

    function liveTiers(d) {
        return XS.list(d.tiers).map((t, rank) => ({ t, rank, items: XS.list(t.items).filter((i) => i.enabled !== false && i.item) })).filter((x) => x.t.enabled !== false && x.items.length);
    }

    function lootIssues(d) {
        const list = [];
        const live = liveTiers(d);
        if (!live.length) list.push({ level: 'bad', text: 'Nothing in it is switched on, so crates come up empty' });
        if (d.guarantee && !live.some((x) => x.t.name === d.guarantee)) list.push({ level: 'warn', text: `The guarantee tier "${d.guarantee}" is off or empty` });
        if (S.items.length) {
            const missing = [];
            XS.list(d.tiers).forEach((t) => XS.list(t.items).forEach((it) => { if (it.item && !S.itemSet.has(it.item) && !S.itemSet.has(String(it.item).toLowerCase())) missing.push(it.item); }));
            if (missing.length) list.push({ level: 'warn', text: `${missing.length} item${missing.length === 1 ? ' is' : 's are'} not on this server: ${missing.slice(0, 4).join(', ')}` });
        }
        return list;
    }

    function crateIssues(d) {
        const list = [];
        if (d.loot && !lootById(d.loot)) list.push({ level: 'warn', text: 'Its loot table was deleted, so it uses the first one', tab: 'general' });
        if (d.access.rule === 'groups' && !d.access.jobs.length && !d.access.gangs.length) list.push({ level: 'bad', text: 'Only listed jobs and gangs can open it, and none are listed', tab: 'access' });
        return list;
    }

    function zoneIssues(d) {
        const list = [];
        if (!d.points.length) list.push({ level: 'bad', text: 'No landing point, so it can never get a drop', tab: 'points' });
        if (d.crate && !crateById(d.crate)) list.push({ level: 'warn', text: 'Its crate type was deleted, so it uses the default', tab: 'general' });
        if (d.loot && !lootById(d.loot)) list.push({ level: 'warn', text: 'Its loot table was deleted, so it uses the crate\'s', tab: 'general' });
        const c = zoneCrate(d);
        const l = zoneLoot(d, c);
        if (!c) list.push({ level: 'bad', text: 'There is no crate type to drop here', tab: 'general' });
        if (!l) list.push({ level: 'bad', text: 'There is no loot table to fill it', tab: 'general' });
        else if (!liveTiers(l.data).length) list.push({ level: 'bad', text: `Its loot table "${l.data.label}" is empty`, tab: 'general' });
        if (d.see && d.see.rule === 'only' && !XS.list(d.see.jobs).length && !XS.list(d.see.gangs).length) list.push({ level: 'bad', text: 'Only listed jobs and gangs see it, and none are listed', tab: 'see' });
        if (d.enabled === false) list.push({ level: 'info', text: 'Switched off', tab: 'general' });
        return list;
    }

    const zoneReady = (z) => z.data.enabled !== false && !zoneIssues(z.data).some((i) => i.level === 'bad');

    function allIssues() {
        const out = [];
        if (!S.zones.length) out.push({ level: 'bad', text: 'No drop zones yet', sub: 'Build one standing on the spot', act: 'data-act="new" data-kind="zone"' });
        else if (!S.zones.some((z) => z.data.enabled !== false)) out.push({ level: 'bad', text: 'Every drop zone is switched off', sub: 'Nothing can drop', act: 'data-act="nav" data-page="zones"' });
        S.zones.forEach((z) => zoneIssues(z.data).forEach((i) => { if (i.level !== 'info' || i.text !== 'Switched off') out.push({ level: i.level, text: i.text, sub: `Zone #${z.id} · ${z.data.label}`, act: `data-act="edit" data-kind="zone" data-id="${z.id}" data-tab="${i.tab}"` }); }));
        S.crates.forEach((c) => crateIssues(normCrate(c.data)).forEach((i) => out.push({ level: i.level, text: i.text, sub: `Crate type · ${c.data.label}`, act: `data-act="edit" data-kind="crate" data-id="${c.id}" data-tab="${i.tab}"` })));
        S.loot.forEach((l) => lootIssues(l.data).forEach((i) => out.push({ level: i.level, text: i.text, sub: `Loot table · ${l.data.label}`, act: `data-act="edit" data-kind="loot" data-id="${l.id}"` })));
        if (setting('Schedule.Enabled') === false) out.push({ level: 'info', text: 'Automatic drops are off', sub: 'Only staff can call drops', act: 'data-act="nav" data-page="schedule"' });
        if (!S.system.dispatch) out.push({ level: 'info', text: 'No dispatch script found', sub: 'Police get a plain notification and a blip', act: 'data-act="setting" data-key="Police.Jobs"' });
        if (setting('Drop.OpenWith') === 'target' && !S.system.target) out.push({ level: 'warn', text: 'Crates open with target, but no target script is running', sub: 'Players get the E prompt instead', act: 'data-act="setting" data-key="Drop.OpenWith"' });
        const order = { bad: 0, warn: 1, info: 2 };
        return out.sort((a, b) => order[a.level] - order[b.level]);
    }

    function shell() {
        root.innerHTML = `
<div class="xsp-stage"><div class="bx bx-in">
  <div class="bx-lightbar"></div>
  <div class="bx-top">
    <div class="bx-logo"><svg class="bx-badge" viewBox="0 0 34 34"><defs><linearGradient id="adG" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffb489"/><stop offset="1" stop-color="#e07030"/></linearGradient></defs><rect x="1" y="1" width="32" height="32" rx="9" fill="#140a05" stroke="url(#adG)" stroke-width="1.5"/><path d="M8 15a9 7 0 0 1 18 0" fill="none" stroke="url(#adG)" stroke-width="2" stroke-linecap="round"/><path d="M8 15l6.5 7M26 15l-6.5 7M17 15v7" fill="none" stroke="url(#adG)" stroke-width="1.5" stroke-linecap="round"/><rect x="13" y="21.5" width="8" height="6" rx="1.2" fill="url(#adG)"/></svg>
      <div class="bx-word"><b>XS-<span>AirDrops</span></b><small>Drop builder</small></div></div>
    <button class="bx-search" data-act="palette">${I('search', 15)}<span class="bx-stext">Search zones, crates, loot, settings and pages</span><span class="bx-kbd">Ctrl</span><span class="bx-kbd">K</span></button>
    <span class="bx-sp"></span>
    <div class="bx-sys" id="bx-sys"></div>
    <button class="bx-iconbtn close" data-act="close" title="Esc">${I('close', 16)}</button>
  </div>
  <div class="bx-body">
    <nav class="bx-nav" id="bx-nav"></nav>
    <main class="bx-main"><div class="bx-page xsp-scroll" id="bx-page"></div></main>
  </div>
  <div id="bx-ov"></div>
</div></div>`;
    }

    function navItem(page, icon, label, count, warn) {
        const on = S.page === page || S.page === `${page}-edit` || (page === 'zones' && S.page === 'zone-edit') || (page === 'crates' && S.page === 'crate-edit');
        return `<button class="bx-navitem ${on ? 'on' : ''}" data-act="nav" data-page="${page}">${I(icon, 17)}<span class="bx-navlabel">${esc(label)}</span>${count !== undefined && count !== null ? `<span class="bx-count ${warn ? 'warn' : ''}">${esc(count)}</span>` : ''}</button>`;
    }

    function renderNav() {
        const nav = root.querySelector('#bx-nav');
        if (!nav) return;
        const badZones = S.zones.filter((z) => zoneIssues(z.data).some((i) => i.level === 'bad')).length;
        const badLoot = S.loot.filter((l) => lootIssues(l.data).some((i) => i.level === 'bad')).length;
        const changed = XS.BuilderSettings && XS.BuilderSettings.changedCount ? XS.BuilderSettings.changedCount() : 0;
        const running = XS.list(S.live.drops).length;
        nav.innerHTML = `
<div class="bx-navgroup">Build</div>
${navItem('overview', 'chart', 'Overview')}
${navItem('zones', 'pin', 'Drop zones', S.zones.length, badZones > 0)}
${navItem('crates', 'box', 'Crate types', S.crates.length)}
${navItem('loot', 'stack', 'Loot tables', S.loot.length, badLoot > 0)}
<div class="bx-navsep"></div>
<div class="bx-navgroup">Run</div>
${navItem('schedule', 'clock', 'Schedule', setting('Schedule.Enabled') === false ? 'off' : null, setting('Schedule.Enabled') === false)}
${navItem('live', 'bolt', 'Live', running || null)}
${navItem('history', 'history', 'History')}
<div class="bx-navsep"></div>
<div class="bx-navgroup">Setup</div>
${navItem('settings', 'sliders', 'Settings', changed || null)}
${navItem('access', 'shield', 'Access')}
<div class="bx-me"><div class="bx-avatar">${esc(((S.me && S.me.name) || 'A').slice(0, 1).toUpperCase())}</div><div style="min-width:0"><b>${esc((S.me && S.me.name) || '')}</b><small>Builder access</small></div></div>`;
    }

    function renderSys() {
        const el = root.querySelector('#bx-sys');
        if (!el) return;
        const s = S.system || {};
        const pill = (on, label) => `<span class="bx-pill ${on ? '' : 'off'}"><i></i>${esc(label)}</span>`;
        el.innerHTML = `${pill(!!s.inventory, s.inventory ? `${s.inventory}` : 'No inventory')}${pill(!!s.dispatch, s.dispatch || 'No dispatch')}`;
    }

    function focusKey() {
        const a = document.activeElement;
        if (!a || !root.contains(a) || a === document.body) return null;
        if (a.id) return `#${CSS.escape(a.id)}`;
        const keys = Object.keys(a.dataset);
        if (!keys.length) return null;
        return a.tagName.toLowerCase() + keys.map((k) => `[data-${k.replace(/[A-Z]/g, (m) => `-${m.toLowerCase()}`)}="${CSS.escape(a.dataset[k])}"]`).join('');
    }

    function render() {
        renderNav();
        renderSys();
        const el = pageEl();
        if (!el) return;
        const fkey = focusKey();
        if (XS.BuilderSettings && S.page !== 'settings' && S.page !== 'schedule') XS.BuilderSettings.unmount();
        const pages = {
            overview, zones: zonesPage, 'zone-edit': zoneEditor, crates: cratesPage, 'crate-edit': crateEditor, loot: lootPage, 'loot-edit': lootEditor,
            schedule: schedulePage, live: livePage, history: historyPage, settings: () => '<div id="bx-setmount"></div>', access: accessPage,
        };
        const top = el.scrollTop;
        el.innerHTML = (pages[S.page] || overview)();
        if (S.keepScroll) el.scrollTop = top;
        S.keepScroll = false;
        if (S.page === 'settings') XS.BuilderSettings.mount(el.querySelector('#bx-setmount'), () => renderNav());
        if (S.page === 'schedule') {
            XS.BuilderSettings.mount(el.querySelector('#bx-schedmount'), () => { renderNav(); }, {
                only: ['schedule'],
                onSaved: (d) => { if (d && d.schedule) S.live.schedule = d.schedule; S.keepScroll = true; render(); },
            });
        }
        renderOverlay();
        tick();
        if (fkey && !S.overlay) {
            const n = el.querySelector(fkey);
            if (n && n.focus) {
                n.focus();
                if (n.tagName === 'INPUT' && n.type !== 'number' && n.type !== 'color' && n.setSelectionRange) n.setSelectionRange(n.value.length, n.value.length);
            }
        }
    }

    function head(title, sub, actions, crumb) {
        return `${crumb ? `<div class="bx-crumb">${crumb}</div>` : ''}<div class="bx-pagehead"><div><h1>${esc(title)}</h1>${sub ? `<p>${esc(sub)}</p>` : ''}</div><span class="bx-sp"></span>${actions || ''}</div>`;
    }

    function stat(cls, n, label, sub, icon, act) {
        return `<div class="bx-stat ${cls}" ${act || ''}>${I(icon, 18)}<b>${n}</b><span>${esc(label)}</span>${sub ? `<em>${sub}</em>` : ''}</div>`;
    }

    function countdown(seconds) {
        if (seconds === null || seconds === undefined) return '—';
        return `<time data-until="${Date.now() + Number(seconds) * 1000}">${esc(XS.clock(seconds))}</time>`;
    }

    function tick() {
        root.querySelectorAll('[data-until]').forEach((el) => {
            const left = Math.max(0, Math.round((Number(el.dataset.until) - Date.now()) / 1000));
            el.textContent = XS.clock(left);
        });
    }
    setInterval(() => { if (S.open) tick(); }, 1000);

    function overview() {
        const live = S.live || {};
        const st = live.stats || {};
        const sc = live.schedule || {};
        const enabled = S.zones.filter((z) => z.data.enabled !== false);
        const ready = enabled.length ? Math.round((enabled.filter(zoneReady).length / enabled.length) * 100) : 0;
        const circ = 2 * Math.PI * 50;
        const issues = allIssues();
        const sys = S.system || {};
        const sysRow = (label, value) => `<div class="bx-sysrow"><span>${esc(label)}</span><b class="${value ? '' : 'none'}">${esc(value || 'none')}</b></div>`;
        const abandon = st.total ? Math.round(((st.abandoned || 0) / st.total) * 100) : 0;
        return `${head('Overview', 'Every drop zone, crate type and loot table on the server, and what still needs doing.', `<button class="bx-btn" data-act="quickdrop" data-silent="1">${I('eye', 15)}Silent test drop</button><button class="bx-btn primary" data-act="quickdrop">${I('chute', 15)}Start a drop now</button>`)}
<div class="bx-ov">
  <div class="bx-card"><div class="bx-ready">
    <div class="bx-ring"><svg width="118" height="118"><defs><linearGradient id="bxRingGrad"><stop offset="0" stop-color="#ffb489"/><stop offset="1" stop-color="#e07030"/></linearGradient></defs><circle class="track" cx="59" cy="59" r="50"/><circle class="fill" cx="59" cy="59" r="50" stroke-dasharray="${circ}" stroke-dashoffset="${circ * (1 - ready / 100)}"/></svg><div><b>${ready}%</b><small>ready</small></div></div>
    <div class="bx-readytext"><h2>${esc(S.zones.length ? `${enabled.filter(zoneReady).length} of ${enabled.length} live zones ready` : 'No drop zones yet')}</h2>
      <p>${esc(S.zones.length ? 'Fix the red ones first. Yellow and blue are worth a look.' : 'Go to the spot in game, open the builder and make a zone. One landing point is enough to start.')}</p>
      ${issues.length ? `<div class="bx-issues">${issues.slice(0, 40).map((i) => `<div class="bx-issue ${i.level}" ${i.act} style="cursor:pointer"><i>${I(i.level === 'bad' ? 'alert' : 'info', 13)}</i><div><b>${esc(i.text)}</b><span>${esc(i.sub || '')}</span></div>${I('chevron', 14)}</div>`).join('')}</div>` : `<div class="bx-allgood">${I('check', 16)}Everything is set up.</div>`}
    </div></div></div>
  <div class="bx-stats">
    ${stat('amber', `${XS.list(live.drops).length} / ${sc.max || 1}`, 'Live now', null, 'bolt', 'data-act="nav" data-page="live"')}
    ${stat('', st.today || 0, 'Drops today', null, 'chute', 'data-act="nav" data-page="history"')}
    ${stat('green', st.crackedToday || 0, 'Cracked today', null, 'box', 'data-act="nav" data-page="history"')}
    ${stat('', sc.enabled ? (sc.nextIn !== undefined && sc.nextIn !== null ? countdown(sc.nextIn) : '—') : 'Off', 'Next drop in', sc.enabled ? esc(`${sc.players || 0} on, ${setting('Schedule.MinPlayers') || 0} needed`) : 'Schedule is off', 'clock', 'data-act="nav" data-page="schedule"')}
    ${stat('', `${enabled.filter(zoneReady).length} / ${S.zones.length}`, 'Zones ready', null, 'pin', 'data-act="nav" data-page="zones"')}
    ${stat(abandon > 50 ? 'red' : '', st.total || 0, 'Drops all time', esc(`${abandon}% abandoned`), 'history', 'data-act="nav" data-page="history"')}
  </div>
</div>
<div class="bx-sec"><div class="bx-sectitle"><h2>Start something</h2></div>
  <div class="bx-quick">
    <button class="bx-tpl" data-act="new" data-kind="zone"><span class="bx-kindico">${I('pin', 18)}</span><div><b>New drop zone</b><span>Where crates land. Place points with the freecam or at your feet.</span></div></button>
    <button class="bx-tpl" data-act="new" data-kind="crate"><span class="bx-kindico">${I('box', 18)}</span><div><b>New crate type</b><span>The prop, crack time, who can open it, the plane and the blip.</span></div></button>
    <button class="bx-tpl" data-act="new" data-kind="loot"><span class="bx-kindico">${I('stack', 18)}</span><div><b>New loot table</b><span>Tiers and items with the real odds worked out.</span></div></button>
    <button class="bx-tpl" data-act="nav" data-page="schedule"><span class="bx-kindico">${I('clock', 18)}</span><div><b>Schedule</b><span>How often drops happen, when, and how many at once.</span></div></button>
  </div></div>
<div class="bx-sec"><div class="bx-sectitle"><h2>What XS-AirDrops found</h2></div>
  <div class="bx-sysgrid">${sysRow('Framework', sys.framework)}${sysRow('Inventory', sys.inventory ? `${sys.inventory} · ${sys.shared ? 'shared crate' : 'stacks per search'}` : null)}${sysRow('Dispatch', sys.dispatch || 'plain notification')}${sysRow('Opening', setting('Drop.OpenWith') === 'target' ? (sys.target ? `${sys.target} target` : 'E prompt, no target script') : `E prompt${sys.target ? ` (${sys.target} found)` : ''}`)}${sysRow('Webhook', sys.webhook ? 'on' : null)}</div></div>`;
    }

    function zoneRow(z, total) {
        const d = z.data;
        const iss = zoneIssues(d);
        const bad = iss.filter((i) => i.level === 'bad');
        const c = zoneCrate(d);
        const l = zoneLoot(d, c);
        const rules = [];
        if (d.minPlayers) rules.push(`${d.minPlayers}+ players`);
        if (d.minPolice) rules.push(`${d.minPolice}+ police`);
        if (d.hours.from >= 0 && d.hours.to >= 0 && d.hours.from !== d.hours.to) rules.push(`${hourName(d.hours.from)}–${hourName(d.hours.to)}`);
        if (d.see && d.see.rule && d.see.rule !== 'default' && seeText(d.see) !== 'Everyone') rules.push(seeText(d.see));
        const chance = d.enabled !== false && total > 0 ? (d.weight / total) * 100 : 0;
        return `<tr class="click ${d.enabled === false ? 'off' : ''}" data-act="edit" data-kind="zone" data-id="${z.id}">
            <td class="bx-mono" style="width:52px">#${z.id}</td>
            <td><b>${esc(d.label)}</b>${d.notes ? `<div class="bx-hint">${esc(d.notes.slice(0, 60))}</div>` : ''}</td>
            <td class="bx-mono">${d.points.length}</td>
            <td>${esc(c ? c.data.label : '—')}${d.crate ? '' : '<div class="bx-hint">default</div>'}</td>
            <td>${esc(l ? l.data.label : '—')}</td>
            <td class="bx-hint">${esc(rules.join(' · ') || 'None')}</td>
            <td class="r bx-mono">${d.enabled === false ? '—' : esc(percent(chance))}</td>
            <td class="r">${bad.length ? `<span class="bx-chip bad">${I('alert', 12)}${bad.length}</span>` : (d.enabled === false ? '<span class="bx-chip off">Off</span>' : `<span class="bx-chip ok">${I('check', 12)}</span>`)}</td>
            <td class="r" style="width:126px;white-space:nowrap"><button class="bx-tool" data-act="zonego" data-id="${z.id}" title="Teleport">${I('goto', 14)}</button><button class="bx-tool" data-act="zonetest" data-id="${z.id}" title="Silent test drop">${I('eye', 14)}</button><button class="bx-tool" data-act="dup" data-kind="zone" data-id="${z.id}" title="Duplicate">${I('copy', 14)}</button></td>
        </tr>`;
    }

    function zonesPage() {
        const q = S.zq.trim().toLowerCase();
        const total = S.zones.filter((z) => z.data.enabled !== false && z.data.points.length).reduce((a, z) => a + (Number(z.data.weight) || 0), 0);
        const list = S.zones.filter((z) => {
            const d = z.data;
            if (S.zFilter === 'ready' && !zoneReady(z)) return false;
            if (S.zFilter === 'work' && !zoneIssues(d).some((i) => i.level === 'bad')) return false;
            if (S.zFilter === 'off' && d.enabled !== false) return false;
            if (S.zCrate && (zoneCrate(d) || {}).id !== S.zCrate) return false;
            if (!q) return true;
            return `#${z.id} ${d.label} ${d.notes}`.toLowerCase().includes(q);
        });
        const chip = (id, label) => `<button class="bx-btn xs ${S.zFilter === id ? 'primary' : 'ghost'}" data-act="zfilter" data-k="${id}">${esc(label)}</button>`;
        return `${head('Drop zones', 'Where crates land. A zone can have several landing points and one is picked each drop. Chance is its share of the rotation.', `<button class="bx-btn" data-act="showall">${I('eye', 15)}Show every point</button><button class="bx-btn primary" data-act="new" data-kind="zone">${I('plus', 15)}New zone</button>`)}
<div class="bx-listbar"><div class="bx-filter">${I('search', 15)}<input class="bx-input" id="ad-zq" value="${esc(S.zq)}" placeholder="Name, notes or #id"></div>
  ${chip('all', 'All')}${chip('ready', 'Ready')}${chip('work', 'Needs work')}${chip('off', 'Off')}
  <span class="bx-sp"></span><select class="bx-input" id="ad-zcrate" style="width:220px"><option value="0">Any crate type</option>${S.crates.map((c) => `<option value="${c.id}" ${S.zCrate === c.id ? 'selected' : ''}>${esc(c.data.label)}</option>`).join('')}</select></div>
${list.length ? `<div class="bx-card"><table class="bx-table"><thead><tr><th>#</th><th>Name</th><th>Points</th><th>Crate</th><th>Loot</th><th>Rules</th><th class="r">Chance</th><th class="r">Setup</th><th></th></tr></thead><tbody>${list.map((z) => zoneRow(z, total)).join('')}</tbody></table></div>`
        : `<div class="bx-empty">${I('pin', 30)}<b>${S.zones.length ? 'Nothing matches' : 'No drop zones yet'}</b><p>${S.zones.length ? 'Try another filter.' : 'Stand where a crate should land, then make a zone and press At my feet. Or place points from the sky with the freecam.'}</p>${S.zones.length ? '' : `<button class="bx-btn primary" data-act="new" data-kind="zone">${I('plus', 15)}New zone</button>`}</div>`}`;
    }

    function field(label, inner, hint) {
        return `<div class="bx-field"><label class="bx-label">${esc(label)}</label>${inner}${hint ? `<div class="bx-hint">${esc(hint)}</div>` : ''}</div>`;
    }

    function inp(path, opts) {
        opts = opts || {};
        const v = getPath(S.cur, path);
        return `<input class="bx-input ${opts.mono ? 'mono' : ''}" data-path="${path}" ${opts.list ? `list="${opts.list}"` : ''} value="${esc(v === null || v === undefined ? '' : v)}" ${opts.placeholder ? `placeholder="${esc(opts.placeholder)}"` : ''} ${opts.max ? `maxlength="${opts.max}"` : ''}>`;
    }

    function unit(path, u, opts) {
        opts = opts || {};
        const v = getPath(S.cur, path);
        return `<div class="bx-unit"><input type="number" data-path="${path}" data-num="1" value="${esc(v === null || v === undefined ? '' : v)}" ${opts.min !== undefined ? `min="${opts.min}"` : ''} ${opts.max !== undefined ? `max="${opts.max}"` : ''} step="${opts.step || 1}">${u ? `<em>${esc(u)}</em>` : ''}</div>`;
    }

    function sw(path, label, hint, disabled) {
        const v = getPath(S.cur, path);
        return `<div class="bx-rowline"><div><b>${esc(label)}</b>${hint ? `<div class="bx-hint">${esc(hint)}</div>` : ''}</div><span class="bx-switch ${v ? 'on' : ''} ${disabled ? 'dis' : ''}" data-act="${disabled ? '' : 'toggle'}" data-path="${path}"></span></div>`;
    }

    function sel(path, options, isNum) {
        const v = getPath(S.cur, path);
        return `<select class="bx-input" data-path="${path}" ${isNum ? 'data-num="1"' : ''}>${options.map((o) => `<option value="${esc(o[0])}" ${String(o[0]) === String(v) ? 'selected' : ''}>${esc(o[1])}</option>`).join('')}</select>`;
    }

    function hoursBar(from, to, nowHour) {
        const on = (h) => {
            if (from < 0 || to < 0 || from === to) return true;
            if (from < to) return h >= from && h < to;
            return h >= from || h < to;
        };
        let cells = '';
        for (let h = 0; h < 24; h++) cells += `<i class="${on(h) ? 'on' : ''} ${h === nowHour ? 'now' : ''}" title="${hourName(h)}"></i>`;
        return `<div class="ad-hours">${cells}</div><div class="ad-hourlbl"><span>00</span><span>06</span><span>12</span><span>18</span><span>24</span></div>`;
    }

    function plan(points, radius, sel) {
        if (!points.length) return '<div class="bx-plan"><svg viewBox="0 0 400 300"><text class="pl-empty" x="200" y="150">No landing points yet</text></svg></div>';
        const r = Math.max(5, radius);
        let minX = Infinity; let maxX = -Infinity; let minY = Infinity; let maxY = -Infinity;
        points.forEach((p) => { minX = Math.min(minX, p.x - r); maxX = Math.max(maxX, p.x + r); minY = Math.min(minY, p.y - r); maxY = Math.max(maxY, p.y + r); });
        const w = 400; const h = 300; const pad = 24;
        const span = Math.max(maxX - minX, ((maxY - minY) * w) / h, 40);
        const k = (w - pad * 2) / span;
        const cx = (minX + maxX) / 2; const cy = (minY + maxY) / 2;
        const X = (x) => w / 2 + (x - cx) * k;
        const Y = (y) => h / 2 - (y - cy) * k;
        const step = span > 1500 ? 500 : (span > 600 ? 200 : (span > 250 ? 100 : 50));
        let grid = '';
        for (let gx = Math.floor((cx - span) / step) * step; gx < cx + span; gx += step) grid += `<line class="pl-grid" x1="${X(gx)}" y1="0" x2="${X(gx)}" y2="${h}"/>`;
        for (let gy = Math.floor((cy - span) / step) * step; gy < cy + span; gy += step) grid += `<line class="pl-grid" x1="0" y1="${Y(gy)}" x2="${w}" y2="${Y(gy)}"/>`;
        const circles = points.map((p) => `<circle class="pl-radius" cx="${X(p.x)}" cy="${Y(p.y)}" r="${Math.max(2, radius * k)}"/>`).join('');
        const dots = points.map((p, i) => `<g class="pl-pt ${sel === i ? 'sel' : ''}"><circle class="halo" cx="${X(p.x)}" cy="${Y(p.y)}" r="11" stroke="#ffb489"/><circle class="body" cx="${X(p.x)}" cy="${Y(p.y)}" r="8" fill="#e07030"/><text x="${X(p.x)}" y="${Y(p.y) + 3}">${i + 1}</text></g>`).join('');
        const bar = step * k;
        return `<div class="bx-plan"><svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMid meet">${grid}${circles}${dots}<text class="pl-north" x="${w - 14}" y="18">N</text><line class="pl-scale" x1="14" y1="${h - 14}" x2="${14 + bar}" y2="${h - 14}"/><text class="pl-scaletext" x="14" y="${h - 20}">${step} m</text></svg></div>`;
    }

    function zoneTabGeneral() {
        const d = S.cur;
        const c = zoneCrate(d);
        const l = zoneLoot(d, c);
        const def = defaultCrate();
        const total = S.zones.filter((z) => z.id !== S.curId && z.data.enabled !== false && z.data.points.length).reduce((a, z) => a + (Number(z.data.weight) || 0), 0) + (d.enabled !== false ? Number(d.weight) || 0 : 0);
        const chance = d.enabled !== false && total > 0 ? ((Number(d.weight) || 0) / total) * 100 : 0;
        const fromCrate = c && c.data.loot && lootById(c.data.loot);
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardbody">
  ${field('Name', inp('label', { max: 60, placeholder: 'Sandy Shores Airfield' }), 'Shown in the announcement when names are on.')}
  <div class="bx-cols2">${field('Crate type', sel('crate', [[0, `Default${def ? ` (${def.data.label})` : ''}`]].concat(S.crates.map((x) => [x.id, x.data.label])), true))}${field('Loot table', sel('loot', [[0, `From the crate type${fromCrate ? ` (${fromCrate.data.label})` : (S.loot[0] ? ` (${S.loot[0].data.label})` : '')}`]].concat(S.loot.map((x) => [x.id, x.data.label])), true))}</div>
  ${field('Staff notes', `<textarea class="bx-input" data-path="notes" rows="3" style="height:auto;padding:9px 11px" maxlength="400">${esc(d.notes || '')}</textarea>`)}
</div></div>
</div><div>
<div class="bx-card"><div class="bx-cardbody">
  ${sw('enabled', 'Live', 'Off keeps it out of the rotation without deleting it.')}
  <div class="bx-rowline"><div><b>Weight</b><div class="bx-hint">${esc(`Its share of the rotation. Right now that is ${percent(chance)} of drops.`)}</div></div><div style="width:150px">${unit('weight', '', { min: 1, max: 1000 })}</div></div>
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Plane approach</h3><small>${esc(d.heading < 0 ? 'Random each drop' : `Flies on a heading of ${d.heading}°`)}</small></div><div class="bx-cardbody">
  <div class="ad-compass"><button class="ad-cdir ${d.heading < 0 ? 'on' : ''}" data-act="heading" data-h="-1">${I('dice', 14)}Random</button>${COMPASS.map((x) => `<button class="ad-cdir ${Number(d.heading) === x[1] ? 'on' : ''}" data-act="heading" data-h="${x[1]}">${I('compass', 13)}Flies ${x[0]}</button>`).join('')}</div>
  <div class="bx-hint" style="margin-top:8px">The plane crosses the landing point going this way. Point it along a valley or a road so it reads well from the ground.</div>
</div></div>
</div></div>`;
    }

    function zoneTabPoints() {
        const d = S.cur;
        const radius = d.radius > 0 ? d.radius : (setting('Drop.ZoneRadius') || 120);
        const approx = d.approx > 0 ? d.approx : (setting('Drop.ApproxBlipRadius') || 250);
        return `<div class="bx-layout"><div>
<div class="bx-group"><div class="bx-grouph"><span class="bx-gico" style="background:#e07030">${I('pin', 16)}</span><div class="bx-gtext"><b>Landing points ${d.points.length ? `<span class="bx-tag ok">${d.points.length}</span>` : '<span class="bx-tag req">needed</span>'}</b><span>One is picked at random each drop. Open ground with more than one way in plays best.</span></div></div>
  <div class="bx-points">${d.points.map((p, i) => `<div class="bx-pt"><span class="bx-ptn">${i + 1}</span><div class="bx-ptmain"><b>Point ${i + 1}</b><small>${esc(pt(p))}</small></div>
    <div class="bx-ptacts"><button class="bx-tool" data-act="ptgo" data-i="${i}" title="Teleport">${I('goto', 13)}</button><button class="bx-tool" data-act="ptmark" data-i="${i}" title="Waypoint">${I('map', 13)}</button><button class="bx-tool" data-act="ptre" data-i="${i}" title="Move with the freecam">${I('crosshair', 13)}</button><button class="bx-tool danger" data-act="ptdel" data-i="${i}" title="Remove">${I('remove', 13)}</button></div></div>`).join('')}</div>
  <div class="bx-addrow"><button class="bx-btn sm" data-act="ptadd">${I('crosshair', 14)}Place with the freecam</button><button class="bx-btn sm" data-act="pthere">${I('pin', 14)}At my feet</button></div>
</div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardbody">
  <div class="bx-cols2">${field('Contest radius', unit('radius', 'm', { min: 0, max: 1000, step: 5 }), `The red circle once it lands. 0 uses the setting (${radius} m).`)}${field('Search radius', unit('approx', 'm', { min: 0, max: 3000, step: 10 }), `The yellow circle while inbound. 0 uses the setting (${approx} m).`)}</div>
  <button class="bx-btn sm" data-act="showpts" ${d.points.length ? '' : 'disabled'}>${I('eye', 14)}Show all points in the world</button>
</div></div>
</div><div>
<div class="bx-planwrap"><div class="bx-planbar"><b>Seen from above</b><span class="bx-hint">${esc(`${radius} m contest circles`)}</span></div>${plan(d.points, radius, null)}<div class="bx-planlegend"><span><i style="background:#e07030"></i>Landing point</span><span><i style="background:#ff5c64"></i>Contest radius</span></div></div>
</div></div>`;
    }

    function zoneTabRules() {
        const d = S.cur;
        const sc = (S.live && S.live.schedule) || {};
        const hours = [[-1, 'Any time']].concat(Array.from({ length: 24 }, (_, h) => [h, hourName(h)]));
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Who needs to be on</h3></div><div class="bx-cardbody">
  <div class="bx-cols2">${field('Players online', unit('minPlayers', '', { min: 0, max: 256 }), `0 = just the schedule's ${setting('Schedule.MinPlayers') || 0}. Right now: ${sc.players || 0}.`)}${field('Police on duty', unit('minPolice', '', { min: 0, max: 64 }), `0 = no police needed. Right now: ${sc.police || 0}.`)}</div>
  <div class="bx-hint">Only the schedule checks these. Staff can still start a drop here any time.</div>
</div></div>
</div><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Time of day</h3><small>Server time</small></div><div class="bx-cardbody">
  <div class="bx-cols2">${field('From', sel('hours.from', hours, true))}${field('Until', sel('hours.to', hours, true))}</div>
  ${hoursBar(Number(d.hours.from), Number(d.hours.to), sc.hour)}
  <div class="bx-hint" style="margin-top:8px">Any time on both means all day. Windows can cross midnight, like 20:00 until 04:00.</div>
</div></div>
</div></div>`;
    }

    function zoneTabSee() {
        const d = S.cur;
        const mode = setting('Access.See.Mode') || 'everyone';
        const listed = groupNames(setting('Access.See.Jobs'), setting('Access.See.Gangs'));
        const fromSettings = {
            everyone: 'Everyone, as set in Settings › Who takes part.',
            only: `Only ${listed || 'the jobs and gangs listed'} in Settings › Who takes part.`,
            except: `Everyone except ${listed || 'the jobs and gangs listed'} in Settings › Who takes part.`,
        }[mode] || 'As set in Settings › Who takes part.';
        const rules = [
            ['default', 'Same as Settings', fromSettings],
            ['everyone', 'Everyone', 'Every player gets the pin, the circles and the messages.'],
            ['only', 'Only some jobs and gangs', 'Pick them on the right. Nobody else is told it exists.'],
            ['except', 'Everyone except some jobs and gangs', 'Pick them on the right. Pick police to keep it off their map.'],
        ];
        const picking = d.see.rule === 'only' || d.see.rule === 'except';
        const policeSee = setting('Access.Police.CanSee') !== false;
        const policeNote = d.see.rule === 'only' && policeSee ? 'Police still see it, because Police always see drops is on in Settings. ' : '';
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Who sees drops here</h3><small>${esc(seeText(d.see))}</small></div><div class="bx-cardbody">
  <div class="ad-radios">${rules.map((r) => `<button class="ad-radio ${d.see.rule === r[0] ? 'on' : ''}" data-act="setv" data-path="see.rule" data-v="${r[0]}"><i></i><div><b>${esc(r[1])}</b><span>${esc(r[2])}</span></div></button>`).join('')}</div>
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">${esc(`${policeNote}Players it is hidden from get no pin, no circles, no messages and no crate. The server never sends them where it is, so they cannot open it either. Police are only called by the crate type when they can see it.`)}</div></div></div>
</div><div>
${picking ? `<div class="bx-card"><div class="bx-cardhead"><h3>Jobs</h3><small>${esc(d.see.rule === 'only' ? 'These see it' : 'These do not')}</small></div><div class="bx-cardbody">${chips('see.jobs', S.jobs, d.see.jobs)}<input class="bx-input mono" style="margin-top:10px" data-addchip="see.jobs" placeholder="Add a job name, then Enter"></div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Gangs</h3><small>${esc(d.see.rule === 'only' ? 'These see it' : 'These do not')}</small></div><div class="bx-cardbody">${chips('see.gangs', S.gangs, d.see.gangs)}<input class="bx-input mono" style="margin-top:10px" data-addchip="see.gangs" placeholder="Add a gang name, then Enter"></div></div>` : `<div class="bx-card"><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">Pick Only or Everyone except to choose jobs and gangs for this zone. Who can open the crate is set on the crate type.</div><button class="bx-btn sm ghost" style="margin-top:10px" data-act="setting" data-key="Access.See.Mode">${I('sliders', 13)}Open the setting</button></div></div>`}
</div></div>`;
    }

    function editorHead(kind, crumbPage, crumbLabel, extra) {
        return `<div class="bx-crumb"><button data-act="nav" data-page="${crumbPage}">${esc(crumbLabel)}</button>${I('chevron', 12)}<span>${esc(S.curId ? `#${S.curId}` : 'New')}</span></div>
<div class="bx-edhead"><input class="bx-edname" data-path="label" value="${esc(S.cur.label)}" placeholder="Name it" maxlength="60"><span class="bx-sp"></span>
  ${extra || ''}
  ${S.curId ? `<button class="bx-btn danger" data-act="delete" title="Delete">${I('remove', 15)}</button>` : ''}
  <button class="bx-btn primary" data-act="save" ${S.busy ? 'disabled' : ''}>${I('check', 15)}${esc(S.dirty || !S.curId ? 'Save' : 'Saved')}<span class="bx-kbd">Ctrl S</span></button></div>`;
    }

    function tabs(list, labels, counts) {
        return `<div class="bx-tabs">${list.map((x) => `<button class="bx-tab ${S.tab === x ? 'on' : ''}" data-act="tab" data-tab="${x}">${I(labels[x][0], 14)}${esc(labels[x][1])}${counts && counts[x] ? `<em>${counts[x]}</em>` : ''}</button>`).join('')}</div>`;
    }

    function zoneEditor() {
        const d = S.cur;
        if (!d) return overview();
        const list = zoneIssues(d);
        const c = zoneCrate(d);
        const l = zoneLoot(d, c);
        if (!['general', 'points', 'rules', 'see'].includes(S.tab)) S.tab = 'general';
        const steps = [
            ['Name', !!d.label.trim(), 'general'],
            ['Landing point', d.points.length > 0, 'points'],
            ['Crate type', !!c, 'general'],
            ['Loot', !!l && liveTiers(l.data).length > 0, 'general'],
        ];
        const body = { general: zoneTabGeneral, points: zoneTabPoints, rules: zoneTabRules, see: zoneTabSee };
        const extra = S.curId ? `<button class="bx-btn ghost" data-act="zonego" data-id="${S.curId}">${I('goto', 15)}Teleport</button><button class="bx-btn" data-act="zonetest" data-id="${S.curId}">${I('eye', 15)}Silent test</button><button class="bx-btn" data-act="zonedrop" data-id="${S.curId}">${I('chute', 15)}Drop here now</button>` : '';
        return `${editorHead('zone', 'zones', 'Drop zones', extra)}
<div class="bx-edmeta">${c ? `<span class="bx-chip blue">${I('box', 12)}${esc(c.data.label)}</span>` : ''}${l ? `<span class="bx-chip">${I('stack', 12)}${esc(l.data.label)}</span>` : ''}${d.enabled === false ? '<span class="bx-chip off">Switched off</span>' : ''}${list.filter((i) => i.level === 'bad').length ? `<span class="bx-chip bad">${I('alert', 12)}${list.filter((i) => i.level === 'bad').length} to fix</span>` : ''}${S.dirty ? '<span class="bx-save-state dirty">Unsaved changes</span>' : ''}</div>
<div class="bx-steps">${steps.map((s) => `<span class="bx-step ${s[1] ? 'done' : 'need'}" data-act="tab" data-tab="${s[2]}"><i>${I(s[1] ? 'check' : 'alert', 10)}</i>${esc(s[0])}</span>`).join('')}</div>
${tabs(['general', 'points', 'rules', 'see'], { general: ['info', 'General'], points: ['pin', 'Landing points'], rules: ['clock', 'Rules'], see: ['eye', 'Who sees it'] }, { points: d.points.length })}
${body[S.tab]()}
<div style="height:60px"></div>`;
    }

    function accessText(d) {
        const a = d.access;
        let who = 'Same as Settings';
        if (a.rule === 'everyone') who = 'Everyone';
        if (a.rule === 'groups') who = [...a.jobs, ...a.gangs].join(', ') || 'Nobody listed';
        const police = a.police === 'allow' ? ' · police can' : (a.police === 'deny' ? ' · not police' : '');
        return who + police;
    }

    function cratesPage() {
        const usedBy = (c) => S.zones.filter((z) => (zoneCrate(z.data) || {}).id === c.id).length;
        return `${head('Crate types', 'What lands: the prop, how long it takes to open, who can open it, the plane, the police call and the map pin. Zones pick one, or use the default.', `<button class="bx-btn primary" data-act="new" data-kind="crate">${I('plus', 15)}New crate type</button>`)}
<div class="bx-card"><table class="bx-table"><thead><tr><th>#</th><th>Name</th><th>Prop</th><th>Opening</th><th>Who can open</th><th>Look</th><th class="r">Zones</th><th></th></tr></thead><tbody>
${S.crates.map((rec) => {
        const c = normCrate(rec.data);
        const iss = crateIssues(c);
        const sp = XS.BLIPS && XS.BLIPS.find(c.blip.sprite);
        return `<tr class="click" data-act="edit" data-kind="crate" data-id="${rec.id}">
            <td class="bx-mono" style="width:52px">#${rec.id}</td>
            <td><div class="bx-pname">${sp ? `<span class="ad-blipico"><img src="${esc(XS.BLIPS.image(sp))}" alt="" onerror="this.style.visibility='hidden'"></span>` : ''}<div><b>${esc(c.label)}</b><small>${c.isDefault ? 'Default · ' : ''}${esc((crateLoot(c) || { data: { label: '—' } }).data.label)}</small></div></div></td>
            <td class="bx-mono bx-hint">${esc(c.model)}</td>
            <td>${esc(`${c.crackTime}s to open`)}<div class="bx-hint">${esc(S.system.shared ? `${c.slots} slots` : `${c.stacksPerSearch} per search`)}</div></td>
            <td>${esc(accessText(c))}</td>
            <td>${c.flyover ? `<span class="bx-chip">${I('plane', 12)}${esc(c.plane)}</span> ` : ''}${c.parachute ? `<span class="bx-chip">${I('chute', 12)}</span> ` : ''}${c.flare ? '<span class="bx-chip">Flare</span> ' : ''}${c.smoke ? '<span class="bx-chip">Smoke</span>' : ''}</td>
            <td class="r bx-mono">${usedBy(rec)}</td>
            <td class="r" style="white-space:nowrap">${iss.some((i) => i.level === 'bad') ? `<span class="bx-chip bad">${I('alert', 12)}</span>` : ''}${c.isDefault ? '<span class="bx-chip blue">Default</span>' : `<button class="bx-btn xs ghost" data-act="cratedefault" data-id="${rec.id}">Make default</button>`}<button class="bx-tool" data-act="dup" data-kind="crate" data-id="${rec.id}" title="Duplicate">${I('copy', 14)}</button></td>
        </tr>`;
    }).join('')}
</tbody></table></div>`;
    }

    function chips(path, list, picked) {
        const set = new Set(XS.list(picked));
        const known = new Set(XS.list(list).map((j) => j.name));
        const extra = XS.list(picked).filter((n) => !known.has(n)).map((n) => ({ name: n, label: n }));
        const all = XS.list(list).concat(extra);
        if (!all.length) return '<div class="bx-hint">None found on this server. Type one below.</div>';
        return `<div class="bx-jobchips">${all.map((j) => `<span class="bx-jobchip ${set.has(j.name) ? 'on' : ''}" data-act="chip" data-path="${path}" data-v="${esc(j.name)}"><span class="chk">${set.has(j.name) ? I('check', 10) : ''}</span>${esc(j.label)}<small>${esc(j.name)}</small></span>`).join('')}</div>`;
    }

    function crateTabGeneral() {
        const d = S.cur;
        const first = S.loot[0];
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardbody">
  ${field('Crate prop', `${inp('model', { mono: true, list: 'ad-models', max: 64, placeholder: 'prop_mil_crate_01' })}<datalist id="ad-models">${CRATE_MODELS.map((m) => `<option value="${esc(m)}">`).join('')}</datalist>`, 'Any object model. If it will not load, prop_mil_crate_01 is used instead.')}
  ${field('Loot table', sel('loot', [[0, `The first one${first ? ` (${first.data.label})` : ''}`]].concat(S.loot.map((x) => [x.id, x.data.label])), true), 'Zones can pick a different one.')}
  ${field('Staff notes', `<textarea class="bx-input" data-path="notes" rows="3" style="height:auto;padding:9px 11px" maxlength="400">${esc(d.notes || '')}</textarea>`)}
</div></div></div><div>
<div class="bx-card"><div class="bx-cardbody">
  ${sw('isDefault', 'Default crate type', 'Zones that do not pick one get this.')}
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Used by</h3></div><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">${esc(S.zones.filter((z) => S.curId && (zoneCrate(z.data) || {}).id === S.curId).map((z) => z.data.label).join(', ') || 'No zones yet.')}</div></div></div>
</div></div>`;
    }

    function crateTabOpening() {
        const shared = !!S.system.shared;
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Cracking</h3></div><div class="bx-cardbody">
  ${field('Time to force it open', unit('crackTime', 's', { min: 3, max: 600 }), 'You stand still in the open for this long. Long enough that someone can stop you.')}
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Shared crate</h3><small>${esc(shared ? 'Your inventory uses this' : 'ox_inventory only')}</small></div><div class="bx-cardbody">
  <div class="bx-cols2">${field('Slots', unit('slots', '', { min: 1, max: 100 }))}${field('Capacity', unit('maxWeight', 'g', { min: 1000, max: 2000000, step: 1000 }))}</div>
  <div class="bx-hint">The crate opens as a stash everyone can rummage in at once.</div>
</div></div></div><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Searching</h3><small>${esc(shared ? 'Other inventories only' : 'Your inventory uses this')}</small></div><div class="bx-cardbody">
  <div class="bx-cols2">${field('Stacks per search', unit('stacksPerSearch', '', { min: 1, max: 24 }))}${field('Searches per player', unit('searchesPerPlayer', '', { min: 0, max: 50 }), '0 = no limit')}</div>
  <div class="bx-hint">Inventories that cannot be handed a filled crate give out a few stacks each time someone searches, so being second still gets you something.</div>
</div></div></div></div>`;
    }

    function crateTabAccess() {
        const d = S.cur;
        const everyone = setting('Access.Collect.Everyone');
        const rules = [
            ['default', 'Same as Settings', everyone === false ? 'Only the jobs and gangs listed in Settings › Who takes part.' : 'Everyone, as set in Settings › Who takes part.'],
            ['everyone', 'Everyone', 'Anyone who reaches it can open it.'],
            ['groups', 'Only some jobs and gangs', 'Pick them below. Everyone else is told the refusal message.'],
        ];
        const police = [['default', `Same as Settings (${setting('Access.Police.CanCollect') === false ? 'cannot' : 'can'} loot)`], ['allow', 'Police can open it'], ['deny', 'Police cannot open it']];
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Who can open it</h3></div><div class="bx-cardbody">
  <div class="ad-radios">${rules.map((r) => `<button class="ad-radio ${d.access.rule === r[0] ? 'on' : ''}" data-act="setv" data-path="access.rule" data-v="${r[0]}"><i></i><div><b>${esc(r[1])}</b><span>${esc(r[2])}</span></div></button>`).join('')}</div>
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Police</h3></div><div class="bx-cardbody">
  ${field('Police', sel('access.police', police), 'Turning police off makes them responders rather than another gang.')}
</div></div></div><div>
${d.access.rule === 'groups' ? `<div class="bx-card"><div class="bx-cardhead"><h3>Jobs</h3></div><div class="bx-cardbody">${chips('access.jobs', S.jobs, d.access.jobs)}<input class="bx-input mono" style="margin-top:10px" data-addchip="access.jobs" placeholder="Add a job name, then Enter"></div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Gangs</h3></div><div class="bx-cardbody">${chips('access.gangs', S.gangs, d.access.gangs)}<input class="bx-input mono" style="margin-top:10px" data-addchip="access.gangs" placeholder="Add a gang name, then Enter"></div></div>` : `<div class="bx-card"><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">Who sees a drop is set on each drop zone, under Who sees it, or for every zone in Settings › Who takes part. Someone a drop is hidden from cannot open it either.</div></div></div>`}
</div></div>`;
    }

    function flightTime(d) {
        if (setting('Delivery.Flyover') === false || !d.flyover) return 0;
        const speed = Math.max(10, Number(setting('Delivery.PlaneSpeed')) || 90);
        const travel = (Number(setting('Delivery.SpawnDistance')) || 900) / speed;
        const fall = (Number(d.altitude) || 320) / (d.parachute ? 16 : 45);
        return Math.round(travel + fall);
    }

    function crateTabDelivery() {
        const d = S.cur;
        const master = setting('Delivery.Flyover') !== false;
        const ft = flightTime(d);
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Flyover</h3>${master ? '' : '<small style="color:var(--b-amber)">Plane flyovers are off in Settings</small>'}</div><div class="bx-cardbody">
  ${sw('flyover', 'Plane flies over', 'Off makes the crate just appear when it lands.')}
  ${sw('parachute', 'Parachute', 'The crate floats down under a cargo chute. Off, it falls fast.', !d.flyover)}
  <div class="bx-cols2" style="margin-top:12px">${field('Plane model', `${inp('plane', { mono: true, list: 'ad-planes', max: 40 })}<datalist id="ad-planes">${PLANES.map((m) => `<option value="${esc(m)}">`).join('')}</datalist>`)}${field('Height above the point', unit('altitude', 'm', { min: 50, max: 1500, step: 10 }))}</div>
  <div class="bx-hint">${esc(ft ? `The plane shows up about ${ft} seconds before landing.` : 'No plane, so nothing shows until it lands.')}</div>
</div></div></div><div>
<div class="bx-card"><div class="bx-cardhead"><h3>On the ground</h3></div><div class="bx-cardbody">
  ${sw('flare', 'Flare', 'A red flare and glow on the crate.')}
  ${sw('smoke', 'Smoke', 'A smoke column you can see from a distance.')}
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Police</h3></div><div class="bx-cardbody">
  ${sw('police.alert', 'Call the police', 'Uses your dispatch script, or a plain notification and blip.')}
  ${d.police.alert ? field('After landing, wait', unit('police.delay', 's', { min: 0, max: 900, step: 5 }), 'The delay gives whoever raced for it a head start.') : ''}
</div></div></div></div>`;
    }

    function preview(text) {
        return String(text || '').replace(/\{near\}/g, ' near Sandy Shores Airfield').replace(/\{zone\}/g, 'Sandy Shores Airfield').replace(/\{seconds\}/g, String(setting('Drop.WarningTime') || 90))
            .replace(/\{name\}/g, 'XyraL').replace(/\{crate\}/g, S.cur.label || 'Supply crate');
    }

    function crateTabText() {
        const d = S.cur;
        const row = (key, label) => `${field(label, `<textarea class="bx-input" data-path="announce.${key}" rows="2" style="height:auto;padding:9px 11px" maxlength="160">${esc(d.announce[key] || '')}</textarea>`)}<div class="ad-say">${esc(d.announce[key] ? preview(d.announce[key]) : 'Nothing is said.')}</div>`;
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardbody">
  ${row('inbound', 'Inbound')}${row('landed', 'Landed')}
</div></div></div><div>
<div class="bx-card"><div class="bx-cardbody">
  ${row('opened', 'Opened')}${row('emptied', 'Emptied')}
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.6">Leave one empty to say nothing at that step. You can use <span class="bx-mono">{near}</span> (" near the zone", or nothing when names are hidden), <span class="bx-mono">{zone}</span>, <span class="bx-mono">{seconds}</span>, <span class="bx-mono">{name}</span> (who opened it) and <span class="bx-mono">{crate}</span>.</div>
  <button class="bx-btn sm ghost" style="margin-top:10px" data-act="resettext">${I('undo', 13)}Back to the default text</button></div></div>
</div></div>`;
    }

    function blipPicker() {
        const d = S.cur;
        const B = XS.BLIPS;
        if (!B) return '';
        const sprite = Number(d.blip.sprite) || 478;
        const colour = Number(d.blip.colour);
        const sp = B.find(sprite);
        const col = B.colours.find((c) => c.id === colour);
        return `<div class="bb-preview"><span class="bb-ico">${sp ? `<img src="${esc(B.image(sp))}" alt="" onerror="this.style.visibility='hidden'">` : `<b>${sprite}</b>`}<span class="bb-dot" style="background:${esc(col ? col.hex : '#888')}"></span></span><div><strong>${esc(d.blip.label || 'Supply Drop')}</strong><span>${esc(`${sp ? sp.label : 'Icon'} ${sprite} · ${col ? col.label : 'colour'} ${colour}`)}</span></div></div>
        <div class="ad-blips">${B.sprites.map((s) => `<button class="ad-sp ${sprite === s.id ? 'on' : ''}" data-act="sprite" data-id="${s.id}" title="${esc(`${s.label} · ${s.id}`)}"><img src="${esc(B.image(s))}" alt="" loading="lazy" onerror="this.style.visibility='hidden'"></button>`).join('')}</div>
        <div class="ad-colours">${B.colours.slice(0, 48).map((c) => `<button class="ad-col ${colour === c.id ? 'on' : ''}" data-act="colour" data-id="${c.id}" title="${esc(`${c.label} · ${c.id}`)}" style="background:${esc(c.hex)}"></button>`).join('')}</div>`;
    }

    function crateTabMap() {
        return `<div class="bx-layout"><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Map pin</h3></div><div class="bx-cardbody">
  ${blipPicker()}
  <div class="bx-cols3">${field('Label', inp('blip.label', { max: 40, placeholder: 'Supply Drop' }))}${field('Icon number', unit('blip.sprite', '', { min: 1, max: 900 }))}${field('Colour number', unit('blip.colour', '', { min: 0, max: 85 }))}</div>
</div></div></div><div>
<div class="bx-card"><div class="bx-cardbody"><div class="bx-hint" style="font-size:12.5px;line-height:1.55">The pin sits on the landing point until someone opens the crate. While the plane is inbound it flashes inside the wide search circle, then the circle shrinks to the contest radius when it lands. Once the crate is open, the pin and circle go for everyone. Circle colours are in Settings › Map.</div></div></div>
</div></div>`;
    }

    function crateEditor() {
        const d = S.cur;
        if (!d) return overview();
        const order = ['general', 'opening', 'access', 'delivery', 'text', 'map'];
        if (!order.includes(S.tab)) S.tab = 'general';
        const body = { general: crateTabGeneral, opening: crateTabOpening, access: crateTabAccess, delivery: crateTabDelivery, text: crateTabText, map: crateTabMap };
        const iss = crateIssues(d);
        return `${editorHead('crate', 'crates', 'Crate types')}
<div class="bx-edmeta"><span class="bx-chip blue">${I('box', 12)}${esc(d.model)}</span><span class="bx-chip">${esc(`${d.crackTime}s to open`)}</span>${d.isDefault ? '<span class="bx-chip ok">Default</span>' : ''}${iss.filter((i) => i.level === 'bad').length ? `<span class="bx-chip bad">${I('alert', 12)}${esc(iss[0].text)}</span>` : ''}${S.dirty ? '<span class="bx-save-state dirty">Unsaved changes</span>' : ''}</div>
${tabs(order, { general: ['info', 'General'], opening: ['unlock', 'Opening'], access: ['shield', 'Who can open'], delivery: ['plane', 'Delivery'], text: ['bell', 'Announcements'], map: ['mapblip', 'Map pin'] })}
${body[S.tab]()}
<div style="height:60px"></div>`;
    }

    function lootPage() {
        return `${head('Loot tables', 'What is inside. Each roll picks a tier by its weight, then an item from it. Loot is rolled on the server the moment a crate is opened.', `<button class="bx-btn primary" data-act="new" data-kind="loot">${I('plus', 15)}New loot table</button>`)}
<div class="bx-card"><table class="bx-table"><thead><tr><th>#</th><th>Name</th><th>Tiers</th><th>Stacks</th><th>Guarantee</th><th>Used by</th><th class="r">Setup</th><th></th></tr></thead><tbody>
${S.loot.map((rec) => {
        const d = normLoot(rec.data);
        const iss = lootIssues(d);
        const items = d.tiers.reduce((a, t) => a + t.items.length, 0);
        const crates = S.crates.filter((c) => (crateLoot(normCrate(c.data)) || {}).id === rec.id).length;
        const zones = S.zones.filter((z) => z.data.loot === rec.id).length;
        return `<tr class="click" data-act="edit" data-kind="loot" data-id="${rec.id}">
            <td class="bx-mono" style="width:52px">#${rec.id}</td>
            <td><b>${esc(d.label)}</b></td>
            <td>${d.tiers.map((t) => `<span class="ad-tdot" style="background:${esc(t.colour)}" title="${esc(t.name)}"></span>`).join('')} <span class="bx-hint">${esc(`${d.tiers.length} tiers, ${items} items`)}</span></td>
            <td class="bx-mono">${esc(`${d.minStacks}–${d.maxStacks}`)}</td>
            <td>${esc(d.guarantee || 'None')}</td>
            <td class="bx-hint">${esc(`${crates} crate type${crates === 1 ? '' : 's'}, ${zones} zone${zones === 1 ? '' : 's'}`)}</td>
            <td class="r">${iss.some((i) => i.level === 'bad') ? `<span class="bx-chip bad">${I('alert', 12)}</span>` : (iss.length ? `<span class="bx-chip warn">${I('alert', 12)}${iss.length}</span>` : `<span class="bx-chip ok">${I('check', 12)}</span>`)}</td>
            <td class="r"><button class="bx-tool" data-act="dup" data-kind="loot" data-id="${rec.id}" title="Duplicate">${I('copy', 14)}</button></td>
        </tr>`;
    }).join('')}
</tbody></table></div>`;
    }

    function itemImage(name) {
        const inv = S.system.inventory;
        const base = {
            ox_inventory: 'nui://ox_inventory/web/images/', 'qb-inventory': 'nui://qb-inventory/html/images/', 'ps-inventory': 'nui://ps-inventory/html/images/',
            'qs-inventory': 'nui://qs-inventory/html/images/', 'codem-inventory': 'nui://codem-inventory/html/itemimages/', core_inventory: 'nui://core_inventory/html/img/',
        }[inv];
        if (!base || !name) return '';
        return `<img src="${esc(base + name)}.png" alt="" onerror="this.remove()">`;
    }

    function itemLabel(name) {
        const hit = S.items.find((i) => i.name === name);
        return hit ? hit.label : '';
    }

    function lootEditor() {
        const d = S.cur;
        if (!d) return overview();
        const live = liveTiers(d);
        const tierSum = live.reduce((a, x) => a + (Number(x.t.weight) || 0), 0);
        const iss = lootIssues(d);
        const bar = live.map((x) => `<span style="width:${tierSum ? ((Number(x.t.weight) || 0) / tierSum) * 100 : 0}%;background:${esc(x.t.colour)}" title="${esc(x.t.name)}"></span>`).join('');
        const tierCard = (t, ti) => {
            const liveT = live.find((x) => x.rank === ti);
            const tierPct = liveT && tierSum ? ((Number(t.weight) || 0) / tierSum) * 100 : 0;
            const itemSum = liveT ? liveT.items.reduce((a, it) => a + (Number(it.weight) || 0), 0) : 0;
            const rows = t.items.map((it, ii) => {
                const on = liveT && it.enabled !== false && it.item;
                const inTier = on && itemSum ? ((Number(it.weight) || 0) / itemSum) * 100 : 0;
                const known = !it.item || !S.items.length || S.itemSet.has(it.item) || S.itemSet.has(String(it.item).toLowerCase());
                return `<div class="ad-irow ${it.enabled === false ? 'off' : ''}">
                    <span class="bx-thumb">${itemImage(it.item)}${I('box', 14)}</span>
                    <div class="bx-picker"><input class="bx-input mono sm" data-item="${ti}.${ii}" value="${esc(it.item)}" placeholder="item name" autocomplete="off"><div class="ad-iname ${known ? '' : 'missing'}">${esc(known ? (itemLabel(it.item) || (it.item ? '' : 'Pick an item')) : 'Not on this server')}</div><div class="bx-pickpop xsp-hidden" data-pop="${ti}.${ii}"></div></div>
                    <div class="bx-unit"><input type="number" data-path="tiers.${ti}.items.${ii}.min" data-num="1" value="${esc(it.min)}" min="1" max="10000"><em>min</em></div>
                    <div class="bx-unit"><input type="number" data-path="tiers.${ti}.items.${ii}.max" data-num="1" value="${esc(it.max)}" min="1" max="10000"><em>max</em></div>
                    <div class="bx-unit"><input type="number" data-path="tiers.${ti}.items.${ii}.weight" data-num="1" value="${esc(it.weight)}" min="1" max="1000"><em>wt</em></div>
                    <div class="ad-odds"><b>${esc(percent(inTier))}</b><small>${esc(`${percent((tierPct * inTier) / 100)} a roll`)}</small></div>
                    <span class="bx-switch ${it.enabled !== false ? 'on' : ''}" data-act="toggle" data-path="tiers.${ti}.items.${ii}.enabled" title="On"></span>
                    <button class="bx-tool danger" data-act="itemdel" data-t="${ti}" data-i="${ii}" title="Remove">${I('remove', 13)}</button>
                </div>`;
            }).join('');
            return `<div class="ad-tier ${t.enabled === false ? 'off' : ''}">
                <div class="ad-tierh">
                    <input type="color" class="ad-tcolour" data-path="tiers.${ti}.colour" value="${esc(t.colour)}" title="Colour">
                    <input class="bx-input" data-path="tiers.${ti}.name" value="${esc(t.name)}" maxlength="32" style="width:170px">
                    <div class="bx-unit" style="width:130px"><input type="number" data-path="tiers.${ti}.weight" data-num="1" value="${esc(t.weight)}" min="1" max="1000"><em>weight</em></div>
                    <div class="ad-odds big"><b>${esc(percent(tierPct))}</b><small>of rolls</small></div>
                    ${d.guarantee === t.name ? '<span class="bx-chip blue">Guarantee floor</span>' : ''}
                    <span class="bx-sp"></span>
                    <button class="bx-tool ad-up" data-act="tiermove" data-t="${ti}" data-dir="-1" title="Move up" ${ti === 0 ? 'disabled' : ''}>${I('chevron', 13)}</button>
                    <button class="bx-tool ad-down" data-act="tiermove" data-t="${ti}" data-dir="1" title="Move down" ${ti === d.tiers.length - 1 ? 'disabled' : ''}>${I('chevron', 13)}</button>
                    <span class="bx-switch ${t.enabled !== false ? 'on' : ''}" data-act="toggle" data-path="tiers.${ti}.enabled" title="On"></span>
                    <button class="bx-tool danger" data-act="tierdel" data-t="${ti}" title="Remove tier">${I('remove', 13)}</button>
                </div>
                <div class="ad-items">${rows || '<div class="bx-hint" style="padding:6px 4px">No items in this tier yet.</div>'}</div>
                <div class="bx-addrow" style="padding:0"><button class="bx-btn sm ghost" data-act="itemadd" data-t="${ti}">${I('plus', 14)}Add an item</button></div>
            </div>`;
        };
        const roll = S.roll ? `<div class="bx-card" style="margin-bottom:14px"><div class="bx-cardhead"><h3>Test crate</h3><small>Rolled on the server with these numbers, nothing given out</small><span class="bx-sp"></span><button class="bx-btn xs ghost" data-act="rollclose">${I('close', 12)}</button></div><div class="bx-cardbody"><div class="ad-rolls">${XS.list(S.roll).map((r) => `<span class="ad-rollit" style="border-color:${esc((d.tiers.find((t) => t.name === r.tier) || {}).colour || '#555')}"><b>${esc(r.count)}×</b> ${esc(r.item)}<small>${esc(r.tier)}</small></span>`).join('') || '<span class="bx-hint">Empty crate.</span>'}</div></div></div>` : '';
        return `${editorHead('loot', 'loot', 'Loot tables', `<button class="bx-btn" data-act="lootroll">${I('dice', 15)}Roll a test crate</button>`)}
<div class="bx-edmeta">${iss.map((i) => `<span class="bx-chip ${i.level === 'bad' ? 'bad' : 'warn'}">${I('alert', 12)}${esc(i.text)}</span>`).join('')}${S.dirty ? '<span class="bx-save-state dirty">Unsaved changes</span>' : ''}</div>
<div class="bx-card" style="margin:16px 0 14px"><div class="bx-cardbody">
  <div class="bx-cols3">${field('Fewest stacks', unit('minStacks', '', { min: 1, max: 24 }))}${field('Most stacks', unit('maxStacks', '', { min: 1, max: 24 }))}${field('Guarantee at least', sel('guarantee', [['', 'No guarantee']].concat(d.tiers.map((t) => [t.name, t.name]))), 'One roll is forced up to this tier or better if nothing reached it.')}</div>
  <div class="ad-tierbar">${bar}</div>
  <div class="bx-hint" style="margin-top:6px">Tiers go from common at the top to rare at the bottom. That order is what "or better" means for the guarantee.</div>
</div></div>
${roll}
<div class="ad-tiers">${d.tiers.map(tierCard).join('')}</div>
<button class="bx-btn" data-act="tieradd">${I('plus', 15)}Add a tier</button>
<div style="height:60px"></div>`;
    }

    function schedulePage() {
        const sc = (S.live && S.live.schedule) || {};
        const on = setting('Schedule.Enabled') !== false;
        const from = Number(setting('Schedule.Hours.from'));
        const to = Number(setting('Schedule.Hours.to'));
        const need = Number(setting('Schedule.MinPlayers')) || 0;
        const reasons = S.zones.map((z) => {
            const d = z.data;
            let why = '';
            if (d.enabled === false) why = 'Switched off';
            else if (!d.points.length) why = 'No landing points';
            else if ((sc.players || 0) < d.minPlayers) why = `Needs ${d.minPlayers} players`;
            else if ((sc.police || 0) < d.minPolice) why = `Needs ${d.minPolice} police`;
            else if (d.hours.from >= 0 && d.hours.to >= 0 && d.hours.from !== d.hours.to && !((d.hours.from < d.hours.to) ? (sc.hour >= d.hours.from && sc.hour < d.hours.to) : (sc.hour >= d.hours.from || sc.hour < d.hours.to))) why = 'Outside its hours';
            else if (XS.list(S.live.drops).some((x) => x.zoneId === z.id)) why = 'Has a drop running';
            return { z, why };
        });
        const ok = reasons.filter((r) => !r.why).length;
        let status = 'Waiting for the next slot';
        if (!on) status = 'Off. Only staff can call drops.';
        else if (sc.note === 'players' || (sc.players || 0) < need) status = `Waiting for players (${sc.players || 0} of ${need})`;
        else if (sc.note === 'hours') status = 'Outside the active hours';
        else if (sc.note === 'zones' || !ok) status = 'No zone can take a drop right now';
        else if (sc.note === 'full') status = 'At the limit of drops at once';
        return `${head('Schedule', 'When drops happen on their own. Save at the bottom puts it live straight away.', `<button class="bx-btn primary" data-act="quickdrop">${I('chute', 15)}Start one now</button>`)}
<div class="bx-stats ad-schedstats">
  ${stat(on ? 'green' : 'red', on ? 'On' : 'Off', 'Automatic drops', esc(status), 'clock', 'data-act="setting" data-key="Schedule.Enabled"')}
  ${stat('', on && sc.nextIn !== undefined && sc.nextIn !== null ? countdown(sc.nextIn) : '—', 'Next drop in', esc(`${setting('Schedule.MinInterval')}–${setting('Schedule.MaxInterval')} min apart`), 'gauge', '')}
  ${stat((sc.players || 0) >= need ? 'green' : 'amber', `${sc.players || 0} / ${need}`, 'Players online', esc(`${sc.police || 0} police on duty`), 'people', '')}
  ${stat('amber', `${sc.running || 0} / ${sc.max || 1}`, 'Running now', null, 'bolt', 'data-act="nav" data-page="live"')}
</div>
<div class="bx-layout" style="margin-top:16px"><div>
  <div id="bx-schedmount"></div>
</div><div>
  <div class="bx-card"><div class="bx-cardhead"><h3>Active hours</h3><small>${esc(from < 0 || to < 0 || from === to ? 'All day' : `${hourName(from)} until ${hourName(to)}`)}</small></div><div class="bx-cardbody">${hoursBar(from, to, sc.hour)}<div class="bx-hint" style="margin-top:8px">${esc(`Server time is about ${hourName(sc.hour || 0)} now. Zones can narrow this further.`)}</div></div></div>
  <div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Zones right now</h3><small>${esc(`${ok} of ${S.zones.length} can take a drop`)}</small></div><div class="bx-cardbody">
    ${reasons.length ? `<div class="bx-points" style="padding:0">${reasons.map((r) => `<div class="bx-pt" data-act="edit" data-kind="zone" data-id="${r.z.id}" style="cursor:pointer"><span class="bx-dot ${r.why ? 'off' : ''}"></span><div class="bx-ptmain"><b>${esc(r.z.data.label)}</b><small>${esc(r.why || 'Can take a drop')}</small></div>${I('chevron', 13)}</div>`).join('')}</div>` : '<div class="bx-hint">No zones yet.</div>'}
    <div class="bx-hint" style="margin-top:8px">Zone cooldowns are not shown here. The console says why when the schedule skips a slot with Config.Debug on.</div>
  </div></div>
</div></div>`;
    }

    function liveCard(x) {
        const st = STATE[x.state] || [x.state, '', ''];
        const left = x.state === 'announced' || x.state === 'inbound' ? x.landsIn : x.expiresIn;
        let police = '';
        if (x.policeSent) police = 'Police called';
        else if (x.policeIn !== undefined && x.policeIn !== null) police = `Police in ${XS.clock(x.policeIn)}`;
        return `<div class="ad-live ${x.state}">
            <div class="ad-liveh"><span class="bx-chip ${st[1]}">${esc(st[0])}</span>${x.silent ? '<span class="bx-chip off">Silent test</span>' : ''}${x.emptied ? '<span class="bx-chip off">Emptied</span>' : ''}${x.heldOpen ? '<span class="bx-chip warn">Held, people still there</span>' : ''}<span class="bx-sp"></span><span class="bx-hint">${esc(`#${x.id}`)}</span></div>
            <div class="ad-livebody"><div><h3>${esc(x.label)}</h3><p>${esc(`${x.crate} · ${x.loot}`)}</p><p class="bx-mono">${esc(pt(x.coords))}</p></div>
              <div class="ad-clock"><small>${esc(x.emptied ? 'Gone in' : st[2])}</small><b>${countdown(left)}</b></div></div>
            <div class="ad-livefoot"><span>${esc([x.calledBy ? `Called by ${x.calledBy}` : '', x.crackedBy ? `Opened by ${x.crackedBy}` : '', police].filter(Boolean).join(' · ') || 'Nobody has opened it yet')}</span>
              <button class="bx-btn xs" data-act="livego" data-id="${esc(x.id)}">${I('goto', 12)}Teleport</button><button class="bx-btn xs" data-act="livemark" data-id="${esc(x.id)}">${I('map', 12)}Waypoint</button><button class="bx-btn xs danger" data-act="livecancel" data-id="${esc(x.id)}">${I('close', 12)}Cancel</button></div>
        </div>`;
    }

    function livePage() {
        const live = S.live || {};
        const drops = XS.list(live.drops);
        const sc = live.schedule || {};
        const z = S.start.zone ? zoneById(S.start.zone) : null;
        const zc = z ? zoneCrate(z.data) : null;
        const zl = z ? zoneLoot(z.data, zc) : null;
        const ready = S.zones.filter((x) => x.data.points.length);
        return `${head('Live', 'Drops running right now. They update by themselves.', `<button class="bx-btn sm" data-act="liveload">${I('refresh', 14)}Refresh</button>`)}
<div class="bx-layout"><div>
  ${drops.length ? drops.map(liveCard).join('') : `<div class="bx-empty">${I('chute', 30)}<b>Nothing running</b><p>${esc(sc.enabled ? 'The schedule starts one when the time comes, or start one yourself.' : 'The schedule is off, so drops only happen when staff call one.')}</p></div>`}
</div><div>
  <div class="bx-card"><div class="bx-cardhead"><h3>Start a drop</h3><small>${esc(`${drops.length} of ${sc.max || 1} running`)}</small></div><div class="bx-cardbody">
    ${field('Zone', `<select class="bx-input" data-start="zone"><option value="0">Random, by weight</option>${ready.map((x) => `<option value="${x.id}" ${S.start.zone === x.id ? 'selected' : ''}>${esc(x.data.label)}${x.data.enabled === false ? ' (off)' : ''}</option>`).join('')}</select>`)}
    <div class="bx-cols2">${field('Crate type', `<select class="bx-input" data-start="crate"><option value="0">${esc(zc ? `The zone's (${zc.data.label})` : "The zone's")}</option>${S.crates.map((x) => `<option value="${x.id}" ${S.start.crate === x.id ? 'selected' : ''}>${esc(x.data.label)}</option>`).join('')}</select>`)}${field('Loot table', `<select class="bx-input" data-start="loot"><option value="0">${esc(zl ? `The zone's (${zl.data.label})` : "The zone's")}</option>${S.loot.map((x) => `<option value="${x.id}" ${S.start.loot === x.id ? 'selected' : ''}>${esc(x.data.label)}</option>`).join('')}</select>`)}</div>
    <div class="bx-rowline"><div><b>Silent test</b><div class="bx-hint">A real crate only staff can see. No announcement, no police, kept out of the history.</div></div><span class="bx-switch ${S.start.silent ? 'on' : ''}" data-act="startsilent"></span></div>
    <button class="bx-btn primary" style="width:100%;margin-top:12px" data-act="livestart" ${ready.length ? '' : 'disabled'}>${I('chute', 15)}${esc(S.start.silent ? 'Start a silent test' : 'Start the drop')}</button>
  </div></div>
  <div class="bx-card" style="margin-top:14px"><div class="bx-cardbody">
    <div class="bx-rowline"><div><b>Schedule</b><div class="bx-hint">${esc(sc.enabled ? 'Next drop in' : 'Off')}</div></div><b class="bx-mono">${sc.enabled && sc.nextIn !== undefined && sc.nextIn !== null ? countdown(sc.nextIn) : '—'}</b></div>
    <div class="bx-rowline"><div><b>Players / police</b></div><b class="bx-mono">${esc(`${sc.players || 0} / ${sc.police || 0}`)}</b></div>
  </div></div>
</div></div>`;
    }

    function historyPage() {
        const st = S.hstats || {};
        const abandon = st.total ? Math.round(((st.abandoned || 0) / st.total) * 100) : 0;
        const cracked = st.total ? Math.round(((st.cracked || 0) / st.total) * 100) : 0;
        const outcomes = ['all', 'emptied', 'looted out', 'abandoned', 'cancelled'];
        return `${head('History', 'Every drop, what was in it and who opened it. If more than half are abandoned, they land where nobody goes or the loot is not worth the trip.', `<button class="bx-btn sm" data-act="histload">${I('refresh', 14)}Refresh</button>`)}
<div class="bx-stats ad-schedstats">
  ${stat('', st.total || 0, 'Drops all time', null, 'chute', '')}
  ${stat('green', `${cracked}%`, 'Opened', esc(`${st.cracked || 0} crates`), 'box', '')}
  ${stat(abandon > 50 ? 'red' : 'amber', `${abandon}%`, 'Abandoned', esc(`${st.abandoned || 0} crates`), 'alert', '')}
  ${stat('', st.today || 0, 'Today', esc(`${st.crackedToday || 0} opened`), 'clock', '')}
</div>
<div class="bx-listbar" style="margin-top:16px">${outcomes.map((o) => `<button class="bx-btn xs ${S.hOutcome === o ? 'primary' : 'ghost'}" data-act="histfilter" data-k="${esc(o)}">${esc(o === 'all' ? 'All' : (OUTCOME[o] || [o])[0])}</button>`).join('')}</div>
${S.history.length ? `<div class="bx-card"><table class="bx-table"><thead><tr><th>When</th><th>Zone</th><th>Crate</th><th>Called by</th><th>Opened by</th><th>Outcome</th><th class="r">Lasted</th><th class="r">Stacks</th></tr></thead><tbody>
${S.history.map((h) => {
        const o = OUTCOME[h.outcome] || [h.outcome, ''];
        const open = S.hOpen === h.id;
        const rows = XS.list(h.contents);
        return `<tr class="click" data-act="histopen" data-id="${h.id}"><td class="bx-mono" style="white-space:nowrap">${esc(XS.ago(h.age))}</td><td><b>${esc(h.label)}</b></td><td>${esc(h.crate || '—')}<div class="bx-hint">${esc(h.loot || '')}</div></td><td>${esc(h.calledBy || '—')}</td><td>${esc(h.crackedBy || '—')}</td><td><span class="bx-chip ${o[1]}">${esc(o[0])}</span></td><td class="r bx-mono">${esc(h.lasted !== undefined && h.lasted !== null ? XS.span(h.lasted) : '—')}</td><td class="r bx-mono">${rows.length}</td></tr>
        ${open ? `<tr><td colspan="8"><div class="ad-rolls">${rows.map((r) => `<span class="ad-rollit"><b>${esc(r.count)}×</b> ${esc(r.item)}<small>${esc(r.tier || '')}</small></span>`).join('') || '<span class="bx-hint">Nobody opened it, so nothing was rolled.</span>'}</div></td></tr>` : ''}`;
    }).join('')}
</tbody></table></div>` : `<div class="bx-empty">${I('history', 30)}<b>No drops yet</b><p>Silent tests are kept out of the history.</p></div>`}`;
    }

    function accessPage() {
        const a = S.access || {};
        return `${head('Access', 'Who can open this builder and call drops by hand.')}
<div class="bx-layout"><div><div class="bx-card"><div class="bx-cardhead"><h3>Give a group access</h3></div><div class="bx-cardbody">
  <div class="ad-code">add_ace group.admin ${esc(a.ace || 'xs.airdrops')} allow</div>
  <div class="bx-hint" style="margin-top:8px">${esc(`Put that line in server.cfg for every group that should build, then restart the server. Without it /${a.command || 'airdrops'} says you do not have permission.`)}</div>
</div></div>
<div class="bx-card" style="margin-top:14px"><div class="bx-cardhead"><h3>Commands</h3></div><div class="bx-cardbody">
  <div class="bx-rowline"><div><b class="bx-mono">/${esc(a.command || 'airdrops')}</b><div class="bx-hint">Opens this builder.</div></div></div>
  ${a.drop ? `<div class="bx-rowline"><div><b class="bx-mono">/${esc(a.drop)} [zone]</b><div class="bx-hint">Calls a drop now. With a name or #id it drops at that zone, without one it picks by weight. The server console can always use it.</div></div></div>` : '<div class="bx-rowline"><div><b>Calling drops by command is off</b><div class="bx-hint">Config.AdminCommand.Enabled</div></div></div>'}
</div></div></div><div>
<div class="bx-card"><div class="bx-cardhead"><h3>Any one of these lets you in</h3></div><div class="bx-cardbody">
  <div class="bx-rowline"><div><b>Ace permission</b><div class="bx-hint">Config.Admin.acePermission</div></div><span class="bx-chip blue">${esc(a.ace || 'xs.airdrops')}</span></div>
  <div class="bx-rowline"><div><b>Other aces</b><div class="bx-hint">Config.AdminCommand.Aces</div></div><span>${XS.list(a.aces).map((x) => `<span class="bx-chip">${esc(x)}</span>`).join(' ') || '<span class="bx-hint">None</span>'}</span></div>
  <div class="bx-rowline"><div><b>Framework groups</b><div class="bx-hint">Config.Admin.groups</div></div><span>${XS.list(a.groups).map((x) => `<span class="bx-chip">${esc(x)}</span>`).join(' ') || '<span class="bx-hint">None</span>'}</span></div>
  <div class="bx-rowline"><div><b>Licences</b><div class="bx-hint">Config.Admin.licenses</div></div><span class="bx-chip">${esc(`${a.licenses || 0} listed`)}</span></div>
  <div class="bx-hint" style="margin-top:10px">These live in config.lua on purpose. Giving builder access from inside the builder would let anyone with access hand it out.</div>
</div></div></div></div>`;
    }

    function paletteItems() {
        const out = [];
        S.zones.forEach((z) => out.push({ group: 'Drop zones', label: `#${z.id} ${z.data.label}`, sub: `${z.data.points.length} points`, run: () => edit('zone', z.id) }));
        S.crates.forEach((c) => out.push({ group: 'Crate types', label: c.data.label, sub: c.data.model, run: () => edit('crate', c.id) }));
        S.loot.forEach((l) => out.push({ group: 'Loot tables', label: l.data.label, sub: `${XS.list(l.data.tiers).length} tiers`, run: () => edit('loot', l.id) }));
        [['overview', 'Overview'], ['zones', 'Drop zones'], ['crates', 'Crate types'], ['loot', 'Loot tables'], ['schedule', 'Schedule'], ['live', 'Live'], ['history', 'History'], ['settings', 'Settings'], ['access', 'Access']]
            .forEach((x) => out.push({ group: 'Pages', label: x[1], run: () => go(x[0]) }));
        if (XS.BuilderSettings) XS.BuilderSettings.fields().forEach((f) => out.push({ group: 'Settings', label: XS.BuilderSettings.label(f.key), sub: XS.BuilderSettings.sectionLabel(f.section), key: f.key, run: () => openSetting(f.key) }));
        return out;
    }

    function openSetting(key) {
        go('settings').then(() => setTimeout(() => XS.BuilderSettings.focus(key), 30));
    }

    function renderOverlay() {
        const ov = root.querySelector('#bx-ov');
        if (!ov) return;
        const o = S.overlay;
        if (!o) { ov.innerHTML = ''; return; }
        if (o.kind === 'palette') {
            const q = (o.q || '').trim().toLowerCase();
            const all = paletteItems();
            o.list = (q ? all.filter((i) => { const hay = `${i.label} ${i.sub || ''} ${i.group} ${i.key || ''}`.toLowerCase(); return q.split(/\s+/).every((w) => hay.includes(w)); }) : all.slice(0, 30)).slice(0, 60);
            o.idx = Math.min(o.idx || 0, Math.max(0, o.list.length - 1));
            let lastGroup = '';
            ov.innerHTML = `<div class="bx-overlay" data-act="ovclose"><div class="bx-palette" data-stop="1"><div class="bx-palin">${I('search', 17)}<input id="ad-palq" value="${esc(o.q || '')}" placeholder="Search zones, crates, loot, settings and pages" autocomplete="off"></div><div class="bx-palres xsp-scroll">${o.list.map((it, i) => { const g = it.group !== lastGroup ? `<div class="bx-palgroup">${esc(it.group)}</div>` : ''; lastGroup = it.group; return `${g}<button class="bx-palitem ${i === o.idx ? 'hl' : ''}" data-act="palrun" data-i="${i}"><div><b>${esc(it.label)}</b>${it.sub ? `<small>${esc(it.sub)}</small>` : ''}</div></button>`; }).join('') || '<div class="bx-empty" style="border:none">Nothing matches</div>'}</div><div class="bx-palfoot"><span class="bx-kbd">↑↓</span>move<span class="bx-kbd">Enter</span>open<span class="bx-kbd">Esc</span>close</div></div></div>`;
            const input = ov.querySelector('#ad-palq');
            input.focus();
            input.setSelectionRange(input.value.length, input.value.length);
            return;
        }
        if (o.kind === 'modal') {
            ov.innerHTML = `<div class="bx-overlay" data-act="ovclose"><div class="bx-modal" data-stop="1"><h3>${esc(o.title)}</h3><p>${esc(o.text)}</p><div class="acts"><button class="bx-btn ghost" data-act="ovclose">Cancel</button><button class="bx-btn ${o.danger ? 'danger' : 'primary'}" data-act="modalok">${esc(o.ok || 'OK')}</button></div></div></div>`;
        }
    }

    function modal(opts) {
        return new Promise((resolve) => {
            S.overlay = Object.assign({ kind: 'modal' }, opts, { resolve });
            renderOverlay();
        });
    }

    function closeOverlay(result) {
        const o = S.overlay;
        S.overlay = null;
        renderOverlay();
        if (o && o.resolve) o.resolve(result);
    }

    async function confirmLeave() {
        if (!S.dirty) return true;
        const ok = await modal({ title: 'Unsaved changes', text: 'Leave without saving? What you changed here is lost.', ok: 'Leave', danger: true });
        if (ok) { S.dirty = false; S.cur = null; S.curId = null; }
        return !!ok;
    }

    const EDIT_PAGE = { zone: 'zone-edit', crate: 'crate-edit', loot: 'loot-edit' };
    const LIST_PAGE = { zone: 'zones', crate: 'crates', loot: 'loot' };
    const LISTS = { zone: () => S.zones, crate: () => S.crates, loot: () => S.loot };
    const NORM = { zone: normZone, crate: normCrate, loot: normLoot };
    const BLANK = { zone: blankZone, crate: blankCrate, loot: blankLoot };

    async function go(page) {
        if (S.page.endsWith('-edit') && page !== S.page && !(await confirmLeave())) return;
        S.page = page;
        S.pick = null;
        if (page === 'history') loadHistory();
        if (page === 'live' || page === 'schedule' || page === 'overview') loadLive();
        render();
    }

    async function edit(kind, id, tab) {
        if (S.page.endsWith('-edit') && (S.kind !== kind || S.curId !== Number(id)) && !(await confirmLeave())) return;
        const rec = LISTS[kind]().find((r) => r.id === Number(id));
        if (!rec) return;
        S.kind = kind;
        S.cur = NORM[kind](copy(rec.data));
        S.curId = rec.id;
        S.tab = tab || 'general';
        S.page = EDIT_PAGE[kind];
        S.dirty = false;
        S.roll = null;
        S.pick = null;
        render();
    }

    async function create(kind, from) {
        if (S.page.endsWith('-edit') && !(await confirmLeave())) return;
        S.kind = kind;
        S.cur = NORM[kind](from ? copy(from) : BLANK[kind]());
        S.curId = null;
        S.tab = 'general';
        S.page = EDIT_PAGE[kind];
        S.dirty = true;
        S.roll = null;
        if (kind === 'zone' && !from && S.here && S.here.area) S.cur.label = S.here.area;
        if (kind === 'loot' && !from) S.cur.label = 'New loot table';
        if (kind === 'crate' && !from) {
            S.cur.label = 'New crate type';
            S.cur.announce = Object.assign({}, ANNOUNCE);
        }
        render();
    }

    function upsert(kind, rec) {
        if (!rec) return;
        const list = LISTS[kind]();
        const i = list.findIndex((r) => r.id === rec.id);
        if (i >= 0) list[i] = rec; else list.push(rec);
        list.sort((a, b) => a.id - b.id);
    }

    async function save() {
        if (S.page === 'settings' || S.page === 'schedule') {
            const res = await XS.BuilderSettings.save();
            if (res && res.schedule) { S.live.schedule = res.schedule; render(); }
            return;
        }
        if (!S.page.endsWith('-edit') || !S.cur || S.busy) return;
        const a = document.activeElement;
        if (a && a.blur) a.blur();
        if (!String(S.cur.label || '').trim()) { XS.toast('Give it a name first.', 'error'); return; }
        S.busy = true;
        const kind = S.kind;
        const res = await XS.server(`${kind}:save`, { id: S.curId, data: copy(S.cur) });
        S.busy = false;
        if (!res.ok) { XS.toast(res.error, 'error'); render(); return; }
        const rec = kind === 'crate' ? res.data.record : res.data;
        if (kind === 'crate' && res.data.crates) S.crates = XS.list(res.data.crates);
        else upsert(kind, rec);
        S.curId = rec.id;
        S.cur = NORM[kind](copy(rec.data));
        S.dirty = false;
        XS.toast('Saved. It is live now.', 'ok');
        render();
    }

    async function remove() {
        const names = { zone: 'drop zone', crate: 'crate type', loot: 'loot table' };
        const extra = { zone: 'Its landing points go with it.', crate: 'Zones using it switch to the default crate type.', loot: 'Crate types and zones using it switch to the first loot table.' };
        const ok = await modal({ title: `Delete this ${names[S.kind]}?`, text: `${extra[S.kind]} This cannot be undone.`, ok: 'Delete', danger: true });
        if (!ok) return;
        const kind = S.kind;
        const res = await XS.server(`${kind}:delete`, { id: S.curId });
        if (!res.ok) { XS.toast(res.error, 'error'); return; }
        if (kind === 'crate' && res.data && res.data.crates) S.crates = XS.list(res.data.crates);
        else if (kind === 'zone') S.zones = S.zones.filter((z) => z.id !== S.curId);
        else if (kind === 'loot') S.loot = S.loot.filter((z) => z.id !== S.curId);
        S.dirty = false;
        S.cur = null;
        S.curId = null;
        S.page = LIST_PAGE[kind];
        XS.toast('Deleted.', 'ok');
        render();
    }

    async function loadLive() {
        const res = await XS.server('live');
        if (res.ok) { applyLive(res.data); }
    }

    function applyLive(data) {
        S.live = data || S.live;
        if (!S.open) return;
        if (['live', 'overview', 'schedule'].includes(S.page)) {
            const a = document.activeElement;
            if (a && pageEl() && pageEl().contains(a) && (a.tagName === 'INPUT' || a.tagName === 'SELECT' || a.tagName === 'TEXTAREA')) { renderNav(); return; }
            S.keepScroll = true;
            render();
        } else renderNav();
    }

    async function loadHistory() {
        const res = await XS.server('history', { outcome: S.hOutcome, limit: 100 });
        if (res.ok) {
            S.history = XS.list(res.data.rows);
            S.hstats = res.data.stats || {};
            if (S.page === 'history') render();
        }
    }

    function changed(redraw) {
        S.dirty = true;
        if (redraw !== false) { S.keepScroll = true; render(); } else {
            const btn = root.querySelector('[data-act="save"]');
            if (btn) btn.innerHTML = `${I('check', 15)}Save<span class="bx-kbd">Ctrl S</span>`;
        }
    }

    async function startDrop(payload) {
        const res = await XS.server('drop:start', payload);
        if (!res.ok) { XS.toast(res.error, 'error'); return false; }
        XS.toast(payload.silent ? `Silent test started at ${res.data.label}. Only staff can see it.` : `Drop started at ${res.data.label}.`, 'ok');
        if (res.data.live) applyLive(res.data.live);
        return true;
    }

    async function place(origin) {
        const d = S.cur;
        const c = zoneCrate(d);
        const radius = d.radius > 0 ? d.radius : (setting('Drop.ZoneRadius') || 120);
        const approx = d.approx > 0 ? d.approx : (setting('Drop.ApproxBlipRadius') || 250);
        const res = await XS.rpc('b:place', { label: `Landing point for ${d.label || 'this zone'}`, model: c ? c.data.model : 'prop_mil_crate_01', radius, approx, origin, existing: d.points });
        if (!res.ok) { if (res.error && res.error !== 'Cancelled.') XS.toast(res.error, 'error'); return null; }
        return res.data;
    }

    function liveById(id) {
        return XS.list(S.live.drops).find((x) => x.id === id);
    }

    async function onClick(e) {
        const el = e.target.closest('[data-act]');
        if (!el) return;
        if (el.classList.contains('bx-overlay') && e.target !== el) return;
        if (el.tagName === 'TR' && e.target.closest('input,select,textarea,button')) return;
        if (el.disabled) return;
        const act = el.dataset.act;
        const id = el.dataset.id ? Number(el.dataset.id) : null;
        if ((el.tagName === 'INPUT' || el.tagName === 'SELECT') && act !== 'toggle') return;
        switch (act) {
        case 'close': XS.close('builder'); break;
        case 'nav': go(el.dataset.page); break;
        case 'palette': S.overlay = { kind: 'palette', q: '', idx: 0 }; renderOverlay(); break;
        case 'palrun': { const it = S.overlay && S.overlay.list[Number(el.dataset.i)]; closeOverlay(); if (it) it.run(); break; }
        case 'ovclose': closeOverlay(false); break;
        case 'modalok': closeOverlay(true); break;
        case 'setting': openSetting(el.dataset.key); break;
        case 'new': create(el.dataset.kind); break;
        case 'edit': edit(el.dataset.kind, id, el.dataset.tab); break;
        case 'dup': {
            const kind = el.dataset.kind;
            const rec = LISTS[kind]().find((r) => r.id === id);
            if (!rec) break;
            const d = copy(rec.data);
            d.label = `${d.label} copy`;
            if (kind === 'crate') d.isDefault = false;
            create(kind, d);
            break;
        }
        case 'tab': S.tab = el.dataset.tab; S.pick = null; render(); break;
        case 'save': save(); break;
        case 'delete': remove(); break;
        case 'toggle': setPath(S.cur, el.dataset.path, !getPath(S.cur, el.dataset.path)); changed(); break;
        case 'setv': setPath(S.cur, el.dataset.path, el.dataset.v); changed(); break;
        case 'chip': {
            const list = XS.list(getPath(S.cur, el.dataset.path)).slice();
            const v = el.dataset.v;
            const i = list.indexOf(v);
            if (i >= 0) list.splice(i, 1); else list.push(v);
            setPath(S.cur, el.dataset.path, list);
            changed();
            break;
        }
        case 'heading': S.cur.heading = Number(el.dataset.h); changed(); break;
        case 'zfilter': S.zFilter = el.dataset.k; render(); break;
        case 'ptadd': { const p = await place(); if (p) { S.cur.points.push(p); changed(); } break; }
        case 'pthere': {
            const res = await XS.rpc('b:here');
            if (res.ok) {
                S.cur.points.push({ x: res.data.x, y: res.data.y, z: res.data.z });
                if (!S.cur.label && res.data.area) S.cur.label = res.data.area;
                changed();
            }
            break;
        }
        case 'ptre': { const i = Number(el.dataset.i); const p = await place(S.cur.points[i]); if (p) { S.cur.points[i] = p; changed(); } break; }
        case 'ptdel': S.cur.points.splice(Number(el.dataset.i), 1); changed(); break;
        case 'ptgo': { const p = S.cur.points[Number(el.dataset.i)]; if (p) { const r = await XS.rpc('b:teleport', p); if (!r.ok) XS.toast(r.error, 'error'); } break; }
        case 'ptmark': { const p = S.cur.points[Number(el.dataset.i)]; if (p) { XS.rpc('b:waypoint', p); XS.toast('Waypoint set.', 'ok'); } break; }
        case 'showpts': {
            const radius = S.cur.radius > 0 ? S.cur.radius : (setting('Drop.ZoneRadius') || 120);
            XS.rpc('b:showPoints', { points: S.cur.points, radius, label: S.cur.label });
            break;
        }
        case 'showall': {
            const points = [];
            S.zones.forEach((z) => z.data.points.forEach((p) => points.push(p)));
            if (!points.length) { XS.toast('No landing points yet.', 'error'); break; }
            XS.rpc('b:showPoints', { points, radius: setting('Drop.ZoneRadius') || 120, label: 'Every landing point' });
            break;
        }
        case 'zonego': { const z = zoneById(id); const p = z && z.data.points[0]; if (p) { const r = await XS.rpc('b:teleport', p); if (!r.ok) XS.toast(r.error, 'error'); } else XS.toast('That zone has no landing points yet.', 'error'); break; }
        case 'zonetest': startDrop({ zone: id, silent: true }); break;
        case 'zonedrop': {
            if (S.dirty) { XS.toast('Save the zone first.', 'error'); break; }
            startDrop({ zone: id, silent: false });
            break;
        }
        case 'quickdrop': startDrop({ zone: 0, silent: el.dataset.silent === '1' }); break;
        case 'cratedefault': {
            const rec = crateById(id);
            if (!rec) break;
            const d = copy(rec.data);
            d.isDefault = true;
            const res = await XS.server('crate:save', { id, data: d });
            if (!res.ok) { XS.toast(res.error, 'error'); break; }
            S.crates = XS.list(res.data.crates);
            XS.toast(`${d.label} is the default now.`, 'ok');
            render();
            break;
        }
        case 'sprite': S.cur.blip.sprite = Number(el.dataset.id); changed(); break;
        case 'colour': S.cur.blip.colour = Number(el.dataset.id); changed(); break;
        case 'resettext': S.cur.announce = Object.assign({}, ANNOUNCE); changed(); break;
        case 'tieradd': S.cur.tiers.push({ name: `tier ${S.cur.tiers.length + 1}`, weight: 5, colour: PALETTE[S.cur.tiers.length % PALETTE.length], enabled: true, items: [] }); changed(); break;
        case 'tierdel': {
            const t = S.cur.tiers[Number(el.dataset.t)];
            if (t && t.items.length) {
                const ok = await modal({ title: `Remove the ${t.name} tier?`, text: `Its ${t.items.length} items go with it when you save.`, ok: 'Remove', danger: true });
                if (!ok) break;
            }
            if (S.cur.guarantee === (t && t.name)) S.cur.guarantee = '';
            S.cur.tiers.splice(Number(el.dataset.t), 1);
            changed();
            break;
        }
        case 'tiermove': {
            const i = Number(el.dataset.t);
            const j = i + Number(el.dataset.dir);
            if (j < 0 || j >= S.cur.tiers.length) break;
            const tmp = S.cur.tiers[i];
            S.cur.tiers[i] = S.cur.tiers[j];
            S.cur.tiers[j] = tmp;
            changed();
            break;
        }
        case 'itemadd': {
            const t = S.cur.tiers[Number(el.dataset.t)];
            t.items.push({ item: '', min: 1, max: 1, weight: 10, enabled: true });
            changed();
            const input = root.querySelector(`[data-item="${el.dataset.t}.${t.items.length - 1}"]`);
            if (input) input.focus();
            break;
        }
        case 'itemdel': S.cur.tiers[Number(el.dataset.t)].items.splice(Number(el.dataset.i), 1); changed(); break;
        case 'pickitem': {
            const [ti, ii] = el.dataset.at.split('.').map(Number);
            S.cur.tiers[ti].items[ii].item = el.dataset.v;
            S.pick = null;
            changed();
            break;
        }
        case 'lootroll': {
            const res = await XS.server('loot:test', { data: copy(S.cur), count: 1 });
            if (!res.ok) { XS.toast(res.error, 'error'); break; }
            S.roll = XS.list(res.data)[0] || [];
            S.keepScroll = true;
            render();
            break;
        }
        case 'rollclose': S.roll = null; S.keepScroll = true; render(); break;
        case 'startsilent': S.start.silent = !S.start.silent; S.keepScroll = true; render(); break;
        case 'livestart': startDrop({ zone: S.start.zone, crate: S.start.crate, loot: S.start.loot, silent: S.start.silent }); break;
        case 'liveload': loadLive(); break;
        case 'livego': { const x = liveById(el.dataset.id); if (x) { const r = await XS.rpc('b:teleport', x.coords); if (!r.ok) XS.toast(r.error, 'error'); } break; }
        case 'livemark': { const x = liveById(el.dataset.id); if (x) { XS.rpc('b:waypoint', x.coords); XS.toast('Waypoint set.', 'ok'); } break; }
        case 'livecancel': {
            const x = liveById(el.dataset.id);
            const ok = await modal({ title: 'Cancel this drop?', text: `The crate at ${x ? x.label : 'the zone'} goes away for everyone, with whatever is still in it.`, ok: 'Cancel the drop', danger: true });
            if (!ok) break;
            const res = await XS.server('drop:cancel', { id: el.dataset.id });
            if (!res.ok) { XS.toast(res.error, 'error'); break; }
            applyLive(res.data);
            XS.toast('Cancelled.', 'ok');
            break;
        }
        case 'histload': loadHistory(); break;
        case 'histfilter': S.hOutcome = el.dataset.k; loadHistory(); render(); break;
        case 'histopen': S.hOpen = S.hOpen === id ? null : id; S.keepScroll = true; render(); break;
        default: break;
        }
    }

    function pickList(q) {
        const s = String(q || '').trim().toLowerCase();
        const out = [];
        for (const it of S.items) {
            if (!s || it.name.toLowerCase().includes(s) || String(it.label).toLowerCase().includes(s)) out.push(it);
            if (out.length >= 30) break;
        }
        return out;
    }

    function renderPick() {
        root.querySelectorAll('[data-pop]').forEach((p) => p.classList.add('xsp-hidden'));
        if (!S.pick || !S.items.length) return;
        const pop = root.querySelector(`[data-pop="${S.pick.at}"]`);
        if (!pop) return;
        const list = pickList(S.pick.q);
        S.pick.list = list;
        S.pick.idx = Math.min(S.pick.idx || 0, Math.max(0, list.length - 1));
        pop.innerHTML = list.length ? list.map((it, i) => `<button class="bx-pickopt ${i === S.pick.idx ? 'hl' : ''}" data-act="pickitem" data-at="${S.pick.at}" data-v="${esc(it.name)}"><span class="bx-thumb">${itemImage(it.name)}${I('box', 13)}</span><div><b>${esc(it.label)}</b><small>${esc(it.name)}</small></div></button>`).join('')
            : `<div class="bx-hint" style="padding:8px">${esc(`Nothing called "${S.pick.q}" on this server. You can still use it.`)}</div>`;
        pop.classList.remove('xsp-hidden');
    }

    function onFocus(e) {
        const el = e.target;
        if (el.dataset && el.dataset.item !== undefined) {
            S.pick = { at: el.dataset.item, q: el.value, idx: 0 };
            renderPick();
        }
    }

    function itemHint(at) {
        const input = root.querySelector(`[data-item="${at}"]`);
        const hint = input && input.parentElement.querySelector('.ad-iname');
        if (!hint) return;
        const v = input.value;
        const known = !v || !S.items.length || S.itemSet.has(v) || S.itemSet.has(v.toLowerCase());
        hint.classList.toggle('missing', !known);
        hint.textContent = known ? (itemLabel(v) || (v ? '' : 'Pick an item')) : 'Not on this server';
    }

    function onBlur(e) {
        const el = e.target;
        if (el.dataset && el.dataset.item !== undefined) {
            const at = el.dataset.item;
            if (S.pick && S.pick.at === at) S.pick = null;
            renderPick();
            itemHint(at);
        }
    }

    function onInput(e) {
        const el = e.target;
        if (el.id === 'ad-palq') { S.overlay.q = el.value; S.overlay.idx = 0; renderOverlay(); return; }
        if (el.id === 'ad-zq') {
            S.zq = el.value;
            const pos = el.selectionStart;
            render();
            const again = root.querySelector('#ad-zq');
            if (again) { again.focus(); again.setSelectionRange(pos, pos); }
            return;
        }
        if (el.dataset.item !== undefined) {
            const [ti, ii] = el.dataset.item.split('.').map(Number);
            const v = el.value.replace(/[^A-Za-z0-9_.-]/g, '');
            S.cur.tiers[ti].items[ii].item = v;
            S.pick = { at: el.dataset.item, q: v, idx: 0 };
            S.dirty = true;
            renderPick();
            const btn = root.querySelector('[data-act="save"]');
            if (btn) btn.innerHTML = `${I('check', 15)}Save<span class="bx-kbd">Ctrl S</span>`;
            return;
        }
        if (el.dataset.path && S.cur && el.type !== 'color') {
            let v = el.value;
            if (el.dataset.num || el.type === 'number') v = el.value === '' ? 0 : Number(el.value);
            setPath(S.cur, el.dataset.path, v);
            changed(false);
        }
    }

    function later() {
        if (S.pointer) { S.pendingRender = true; return; }
        setTimeout(() => { S.keepScroll = true; render(); }, 0);
    }

    function onChange(e) {
        const el = e.target;
        if (el.id === 'ad-zcrate') { S.zCrate = Number(el.value); render(); return; }
        if (el.dataset.start) { S.start[el.dataset.start] = Number(el.value); S.keepScroll = true; render(); return; }
        if (el.type === 'color' && el.dataset.path && S.cur) { setPath(S.cur, el.dataset.path, el.value); changed(); return; }
        if ((el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') && el.dataset.path && S.cur && S.page.endsWith('-edit')) {
            if (el.dataset.path.endsWith('.name') && S.kind === 'loot') {
                const ti = Number(el.dataset.path.split('.')[1]);
                if (S.cur.guarantee && !S.cur.tiers.some((t) => t.name === S.cur.guarantee)) S.cur.guarantee = S.cur.tiers[ti].name;
            }
            later();
            return;
        }
        if (el.tagName === 'SELECT' && el.dataset.path && S.cur) {
            let v = el.value;
            if (el.dataset.num) v = Number(v);
            setPath(S.cur, el.dataset.path, v);
            changed();
        }
    }

    function onKey(e) {
        if (S.overlay && S.overlay.kind === 'palette') {
            const o = S.overlay;
            if (e.key === 'ArrowDown') { o.idx = Math.min((o.list || []).length - 1, (o.idx || 0) + 1); renderOverlay(); e.preventDefault(); return; }
            if (e.key === 'ArrowUp') { o.idx = Math.max(0, (o.idx || 0) - 1); renderOverlay(); e.preventDefault(); return; }
            if (e.key === 'Enter') { const it = (o.list || [])[o.idx || 0]; closeOverlay(); if (it) it.run(); e.preventDefault(); return; }
        }
        if (e.key === 'Enter' && S.overlay && S.overlay.kind === 'modal') { closeOverlay(true); e.preventDefault(); return; }
        if (S.pick && e.target.dataset && e.target.dataset.item !== undefined) {
            if (e.key === 'ArrowDown') { S.pick.idx = Math.min((S.pick.list || []).length - 1, (S.pick.idx || 0) + 1); renderPick(); e.preventDefault(); return; }
            if (e.key === 'ArrowUp') { S.pick.idx = Math.max(0, (S.pick.idx || 0) - 1); renderPick(); e.preventDefault(); return; }
            if (e.key === 'Enter') {
                const it = (S.pick.list || [])[S.pick.idx || 0];
                const [ti, ii] = S.pick.at.split('.').map(Number);
                if (it) S.cur.tiers[ti].items[ii].item = it.name;
                S.pick = null;
                changed();
                e.preventDefault();
                return;
            }
        }
        if (e.target.dataset && e.target.dataset.addchip && e.key === 'Enter') {
            const v = e.target.value.toLowerCase().replace(/[^a-z0-9_-]/g, '');
            if (v) {
                const list = XS.list(getPath(S.cur, e.target.dataset.addchip)).slice();
                if (!list.includes(v)) list.push(v);
                setPath(S.cur, e.target.dataset.addchip, list);
                changed();
            }
            e.preventDefault();
            return;
        }
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 'k') { S.overlay = { kind: 'palette', q: '', idx: 0 }; renderOverlay(); e.preventDefault(); return; }
        if ((e.ctrlKey || e.metaKey) && e.key.toLowerCase() === 's') { save(); e.preventDefault(); }
    }

    function apply(data, keep) {
        data = XS.fix(data || {});
        S.zones = XS.list(data.zones).map((z) => Object.assign(z, { data: normZone(z.data) }));
        S.crates = XS.list(data.crates);
        S.loot = XS.list(data.loot);
        S.live = data.live || S.live;
        S.live.drops = XS.list(S.live.drops);
        S.system = data.system || {};
        S.access = data.access || {};
        S.items = XS.list(data.items);
        S.itemSet = new Set(S.items.map((i) => i.name).concat(S.items.map((i) => String(i.name).toLowerCase())));
        S.jobs = XS.list(data.jobs);
        S.gangs = XS.list(data.gangs);
        S.me = data.me || {};
        if (data.here) S.here = data.here;
        XS.BuilderSettings.load({ settings: data.settings || {}, jobs: S.jobs, gangs: S.gangs });
        if (!keep) {
            S.page = 'overview';
            S.cur = null;
            S.curId = null;
        }
    }

    XS.apps.builder = {
        isOpen: () => S.open,
        escape() {
            if (S.overlay) { closeOverlay(false); return; }
            if (S.pick) { S.pick = null; renderPick(); return; }
            XS.close('builder');
        },
        on(action, data) {
            if (action === 'open') {
                const keep = S.dirty && S.cur && S.page.endsWith('-edit');
                apply(data, keep);
                S.open = true;
                shell();
                XS.show('xsp-builder', true);
                if (S.page === 'history') loadHistory();
                render();
            } else if (action === 'live') {
                const d = XS.fix(data || {});
                d.drops = XS.list(d.drops);
                applyLive(d);
            } else if (action === 'show') {
                XS.show('xsp-builder', true);
            } else if (action === 'hide') {
                XS.show('xsp-builder', false);
            } else if (action === 'close') {
                S.open = false;
                S.overlay = null;
                S.pick = null;
                XS.show('xsp-builder', false);
            }
        },
        state: () => S,
    };

    root.addEventListener('click', onClick);
    root.addEventListener('input', onInput);
    root.addEventListener('change', onChange);
    root.addEventListener('focusin', onFocus);
    root.addEventListener('focusout', onBlur);
    root.addEventListener('mousedown', (e) => {
        S.pointer = true;
        if (e.target.closest('[data-act="pickitem"]')) e.preventDefault();
    }, true);
    window.addEventListener('mouseup', () => {
        setTimeout(() => {
            S.pointer = false;
            if (S.pendingRender) {
                S.pendingRender = false;
                S.keepScroll = true;
                render();
            }
        }, 0);
    }, true);
    window.addEventListener('keydown', (e) => { if (S.open && !root.classList.contains('xsp-hidden')) onKey(e); });
})();
