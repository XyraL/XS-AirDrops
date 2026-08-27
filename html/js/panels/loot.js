// Loot tables.
//
// Tiers hold items; both carry a weight, and both weights are relative rather
// than percentages — so adding a tier does not mean rebalancing every number
// that was already there. The panel shows the resolved percentage next to each
// weight, because "weight 28" means nothing on its own and the actual question
// an admin has is "how often will this drop".

async function renderLoot() {
    const panel = document.getElementById('panel-loot');
    const data = await nui('getLoot');
    const tiers = (data && data.tiers) || [];

    const itemCount = tiers.reduce((n, t) => n + (t.items || []).length, 0);
    document.getElementById('badge-loot').textContent = itemCount || '';

    const tierTotal = tiers.reduce((n, t) => n + (t.enabled ? t.weight : 0), 0);

    panel.innerHTML = `
        <div class="panel-header">
            <div>
                <div class="panel-title">Loot Tables</div>
                <div class="panel-subtitle">Rolled when a crate is cracked. Weights are relative — the percentages are worked out for you.</div>
            </div>
            <div class="panel-actions">
                <button class="btn btn-ghost" id="btn-add-tier">+ Add tier</button>
                <button class="btn btn-primary" id="btn-add-item" ${tiers.length ? '' : 'disabled'}>+ Add item</button>
            </div>
        </div>

        <div class="panel-body">
            ${tiers.length === 0
                ? emptyState('—', 'No loot tiers', 'Add a tier, then put items in it.')
                : tiers.map(t => renderTier(t, tierTotal)).join('')}

            <div class="alert alert-info" style="margin-top:16px;">
                A crate that is entirely bandages after a five-minute fight teaches players to
                ignore the next one. <strong>GuaranteeAtLeast</strong> in config.lua forces one
                roll up to a chosen tier or better.
            </div>
        </div>`;

    document.getElementById('btn-add-tier').addEventListener('click', () => openTierModal(null));
    document.getElementById('btn-add-item').addEventListener('click', () => openItemModal(null, tiers));

    panel.querySelectorAll('[data-edit-tier]').forEach(btn =>
        btn.addEventListener('click', () => {
            openTierModal(tiers.find(t => String(t.id) === btn.dataset.editTier));
        }));

    panel.querySelectorAll('[data-del-tier]').forEach(btn =>
        btn.addEventListener('click', () => {
            const tier = tiers.find(t => String(t.id) === btn.dataset.delTier);
            confirmDelete(`the "${tier.name}" tier`, async () => {
                const res = await nui('deleteTier', { id: tier.id });
                reportResult(res, 'Tier deleted', 'Its items went with it.');
                renderLoot();
            });
        }));

    panel.querySelectorAll('[data-edit-item]').forEach(btn =>
        btn.addEventListener('click', () => {
            const id = btn.dataset.editItem;
            let found = null;
            tiers.forEach(t => (t.items || []).forEach(i => { if (String(i.id) === id) found = i; }));
            openItemModal(found, tiers);
        }));

    panel.querySelectorAll('[data-del-item]').forEach(btn =>
        btn.addEventListener('click', () => {
            const id = btn.dataset.delItem;
            let found = null;
            tiers.forEach(t => (t.items || []).forEach(i => { if (String(i.id) === id) found = i; }));
            confirmDelete(found ? found.item : 'item', async () => {
                const res = await nui('deleteLoot', { id: found.id });
                reportResult(res, 'Item removed');
                renderLoot();
            });
        }));
}

function renderTier(tier, tierTotal) {
    const items = tier.items || [];
    const itemTotal = items.reduce((n, i) => n + (i.enabled ? i.weight : 0), 0);
    const tierPct = tierTotal > 0 && tier.enabled ? ((tier.weight / tierTotal) * 100).toFixed(1) : '0.0';

    return `
        <div class="card ${tier.enabled ? '' : 'row-muted'}" style="margin-bottom:14px;">
            <div class="card-header">
                <div class="card-title">
                    <span class="tier-dot" style="background:${esc(tier.colour || '#9aa0a8')}"></span>
                    ${esc(tier.name)}
                    <span class="badge badge-muted" style="margin-left:8px;">${tierPct}% of rolls</span>
                    ${tier.enabled ? '' : '<span class="badge badge-muted" style="margin-left:6px;">Disabled</span>'}
                </div>
                <div>
                    <button class="btn btn-ghost btn-sm" data-edit-tier="${esc(tier.id)}">Edit</button>
                    <button class="btn btn-danger btn-sm" data-del-tier="${esc(tier.id)}">Delete</button>
                </div>
            </div>

            ${items.length === 0
                ? '<div class="text-muted text-sm">No items in this tier — it will never be rolled.</div>'
                : `
                <div class="data-table-wrap">
                    <table class="data-table">
                        <thead>
                            <tr><th>Item</th><th>Count</th><th>Weight</th><th>Within tier</th><th></th></tr>
                        </thead>
                        <tbody>
                            ${items.map(item => `
                                <tr class="${item.enabled ? '' : 'row-muted'}">
                                    <td class="mono">${esc(item.item)}</td>
                                    <td>${esc(item.min_count)}${item.max_count !== item.min_count ? '–' + esc(item.max_count) : ''}</td>
                                    <td>${esc(item.weight)}</td>
                                    <td class="text-muted">${itemTotal > 0 && item.enabled
                                        ? ((item.weight / itemTotal) * 100).toFixed(1) + '%'
                                        : '—'}</td>
                                    <td style="text-align:right;white-space:nowrap;">
                                        <button class="btn btn-ghost btn-sm" data-edit-item="${esc(item.id)}">Edit</button>
                                        <button class="btn btn-danger btn-sm" data-del-item="${esc(item.id)}">Delete</button>
                                    </td>
                                </tr>`).join('')}
                        </tbody>
                    </table>
                </div>`}
        </div>`;
}

function openTierModal(tier) {
    const editing = !!tier;

    modal(editing ? 'Edit tier' : 'Add tier', `
        <div class="form-row">
            <div class="form-group" style="flex:2;">
                <label class="form-label">Name</label>
                <input class="input" id="tier-name" value="${esc(tier?.name || '')}" placeholder="rare">
            </div>
            <div class="form-group">
                <label class="form-label">Weight</label>
                <input class="input" id="tier-weight" value="${esc(tier?.weight ?? 10)}">
            </div>
        </div>

        <div class="form-row">
            <div class="form-group">
                <label class="form-label">Rank</label>
                <input class="input" id="tier-rank" value="${esc(tier?.rank ?? 99)}">
                <div class="form-hint">Higher is better. Decides what "this tier or better" means.</div>
            </div>
            <div class="form-group">
                <label class="form-label">Colour</label>
                <input class="input" id="tier-colour" value="${esc(tier?.colour || '#9aa0a8')}" placeholder="#f5a524">
                <div class="form-hint">Panel only — players never see it.</div>
            </div>
        </div>

        <label class="checkbox">
            <input type="checkbox" id="tier-enabled" ${tier?.enabled !== false ? 'checked' : ''}>
            <span>Enabled — can be rolled</span>
        </label>`,

        async () => {
            const name = val('tier-name');
            if (!name) { toast('Name needed', '', 'error'); return false; }

            const res = await nui('saveTier', {
                id: tier?.id,
                name,
                weight: numVal('tier-weight', 10),
                rank: numVal('tier-rank', 99),
                colour: val('tier-colour') || '#9aa0a8',
                enabled: checked('tier-enabled'),
            });

            if (!reportResult(res, editing ? 'Tier updated' : 'Tier added', name)) return false;
            renderLoot();
        });
}

function openItemModal(item, tiers) {
    const editing = !!item;

    modal(editing ? 'Edit item' : 'Add item', `
        <div class="form-group">
            <label class="form-label">Item name</label>
            <input class="input" id="item-name" value="${esc(item?.item || '')}" placeholder="advancedlockpick">
            <div class="form-hint">Exactly as your inventory knows it. A typo here means an empty slot in the crate, not an error.</div>
        </div>

        <div class="form-group">
            <label class="form-label">Tier</label>
            <select class="select" id="item-tier">
                ${tiers.map(t => `
                    <option value="${esc(t.id)}" ${String(t.id) === String(item?.tier_id) ? 'selected' : ''}>
                        ${esc(t.name)}
                    </option>`).join('')}
            </select>
        </div>

        <div class="form-row">
            <div class="form-group">
                <label class="form-label">Minimum</label>
                <input class="input" id="item-min" value="${esc(item?.min_count ?? 1)}">
            </div>
            <div class="form-group">
                <label class="form-label">Maximum</label>
                <input class="input" id="item-max" value="${esc(item?.max_count ?? 1)}">
            </div>
            <div class="form-group">
                <label class="form-label">Weight</label>
                <input class="input" id="item-weight" value="${esc(item?.weight ?? 10)}">
            </div>
        </div>

        <label class="checkbox">
            <input type="checkbox" id="item-enabled" ${item?.enabled !== false ? 'checked' : ''}>
            <span>Enabled — can be rolled</span>
        </label>`,

        async () => {
            const name = val('item-name');
            if (!name) { toast('Item name needed', '', 'error'); return false; }

            const res = await nui('saveLoot', {
                id: item?.id,
                tier_id: parseInt(val('item-tier'), 10),
                item: name,
                min_count: numVal('item-min', 1),
                max_count: numVal('item-max', 1),
                weight: numVal('item-weight', 10),
                enabled: checked('item-enabled'),
            });

            if (!reportResult(res, editing ? 'Item updated' : 'Item added', name)) return false;
            renderLoot();
        });
}
