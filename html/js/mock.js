(() => {
    if (typeof GetParentResourceName === 'function') return;
    if (location.hostname.toLowerCase() === RESOURCE.toLowerCase()) return;

    const send = (app, action, data) => window.dispatchEvent(new MessageEvent('message', { data: { app, action, data } }));
    const params = new URLSearchParams(location.search);
    if (params.get('bg') !== 'none') document.documentElement.style.background = 'linear-gradient(160deg,#7a7066 0%,#3f3a35 45%,#1d1b19 100%)';
    const copy = (v) => JSON.parse(JSON.stringify(v));
    const reply = (data) => ({ ok: true, data });
    const fail = (error) => ({ ok: false, error });

    const ANN = {
        inbound: 'Supply drop inbound{near}. It lands in {seconds} seconds.',
        landed: 'The crate has landed{near}.',
        opened: '{name} has opened the crate.',
        emptied: 'The crate has been emptied.',
    };
    const P = (x, y, z) => ({ x, y, z });
    const crate = (o) => Object.assign({
        label: '', isDefault: false, model: 'prop_mil_crate_01', crackTime: 25, stacksPerSearch: 2, searchesPerPlayer: 0, slots: 12, maxWeight: 80000, loot: 0,
        access: { rule: 'default', jobs: [], gangs: [], police: 'default' }, flyover: true, parachute: true, flare: true, smoke: true, plane: 'titan', altitude: 320,
        police: { alert: true, delay: 45 }, announce: Object.assign({}, ANN), blip: { sprite: 478, colour: 5, label: 'Supply Drop' }, notes: '',
    }, o);
    const zone = (o) => Object.assign({ label: '', enabled: true, points: [], radius: 0, approx: 0, crate: 0, loot: 0, weight: 5, minPlayers: 0, minPolice: 0, hours: { from: -1, to: -1 }, heading: -1, see: { rule: 'default', jobs: [], gangs: [] }, notes: '' }, o);
    const it = (item, min, max, weight) => ({ item, min, max, weight: weight || 10, enabled: true });

    const DB = {
        nextId: { zone: 5, crate: 3, loot: 3 },
        zones: [
            { id: 1, data: zone({ label: 'Sandy Shores Airfield', points: [P(1708.4, 3254.1, 41.0), P(1622.9, 3229.7, 40.4), P(1761.2, 3297.5, 41.1)], weight: 8, heading: 315, notes: 'Open runway, three ways in.' }) },
            { id: 2, data: zone({ label: 'Grapeseed Fields', points: [P(2141.6, 4785.3, 40.9), P(2052.8, 4848.1, 41.6)], radius: 160, crate: 2, minPlayers: 12, minPolice: 2, hours: { from: 20, to: 4 }, heading: 270, see: { rule: 'except', jobs: ['police', 'sheriff'], gangs: [] } }) },
            { id: 3, data: zone({ label: 'Paleto Forest', points: [], weight: 4 }) },
            { id: 4, data: zone({ label: 'Port of Los Santos', enabled: false, points: [P(1020.7, -3125.4, 5.9)], crate: 2, loot: 2 }) },
        ],
        crates: [
            { id: 1, data: crate({ label: 'Standard crate', isDefault: true, loot: 1 }) },
            { id: 2, data: crate({ label: 'Military cache', model: 'prop_drop_armscrate_01', crackTime: 40, loot: 2, plane: 'cargoplane', altitude: 420, access: { rule: 'groups', jobs: [], gangs: ['ballas', 'families'], police: 'deny' }, police: { alert: true, delay: 30 }, blip: { sprite: 556, colour: 1, label: 'Military Cache' }, smoke: false }) },
        ],
        loot: [
            { id: 1, data: { label: 'Standard loot', minStacks: 4, maxStacks: 7, guarantee: 'uncommon', notes: '', tiers: [
                { name: 'common', weight: 60, colour: '#9aa0a8', enabled: true, items: [it('bandage', 2, 5), it('water_bottle', 2, 6), it('sandwich', 2, 6), it('plastic', 5, 15), it('metalscrap', 5, 15)] },
                { name: 'uncommon', weight: 28, colour: '#4c9aff', enabled: true, items: [it('lockpick', 1, 3), it('advancedlockpick', 1, 2), it('radio', 1, 1), it('firstaid', 1, 2), it('steel', 5, 12)] },
                { name: 'rare', weight: 10, colour: '#c084fc', enabled: true, items: [it('weapon_pistol', 1, 1), it('pistol_ammo', 12, 30), it('thermite', 1, 1), it('trojan_usb', 1, 1)] },
                { name: 'legendary', weight: 2, colour: '#f5a524', enabled: true, items: [it('weapon_assaultrifle', 1, 1), it('rifle_ammo', 30, 60), it('goldbar', 1, 2)] },
            ] } },
            { id: 2, data: { label: 'Weapons cache', minStacks: 2, maxStacks: 4, guarantee: 'heavy', notes: '', tiers: [
                { name: 'sidearms', weight: 70, colour: '#4c9aff', enabled: true, items: [it('weapon_pistol', 1, 1, 20), it('weapon_combatpistol', 1, 1, 10), it('pistol_ammo', 24, 48, 30)] },
                { name: 'heavy', weight: 30, colour: '#ff5c64', enabled: true, items: [it('weapon_carbinerifle', 1, 1), it('rifle_ammo', 30, 90, 20), it('weapon_railgun_x', 1, 1, 2)] },
            ] } },
        ],
        drops: [],
        history: [],
    };

    const ITEMS = ['bandage', 'water_bottle', 'sandwich', 'plastic', 'metalscrap', 'lockpick', 'advancedlockpick', 'radio', 'firstaid', 'steel', 'weapon_pistol', 'pistol_ammo', 'thermite', 'trojan_usb',
        'weapon_assaultrifle', 'rifle_ammo', 'goldbar', 'weapon_combatpistol', 'weapon_carbinerifle', 'armor', 'phone', 'handcuffs', 'repairkit', 'cleaningkit', 'joint', 'cokebaggy', 'meth', 'diamond', 'rolex', 'goldchain', 'copper', 'aluminum', 'rubber', 'glass', 'iron', 'electronickit', 'drill', 'security_card_01', 'security_card_02', 'weapon_smg', 'smg_ammo', 'weapon_pumpshotgun', 'shotgun_ammo', 'parachute', 'binoculars']
        .map((name) => ({ name, label: name.replace(/^weapon_/, '').replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()) }));

    const now = () => Math.floor(Date.now() / 1000);
    const T0 = now();
    const histRow = (id, label, crateLabel, lootLabel, calledBy, crackedBy, outcome, ago, lasted, contents) => ({ id, label, zone: 1, crate: crateLabel, loot: lootLabel, calledBy, crackedBy, cid: crackedBy ? 'XYR10001' : '', outcome, contents, age: ago, lasted, x: 0, y: 0, z: 0 });
    DB.history = [
        histRow(9, 'Sandy Shores Airfield', 'Standard crate', 'Standard loot', 'Schedule', 'Vincent Valentine', 'emptied', 3600, 540, [{ item: 'bandage', count: 4, tier: 'common' }, { item: 'lockpick', count: 2, tier: 'uncommon' }, { item: 'weapon_pistol', count: 1, tier: 'rare' }]),
        histRow(8, 'Grapeseed Fields', 'Military cache', 'Weapons cache', 'Schedule', '', 'abandoned', 3 * 3600, 900, []),
        histRow(7, 'Sandy Shores Airfield', 'Standard crate', 'Standard loot', 'XyraL', 'Rafael Duarte', 'looted out', 7 * 3600, 360, [{ item: 'steel', count: 9, tier: 'uncommon' }, { item: 'sandwich', count: 3, tier: 'common' }]),
        histRow(6, 'Port of Los Santos', 'Military cache', 'Weapons cache', 'XyraL', '', 'cancelled', 26 * 3600, 60, []),
        histRow(5, 'Sandy Shores Airfield', 'Standard crate', 'Standard loot', 'Schedule', 'Delia Moss', 'emptied', 30 * 3600, 420, [{ item: 'goldbar', count: 1, tier: 'legendary' }]),
    ];

    let SETTINGS = { sections: [], values: {}, defaults: {} };
    let schedule = { enabled: true, nextIn: 1260, note: null, players: 14, police: 3, running: 0, max: 2, hour: 21 };

    function startDrop(zoneId, opts) {
        const z = DB.zones.find((x) => x.id === Number(zoneId));
        if (!z || !z.data.points.length) return fail('That zone has no landing points yet.');
        if (DB.drops.length >= (SETTINGS.values['Schedule.MaxActive'] || 1)) return fail(`${DB.drops.length} drop is already running. Cancel one, or raise "Drops at once" in Schedule.`);
        if (DB.drops.some((d) => d.zoneId === z.id)) return fail(`"${z.data.label}" already has a drop running.`);
        const c = DB.crates.find((x) => x.id === (opts.crate || z.data.crate)) || DB.crates.find((x) => x.data.isDefault);
        const l = DB.loot.find((x) => x.id === (opts.loot || z.data.loot || c.data.loot)) || DB.loot[0];
        const d = {
            id: `${now()}-${Math.floor(Math.random() * 9000) + 1000}`, state: 'announced', label: z.data.label, zoneId: z.id, point: 1, crate: c.data.label, crateId: c.id, loot: l.data.label, lootId: l.id,
            silent: !!opts.silent, calledBy: opts.by || 'XyraL', crackedBy: null, emptied: false, heldOpen: false, coords: z.data.points[0], landsIn: 90, expiresIn: 270, age: 0, policeIn: null, policeSent: false, radius: z.data.radius || 120,
        };
        DB.drops.push(d);
        return null;
    }

    function live() {
        schedule.running = DB.drops.length;
        schedule.max = SETTINGS.values['Schedule.MaxActive'] || 1;
        schedule.enabled = SETTINGS.values['Schedule.Enabled'] !== false;
        return { drops: copy(DB.drops), schedule: copy(schedule), stats: { total: 42, cracked: 31, abandoned: 9, today: 4, crackedToday: 3 } };
    }

    function data() {
        return {
            me: { name: 'XyraL' }, zones: copy(DB.zones), crates: copy(DB.crates), loot: copy(DB.loot), live: live(),
            system: { framework: 'Qbox', inventory: 'ox_inventory', shared: true, dispatch: params.get('dispatch') === 'none' ? null : 'ps-dispatch', target: 'ox_target', webhook: false },
            access: { ace: 'xs.airdrops', aces: ['command.airdrop', 'xs.airdrops'], groups: ['admin', 'god'], licenses: 0, command: 'airdrops', drop: 'airdrop' },
            items: ITEMS, jobs: [{ name: 'police', label: 'LSPD' }, { name: 'sheriff', label: 'BCSO' }, { name: 'ambulance', label: 'EMS' }, { name: 'mechanic', label: 'Mechanic' }],
            gangs: [{ name: 'ballas', label: 'Ballas' }, { name: 'families', label: 'Families' }, { name: 'vagos', label: 'Vagos' }, { name: 'lostmc', label: 'Lost MC' }],
            settings: copy(SETTINGS), here: { x: 1708.4, y: 3254.1, z: 41.0, area: 'Sandy Shores', street: 'Panorama Dr' },
        };
    }

    function roll(d) {
        const tiers = d.tiers.map((t, rank) => ({ t, rank, items: t.items.filter((i) => i.enabled !== false && i.item) })).filter((x) => x.t.enabled !== false && x.items.length);
        const pick = (list, w) => { const sum = list.reduce((a, x) => a + w(x), 0); let r = Math.random() * sum; for (const x of list) { r -= w(x); if (r <= 0) return x; } return list[list.length - 1]; };
        const out = [];
        if (!tiers.length) return out;
        const n = d.minStacks + Math.floor(Math.random() * (d.maxStacks - d.minStacks + 1));
        for (let i = 0; i < n; i++) {
            const t = pick(tiers, (x) => x.t.weight);
            const e = pick(t.items, (x) => x.weight);
            out.push({ item: e.item, count: e.min + Math.floor(Math.random() * (e.max - e.min + 1)), tier: t.t.name, rank: t.rank });
        }
        return out;
    }

    const LIST = { zone: 'zones', crate: 'crates', loot: 'loot' };

    function server(action, p) {
        const [kind, verb] = action.split(':');
        if (action === 'data') return reply(data());
        if (action === 'live') return reply(live());
        if (action === 'teleport') return reply(true);
        if (action === 'history') return reply({ rows: copy(p.outcome && p.outcome !== 'all' ? DB.history.filter((h) => h.outcome === p.outcome) : DB.history), stats: live().stats });
        if (action === 'settings:save') {
            Object.assign(SETTINGS.values, p.changes || {});
            if (SETTINGS.values['Schedule.MinInterval'] > SETTINGS.values['Schedule.MaxInterval']) return fail('The shortest gap cannot be longer than the longest gap.');
            return reply({ values: copy(SETTINGS.values), schedule: live().schedule });
        }
        if (action === 'loot:test') return reply([roll(p.data)]);
        if (action === 'drop:start') {
            let zoneId = Number(p.zone) || 0;
            if (!zoneId) { const z = DB.zones.find((x) => x.data.enabled && x.data.points.length && !DB.drops.some((d) => d.zoneId === x.id)); if (!z) return fail('No zone can take a drop right now.'); zoneId = z.id; }
            const err = startDrop(zoneId, p);
            if (err) return err;
            const z = DB.zones.find((x) => x.id === zoneId);
            return reply({ id: DB.drops[DB.drops.length - 1].id, label: z.data.label, live: live() });
        }
        if (action === 'drop:cancel') {
            DB.drops = DB.drops.filter((d) => d.id !== p.id);
            return reply(live());
        }
        if (LIST[kind] && verb === 'save') {
            const list = DB[LIST[kind]];
            if (!String((p.data || {}).label || '').trim()) return fail('Give it a name first.');
            let rec = list.find((r) => r.id === Number(p.id));
            if (rec) rec.data = copy(p.data); else { rec = { id: DB.nextId[kind]++, data: copy(p.data) }; list.push(rec); }
            if (kind === 'crate') {
                if (rec.data.isDefault) DB.crates.forEach((c) => { if (c.id !== rec.id) c.data.isDefault = false; });
                return reply({ record: copy(rec), crates: copy(DB.crates) });
            }
            return reply(copy(rec));
        }
        if (LIST[kind] && verb === 'delete') {
            const list = DB[LIST[kind]];
            if (kind !== 'zone' && list.length <= 1) return fail(`Keep at least one ${kind === 'crate' ? 'crate type' : 'loot table'}.`);
            DB[LIST[kind]] = list.filter((r) => r.id !== Number(p.id));
            if (kind === 'crate') {
                if (!DB.crates.some((c) => c.data.isDefault)) DB.crates[0].data.isDefault = true;
                return reply({ crates: copy(DB.crates) });
            }
            return reply(true);
        }
        return fail(`Mock has no ${action}`);
    }

    window.AD_MOCK = { DB, send, data, places: 0 };

    const RPC = {
        'b:server': (p) => server(p.action, p.payload || {}),
        'b:here': () => reply({ x: 1702.1 + window.AD_MOCK.places, y: 3250.6, z: 40.98, area: 'Sandy Shores', street: 'Panorama Dr' }),
        'b:place': () => { window.AD_MOCK.places += 1; return reply({ x: 1690.2 + window.AD_MOCK.places * 7, y: 3240.5, z: 40.7 }); },
        'b:teleport': () => reply(true),
        'b:waypoint': () => reply(true),
        'b:showPoints': () => reply(true),
    };

    XS.post = async (endpoint, payload) => {
        if (endpoint === 'close') { send(payload.app, 'close', {}); return { ok: true }; }
        if (endpoint !== 'rpc') return { ok: true };
        const fn = RPC[payload.name];
        await new Promise((r) => setTimeout(r, 40));
        return fn ? fn(payload.payload || {}) : { ok: true, data: null };
    };

    function seedDrops() {
        startDrop(1, { by: 'XyraL' });
        const a = DB.drops[0];
        Object.assign(a, { state: 'landed', landsIn: 0, expiresIn: 742, age: 160, policeIn: 12 });
        if (params.get('drops') === 'two') {
            startDrop(2, { by: 'XyraL', silent: true });
            Object.assign(DB.drops[1], { state: 'inbound', landsIn: 38 });
        }
    }

    async function boot() {
        try {
            const res = await fetch('__settings.json');
            if (res.ok) SETTINGS = await res.json();
        } catch (e) {
            SETTINGS = { sections: [], values: {}, defaults: {} };
        }
        if (params.get('max')) SETTINGS.values['Schedule.MaxActive'] = Number(params.get('max'));
        if (params.get('drops') !== 'none') seedDrops();
        send('builder', 'open', data());
        const page = params.get('page');
        const edit = params.get('edit');
        setTimeout(() => {
            if (edit) {
                const [kind, id] = edit.split(':');
                const nav = { zone: 'zones', crate: 'crates', loot: 'loot' }[kind];
                const b = document.querySelector(`[data-act="nav"][data-page="${nav}"]`);
                if (b) b.click();
                setTimeout(() => {
                    const r = document.querySelector(`tr[data-act="edit"][data-kind="${kind}"][data-id="${id}"]`);
                    if (r) r.click();
                    const tab = params.get('tab');
                    if (tab) setTimeout(() => { const x = document.querySelector(`[data-act="tab"][data-tab="${tab}"]`); if (x) x.click(); }, 60);
                }, 60);
            } else if (page) {
                const b = document.querySelector(`[data-act="nav"][data-page="${page}"]`);
                if (b) b.click();
            }
        }, 80);
    }

    window.addEventListener('load', boot);
})();
