(() => {
    const esc = XS.esc;
    let ctx = null;
    let el = null;
    let draft = {};
    let section = 'all';
    let query = '';
    let onlyChanged = false;
    let busy = false;
    let flash = null;
    let onChange = null;
    let mode = null;

    const copy = (v) => (v === undefined ? undefined : JSON.parse(JSON.stringify(v)));
    const fields = () => ctx.sections.reduce((all, s) => all.concat(s.fields), []);
    const defOf = (key) => fields().find((f) => f.key === key);
    const label = (key) => { const d = defOf(key); return (d && d.label) || key; };
    const hint = (key) => { const d = defOf(key); return (d && d.help) || ''; };
    const sectionOf = (id) => ctx.sections.find((s) => s.id === id) || {};
    const sectionLabel = (id) => sectionOf(id).label || id;
    const current = (key) => (Object.prototype.hasOwnProperty.call(draft, key) ? draft[key] : ctx.values[key]);
    const changed = (key) => !same(current(key), ctx.defaults[key]);
    const pending = () => Object.keys(draft).filter((k) => !same(draft[k], ctx.values[k]));
    const hourName = (n) => (Number(n) < 0 ? 'Any time' : `${String(n).padStart(2, '0')}:00`);

    function same(a, b) {
        if (Array.isArray(a) || Array.isArray(b)) {
            const x = XS.list(a);
            const y = XS.list(b);
            return x.length === y.length && x.every((v, i) => same(v, y[i]));
        }
        if (typeof a === 'number' && typeof b === 'number') return Math.abs(a - b) < 1e-9;
        return a === b;
    }

    function truthy(v) {
        if (Array.isArray(v)) return v.length > 0;
        return v !== false && v !== undefined && v !== null && v !== '' && v !== 0;
    }

    function live(def, depth) {
        if (!def.needs || (depth || 0) > 6) return true;
        const cmp = /^([\w.]+)(!?=)(.*)$/.exec(def.needs);
        let key;
        if (cmp) {
            key = cmp[1];
            const isSame = String(current(key)) === cmp[3];
            if (cmp[2] === '=' ? !isSame : isSame) return false;
        } else {
            const neg = def.needs.charAt(0) === '!';
            key = neg ? def.needs.slice(1) : def.needs;
            const on = truthy(current(key));
            if (neg ? on : !on) return false;
        }
        const parent = defOf(key);
        return !parent || live(parent, (depth || 0) + 1);
    }

    function optionLabel(def, o) {
        return (def.labels && def.labels[o]) || o;
    }

    function colourName(id) {
        const c = XS.BLIPS && XS.BLIPS.colours.find((x) => x.id === Number(id));
        return c ? `${id} · ${c.label}` : String(id);
    }

    function fmt(def, v) {
        if (v === undefined || v === null) return '—';
        if (def.type === 'bool') return v ? 'On' : 'Off';
        if (def.type === 'list') return XS.list(v).join(', ') || 'None';
        if (def.type === 'hour') return hourName(v);
        if (def.type === 'colour') return colourName(v);
        if (def.type === 'select') return optionLabel(def, v);
        if (def.type === 'text' && v === '') return 'empty';
        return `${v}${def.unit ? ` ${def.unit}` : ''}`;
    }

    function control(def) {
        const v = current(def.key);
        const k = esc(def.key);
        const off = !live(def);
        switch (def.type) {
        case 'bool':
            return `<span class="bx-switch ${v ? 'on' : ''} ${off ? 'dis' : ''}" data-bool="${k}"></span>`;
        case 'int':
        case 'num':
            return `<div class="bx-unit"><input type="number" data-num="${k}" value="${esc(v)}" min="${def.min !== undefined ? def.min : ''}" max="${def.max !== undefined ? def.max : ''}" step="${def.step || 1}" ${off ? 'disabled' : ''}>${def.unit ? `<em>${esc(def.unit)}</em>` : ''}<button data-step="${k}" data-dir="-1" ${off ? 'disabled' : ''}>−</button><button data-step="${k}" data-dir="1" ${off ? 'disabled' : ''}>+</button></div>`;
        case 'hour': {
            let opts = `<option value="-1" ${Number(v) < 0 ? 'selected' : ''}>Any time</option>`;
            for (let n = 0; n < 24; n++) opts += `<option value="${n}" ${Number(v) === n ? 'selected' : ''}>${hourName(n)}</option>`;
            return `<select class="bx-input" data-hour="${k}" ${off ? 'disabled' : ''}>${opts}</select>`;
        }
        case 'colour': {
            const list = (XS.BLIPS && XS.BLIPS.colours) || [];
            const hit = list.find((c) => c.id === Number(v));
            return `<span class="ad-swatch" style="background:${esc(hit ? hit.hex : '#555')}"></span><select class="bx-input" data-colour="${k}" ${off ? 'disabled' : ''}>${list.map((c) => `<option value="${c.id}" ${c.id === Number(v) ? 'selected' : ''}>${esc(`${c.id} · ${c.label}`)}</option>`).join('')}</select>`;
        }
        case 'select':
            return `<select class="bx-input" data-select="${k}" ${off ? 'disabled' : ''}>${XS.list(def.options).map((o) => `<option value="${esc(o)}" ${o === v ? 'selected' : ''}>${esc(optionLabel(def, o))}</option>`).join('')}</select>`;
        case 'text':
            return `<input class="bx-input ${def.slug ? 'mono' : ''}" data-text="${k}" maxlength="${def.max || 64}" value="${esc(v)}" ${off ? 'disabled' : ''}>`;
        case 'list':
            return `<div class="bx-tags" data-tags="${k}">${XS.list(v).map((x, i) => `<span class="bx-tagx">${esc(x)}<button data-untag="${k}" data-i="${i}" ${off ? 'disabled' : ''}>${XS.icon('close', 10)}</button></span>`).join('')}<input data-tagin="${k}" list="bs-groups" placeholder="Type, then Enter" ${off ? 'disabled' : ''}></div>`;
        default:
            return '';
        }
    }

    function row(def) {
        const isChanged = changed(def.key);
        return `<div class="bx-setrow ${isChanged ? 'changed' : ''} ${live(def) ? '' : 'dim'} ${flash === def.key ? 'hit' : ''}" data-row="${esc(def.key)}">
            <div class="bx-setinfo"><b>${esc(label(def.key))}</b>
                ${hint(def.key) ? `<p>${esc(hint(def.key))}</p>` : ''}
                ${isChanged ? `<span class="bx-default">${esc(`config.lua: ${fmt(def, ctx.defaults[def.key])}`)} · <button data-reset="${esc(def.key)}">Reset</button></span>` : ''}
            </div>
            <div class="bx-setctl">${control(def)}</div>
        </div>`;
    }

    function matches(def) {
        if (onlyChanged && !changed(def.key)) return false;
        if (!query) return true;
        const hay = `${label(def.key)} ${hint(def.key)} ${def.key} ${sectionLabel(def.section)}`.toLowerCase();
        return query.split(/\s+/).every((w) => hay.includes(w));
    }

    function sectionBlock(s, list) {
        const secChanged = s.fields.filter((f) => changed(f.key)).length;
        return `<section class="bx-setsec" data-sec="${esc(s.id)}">
            <div class="bx-setsech"><span class="bx-kindico">${XS.icon(s.icon, 17)}</span><div style="flex:1;min-width:0"><h2>${esc(s.label || s.id)}</h2>${s.help ? `<p>${esc(s.help)}</p>` : ''}</div>
            ${secChanged ? `<button class="bx-btn xs ghost" data-resetsec="${esc(s.id)}">${XS.icon('undo', 13)}Reset section</button>` : ''}</div>
            ${list.map(row).join('')}
        </section>`;
    }

    function saveBar() {
        const p = pending();
        if (!p.length) return '';
        return `<div class="bx-savebar"><span><b>${p.length}</b> unsaved</span><button class="bx-btn sm ghost" id="bs-discard">Discard</button><button class="bx-btn sm primary" id="bs-save">${XS.icon('check', 14)}Save changes<span class="bx-kbd">Ctrl S</span></button></div>`;
    }

    function groupsList() {
        return `<datalist id="bs-groups">${XS.list(ctx.jobs).concat(XS.list(ctx.gangs)).map((j) => `<option value="${esc(j.name)}">${esc(j.label)}</option>`).join('')}</datalist>`;
    }

    function render() {
        if (!el) return;
        const scroller = el.closest('.xsp-scroll');
        const top = scroller ? scroller.scrollTop : 0;
        if (mode && mode.only) {
            el.innerHTML = `${groupsList()}${ctx.sections.filter((s) => mode.only.includes(s.id)).map((s) => sectionBlock(s, s.fields)).join('')}${saveBar()}`;
            bind();
            if (scroller) scroller.scrollTop = top;
            if (onChange) onChange();
            return;
        }
        const all = fields();
        const changedCount = all.filter((f) => changed(f.key)).length;
        const searching = query || onlyChanged;
        const shown = ctx.sections.filter((s) => searching || section === 'all' || s.id === section).map((s) => {
            const list = s.fields.filter(matches);
            return list.length ? sectionBlock(s, list) : '';
        }).join('');
        el.innerHTML = `${groupsList()}
            <div class="bx-pagehead"><div><h1>Settings</h1><p>How every drop behaves. Saving puts it live for everyone straight away, no restart. Anything you change here wins over config.lua.</p></div></div>
            <div class="bx-setbar">
                <div class="bx-filter">${XS.icon('search', 15)}<input class="bx-input" id="bs-q" value="${esc(query)}" placeholder="${esc(`Search ${all.length} settings`)}"></div>
                <label class="bx-toggle" id="bs-only"><span class="bx-switch ${onlyChanged ? 'on' : ''}"></span>Only changed</label>
                <span class="bx-sp"></span>
                <span class="bx-chip ${changedCount ? 'warn' : ''}">${changedCount} changed from config.lua</span>
            </div>
            <div class="bx-set">
                <div class="bx-setnav">
                    <button class="${section === 'all' && !searching ? 'on' : ''}" data-sec-go="all">${XS.icon('sliders', 15)}<span>All settings</span></button>
                    ${ctx.sections.map((s) => {
                        const n = s.fields.filter((f) => changed(f.key)).length;
                        return `<button class="${section === s.id && !searching ? 'on' : ''}" data-sec-go="${esc(s.id)}">${XS.icon(s.icon, 15)}<span>${esc(s.label || s.id)}</span>${n ? `<em>${n}</em>` : ''}</button>`;
                    }).join('')}
                </div>
                <div>${shown || `<div class="bx-empty">${XS.icon('search', 28)}<b>Nothing matches</b><p>Try another word, or turn off Only changed.</p></div>`}<div style="height:70px"></div></div>
            </div>
            ${saveBar()}`;
        bind();
        if (scroller) scroller.scrollTop = top;
        if (flash) {
            const hit = el.querySelector(`[data-row="${CSS.escape(flash)}"]`);
            if (hit) hit.scrollIntoView({ block: 'center' });
            flash = null;
        }
        if (onChange) onChange();
    }

    function set(key, value) {
        draft[key] = value;
        if (same(value, ctx.values[key])) delete draft[key];
        render();
    }

    function addTag(key, raw) {
        const def = defOf(key);
        let v = String(raw || '').trim();
        if (!v) return;
        const list = XS.list(current(key)).slice();
        if (def.slug) v = v.toLowerCase().replace(/[^a-z0-9_-]/g, '');
        if (v && !list.includes(v) && list.length < (def.max || 30)) list.push(v);
        set(key, list);
        const again = el.querySelector(`[data-tagin="${CSS.escape(key)}"]`);
        if (again) again.focus();
    }

    function clampNum(def, raw) {
        let n = Number(raw);
        if (!Number.isFinite(n)) n = Number(ctx.values[def.key]) || 0;
        if (def.type === 'int') n = Math.round(n);
        else n = Math.round(n / (def.step || 0.1)) * (def.step || 0.1);
        n = Math.round(n * 1000) / 1000;
        if (def.min !== undefined) n = Math.max(def.min, n);
        if (def.max !== undefined) n = Math.min(def.max, n);
        return n;
    }

    function bind() {
        const q = el.querySelector('#bs-q');
        if (q) {
            q.addEventListener('input', () => {
                query = q.value.trim().toLowerCase();
                const pos = q.selectionStart;
                render();
                const again = el.querySelector('#bs-q');
                again.focus();
                again.setSelectionRange(pos, pos);
            });
        }
        const only = el.querySelector('#bs-only');
        if (only) only.addEventListener('click', () => { onlyChanged = !onlyChanged; render(); });
        el.querySelectorAll('[data-sec-go]').forEach((b) => b.addEventListener('click', () => {
            section = b.dataset.secGo;
            query = '';
            onlyChanged = false;
            render();
            const scroller = el.closest('.xsp-scroll');
            if (scroller) scroller.scrollTop = 0;
        }));
        el.querySelectorAll('[data-bool]').forEach((s) => s.addEventListener('click', () => {
            if (s.classList.contains('dis')) return;
            set(s.dataset.bool, !current(s.dataset.bool));
        }));
        el.querySelectorAll('[data-num]').forEach((i) => i.addEventListener('change', () => set(i.dataset.num, clampNum(defOf(i.dataset.num), i.value))));
        el.querySelectorAll('[data-step]').forEach((b) => b.addEventListener('click', () => {
            const def = defOf(b.dataset.step);
            set(def.key, clampNum(def, (Number(current(def.key)) || 0) + Number(b.dataset.dir) * (def.step || 1)));
        }));
        el.querySelectorAll('[data-hour]').forEach((s) => s.addEventListener('change', () => set(s.dataset.hour, Number(s.value))));
        el.querySelectorAll('[data-colour]').forEach((s) => s.addEventListener('change', () => set(s.dataset.colour, Number(s.value))));
        el.querySelectorAll('[data-select]').forEach((s) => s.addEventListener('change', () => set(s.dataset.select, s.value)));
        el.querySelectorAll('[data-text]').forEach((i) => i.addEventListener('change', () => {
            const def = defOf(i.dataset.text);
            let v = i.value.trim();
            if (def.slug) v = v.toLowerCase().replace(/[^a-z0-9_-]/g, '');
            if (!v && !def.empty) { render(); return; }
            set(def.key, v.slice(0, def.max || 64));
        }));
        el.querySelectorAll('[data-tagin]').forEach((i) => {
            i.addEventListener('keydown', (e) => {
                if (e.key === 'Enter' || e.key === ',') { e.preventDefault(); addTag(i.dataset.tagin, i.value); }
                if (e.key === 'Backspace' && !i.value) {
                    const list = XS.list(current(i.dataset.tagin)).slice();
                    if (list.length) { list.pop(); set(i.dataset.tagin, list); const again = el.querySelector(`[data-tagin="${CSS.escape(i.dataset.tagin)}"]`); if (again) again.focus(); }
                }
            });
            i.addEventListener('change', () => { if (i.value) addTag(i.dataset.tagin, i.value); });
        });
        el.querySelectorAll('[data-tags]').forEach((box) => box.addEventListener('click', (e) => { if (e.target === box) { const i = box.querySelector('input'); if (i) i.focus(); } }));
        el.querySelectorAll('[data-untag]').forEach((b) => b.addEventListener('click', () => {
            const list = XS.list(current(b.dataset.untag)).slice();
            list.splice(Number(b.dataset.i), 1);
            set(b.dataset.untag, list);
        }));
        el.querySelectorAll('[data-reset]').forEach((b) => b.addEventListener('click', () => set(b.dataset.reset, copy(ctx.defaults[b.dataset.reset]))));
        el.querySelectorAll('[data-resetsec]').forEach((b) => b.addEventListener('click', () => {
            const sec = ctx.sections.find((s) => s.id === b.dataset.resetsec);
            sec.fields.forEach((f) => {
                draft[f.key] = copy(ctx.defaults[f.key]);
                if (same(draft[f.key], ctx.values[f.key])) delete draft[f.key];
            });
            render();
        }));
        const discard = el.querySelector('#bs-discard');
        if (discard) discard.addEventListener('click', () => { draft = {}; render(); });
        const save = el.querySelector('#bs-save');
        if (save) save.addEventListener('click', () => XS.BuilderSettings.save());
    }

    XS.BuilderSettings = {
        load(data) {
            const s = data.settings || {};
            ctx = {
                sections: XS.list(s.sections).map((sec) => Object.assign(sec, { fields: XS.list(sec.fields).map((f) => Object.assign(f, { options: XS.list(f.options) })) })),
                values: s.values || {}, defaults: s.defaults || {},
                jobs: XS.list(data.jobs), gangs: XS.list(data.gangs),
            };
            Object.keys(draft).forEach((k) => { if (same(draft[k], ctx.values[k])) delete draft[k]; });
        },
        mount(target, cb, opts) {
            el = target;
            onChange = cb;
            mode = opts || null;
            render();
        },
        unmount() { el = null; mode = null; },
        fields: () => (ctx ? fields() : []),
        label,
        sectionLabel,
        changedCount: () => (ctx ? fields().filter((f) => changed(f.key)).length : 0),
        isDirty: () => !!ctx && pending().length > 0,
        focus(key) {
            const def = defOf(key);
            if (!def) return;
            section = def.section;
            query = '';
            onlyChanged = false;
            flash = key;
            if (el) render();
        },
        value: (key) => (ctx ? current(key) : undefined),
        saved: (key) => (ctx ? ctx.values[key] : undefined),
        async save() {
            const a = document.activeElement;
            if (a && a !== document.body && el && el.contains(a) && a.blur) a.blur();
            if (busy || !ctx) return false;
            const keys = pending();
            if (!keys.length) return false;
            const changes = {};
            keys.forEach((k) => { changes[k] = draft[k]; });
            busy = true;
            const res = await XS.server('settings:save', { changes, resets: [] });
            busy = false;
            if (!res.ok) { XS.toast(res.error, 'error'); return false; }
            ctx.values = (res.data && res.data.values) || Object.assign({}, ctx.values, changes);
            draft = {};
            XS.toast(`Saved ${keys.length} setting${keys.length === 1 ? '' : 's'}. They are live now.`, 'ok');
            render();
            if (mode && mode.onSaved) mode.onSaved(res.data);
            return res.data;
        },
    };
})();
