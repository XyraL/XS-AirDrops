// Drop locations.
//
// The point of editing these in game rather than in config.lua is standing on
// the spot while you do it — hence "use my position", which is the button this
// panel exists for.

async function renderLocations() {
    const panel = document.getElementById('panel-locations');
    const data = await nui('getLocations');
    const rows = (data && data.rows) || [];

    document.getElementById('badge-locations').textContent = rows.length || '';

    panel.innerHTML = `
        <div class="panel-header">
            <div>
                <div class="panel-title">Drop Locations</div>
                <div class="panel-subtitle">Where crates can land. Weight biases the pick; the last location is never chosen twice running.</div>
            </div>
            <div class="panel-actions">
                <button class="btn btn-primary" id="btn-add-location">+ Add location</button>
            </div>
        </div>

        <div class="panel-body">
            ${rows.length === 0
                ? emptyState('—', 'No locations', 'Add one while standing where you want crates to land.')
                : `
                <div class="data-table-wrap">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Label</th><th>Coordinates</th><th>Weight</th>
                                <th>Radius</th><th>Status</th><th></th>
                            </tr>
                        </thead>
                        <tbody>
                            ${rows.map(renderLocationRow).join('')}
                        </tbody>
                    </table>
                </div>`}

            <div class="alert alert-info" style="margin-top:16px;">
                Pick open ground with more than one approach. A spot with a single road in
                belongs to whoever parks on it, which is not a contest.
            </div>
        </div>`;

    document.getElementById('btn-add-location').addEventListener('click', () => openLocationModal(null));

    panel.querySelectorAll('[data-edit-location]').forEach(btn =>
        btn.addEventListener('click', () => {
            const row = rows.find(r => String(r.id) === btn.dataset.editLocation);
            openLocationModal(row);
        }));

    panel.querySelectorAll('[data-tp-location]').forEach(btn =>
        btn.addEventListener('click', async () => {
            const row = rows.find(r => String(r.id) === btn.dataset.tpLocation);
            if (!row) return;
            await nui('teleport', { x: row.x, y: row.y, z: row.z });
            toast('On your way', row.label, 'success');
        }));

    panel.querySelectorAll('[data-del-location]').forEach(btn =>
        btn.addEventListener('click', () => {
            const row = rows.find(r => String(r.id) === btn.dataset.delLocation);
            confirmDelete(row ? row.label : 'location', async () => {
                const res = await nui('deleteLocation', { id: row.id });
                reportResult(res, 'Location deleted');
                renderLocations();
            });
        }));
}

function renderLocationRow(row) {
    return `
        <tr class="${row.enabled ? '' : 'row-muted'}">
            <td><strong>${esc(row.label)}</strong></td>
            <td class="mono text-sm text-muted">
                ${esc(Math.round(row.x))}, ${esc(Math.round(row.y))}, ${esc(Math.round(row.z))}
            </td>
            <td>${esc(row.weight)}</td>
            <td class="text-muted">${row.radius ? esc(Math.round(row.radius)) + 'm' : 'default'}</td>
            <td>
                <span class="badge ${row.enabled ? 'badge-green' : 'badge-muted'}">
                    ${row.enabled ? 'Enabled' : 'Disabled'}
                </span>
            </td>
            <td style="text-align:right;white-space:nowrap;">
                <button class="btn btn-ghost btn-sm" data-tp-location="${esc(row.id)}">Go to</button>
                <button class="btn btn-ghost btn-sm" data-edit-location="${esc(row.id)}">Edit</button>
                <button class="btn btn-danger btn-sm" data-del-location="${esc(row.id)}">Delete</button>
            </td>
        </tr>`;
}

function openLocationModal(row) {
    const editing = !!row;

    modal(editing ? 'Edit location' : 'Add location', `
        <div class="form-group">
            <label class="form-label">Label</label>
            <input class="input" id="loc-label" value="${esc(row?.label || '')}" placeholder="Sandy Shores Airfield">
        </div>

        <div class="form-row">
            <div class="form-group"><label class="form-label">X</label>
                <input class="input" id="loc-x" value="${esc(row?.x ?? '')}"></div>
            <div class="form-group"><label class="form-label">Y</label>
                <input class="input" id="loc-y" value="${esc(row?.y ?? '')}"></div>
            <div class="form-group"><label class="form-label">Z</label>
                <input class="input" id="loc-z" value="${esc(row?.z ?? '')}"></div>
        </div>

        <button class="btn btn-ghost btn-sm" id="btn-use-position" style="margin-bottom:14px;">
            Use my current position
        </button>

        <div class="form-row">
            <div class="form-group">
                <label class="form-label">Weight</label>
                <input class="input" id="loc-weight" value="${esc(row?.weight ?? 5)}">
                <div class="form-hint">Relative, not a percentage.</div>
            </div>
            <div class="form-group">
                <label class="form-label">Zone radius</label>
                <input class="input" id="loc-radius" value="${esc(row?.radius ?? '')}" placeholder="default">
                <div class="form-hint">Blank uses the global setting.</div>
            </div>
        </div>

        <label class="checkbox">
            <input type="checkbox" id="loc-enabled" ${row?.enabled !== false ? 'checked' : ''}>
            <span>Enabled — drops can land here</span>
        </label>`,

        async () => {
            const label = val('loc-label');
            if (!label) { toast('Label needed', 'Give the location a name.', 'error'); return false; }

            const payload = {
                id: row?.id,
                label,
                x: numVal('loc-x'), y: numVal('loc-y'), z: numVal('loc-z'),
                weight: numVal('loc-weight', 5),
                radius: val('loc-radius') ? numVal('loc-radius') : null,
                enabled: checked('loc-enabled'),
            };

            if (!payload.x && !payload.y) {
                toast('Coordinates needed', 'Use your current position, or type them in.', 'error');
                return false;
            }

            const res = await nui('saveLocation', payload);
            if (!reportResult(res, editing ? 'Location updated' : 'Location added', label)) return false;
            renderLocations();
        });

    // Wired after the modal exists, since the button lives inside it.
    document.getElementById('btn-use-position').addEventListener('click', async () => {
        const pos = await nui('getPosition');
        if (!pos || pos.x === undefined) { toast('Could not read your position', '', 'error'); return; }
        document.getElementById('loc-x').value = pos.x.toFixed(2);
        document.getElementById('loc-y').value = pos.y.toFixed(2);
        document.getElementById('loc-z').value = pos.z.toFixed(2);
        toast('Position captured', '', 'success');
    });
}
