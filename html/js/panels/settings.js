// Runtime settings.
//
// These are the numbers you want to nudge while a drop is actually playing out
// — "that warning felt ten seconds short", "cracking is too easy". The panel
// writes them straight to the database; config.lua remains the default that
// Reset goes back to.
//
// Each field saves on its own rather than behind a Save button at the bottom.
// A page of twenty settings with one button invites you to change five things
// and then find out which one the server rejected.

async function renderSettings() {
    const panel = document.getElementById('panel-settings');
    const data = await nui('getSettings');
    const rows = (data && data.rows) || [];

    const changed = rows.filter(r => r.modified).length;
    document.getElementById('badge-settings').textContent = changed || '';

    // Grouped in schema order, so related settings stay together and the order
    // is decided once, on the server, rather than here.
    const groups = [];
    for (const row of rows) {
        let group = groups.find(g => g.name === row.group);
        if (!group) { group = { name: row.group, rows: [] }; groups.push(group); }
        group.rows.push(row);
    }

    panel.innerHTML = `
        <div class="panel-header">
            <div>
                <div class="panel-title">Settings</div>
                <div class="panel-subtitle">
                    Saved to the database and applied immediately — no restart.
                    Anything you have not touched follows config.lua.
                </div>
            </div>
            ${changed ? `<div class="panel-actions">
                <span class="badge badge-amber">${changed} changed from default</span>
            </div>` : ''}
        </div>

        <div class="panel-body">
            ${groups.map(renderSettingGroup).join('')}
        </div>`;

    wireSettingRows(panel, rows);
}

function renderSettingGroup(group) {
    return `
        <div class="card" style="margin-bottom:14px;">
            <div class="card-header"><div class="card-title">${esc(group.name)}</div></div>
            ${group.rows.map(renderSettingRow).join('')}
        </div>`;
}

function renderSettingRow(row) {
    const id = 'set-' + row.key.replace('.', '-');

    const control = row.type === 'bool'
        ? `<label class="checkbox">
               <input type="checkbox" id="${id}" data-setting="${esc(row.key)}" ${row.value ? 'checked' : ''}>
               <span>${row.value ? 'On' : 'Off'}</span>
           </label>`
        : `<div class="setting-input">
               <input class="input" id="${id}" data-setting="${esc(row.key)}" value="${esc(row.value ?? '')}">
               ${row.unit ? `<span class="setting-unit">${esc(row.unit)}</span>` : ''}
           </div>`;

    const range = (row.min !== undefined && row.min !== null)
        ? `<span class="text-muted text-sm">${esc(row.min)}–${esc(row.max)}</span>`
        : '';

    return `
        <div class="setting-row">
            <div class="setting-meta">
                <div class="setting-label">
                    ${esc(row.label)}
                    ${row.modified ? '<span class="badge badge-amber" style="margin-left:8px;">changed</span>' : ''}
                </div>
                ${row.help ? `<div class="form-hint">${esc(row.help)}</div>` : ''}
            </div>
            <div class="setting-control">
                ${control}
                ${range}
                ${row.modified
                    ? `<button class="btn btn-ghost btn-sm" data-reset="${esc(row.key)}"
                               title="Back to the value in config.lua (${esc(row.default ?? '—')})">Reset</button>`
                    : ''}
            </div>
        </div>`;
}

function wireSettingRows(panel, rows) {
    const save = async (key, value) => {
        const res = await nui('saveSetting', { key, value });
        if (res && res.ok) {
            toast('Saved', key, 'success');
            renderSettings();
            return true;
        }
        // Re-render on failure too, so the field snaps back to what the server
        // actually holds rather than showing a value it rejected.
        toast('Not saved', (res && res.error) || 'The server refused it.', 'error');
        renderSettings();
        return false;
    };

    panel.querySelectorAll('input[type="checkbox"][data-setting]').forEach(el =>
        el.addEventListener('change', () => save(el.dataset.setting, el.checked)));

    panel.querySelectorAll('input:not([type="checkbox"])[data-setting]').forEach(el => {
        const original = el.value;

        const commit = () => {
            if (el.value.trim() === original.trim()) return;   // nothing typed
            save(el.dataset.setting, el.value.trim());
        };

        el.addEventListener('blur', commit);
        el.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { e.preventDefault(); el.blur(); }
            // Escape puts back what was there, which is the only way out of a
            // half-typed number that does not save it.
            if (e.key === 'Escape') { el.value = original; el.blur(); }
        });
    });

    panel.querySelectorAll('[data-reset]').forEach(btn =>
        btn.addEventListener('click', async () => {
            const res = await nui('resetSetting', { key: btn.dataset.reset });
            reportResult(res, 'Reset to default', btn.dataset.reset);
            renderSettings();
        }));
}
