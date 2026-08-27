// Drop locations.
//
// Built in game, standing on the spot. That is the whole reason these live in
// the database and not in config.lua — guessing coordinates in a text file and
// restarting to see where they landed is a miserable way to design an event.
//
// The workflow this is shaped around: stand somewhere, capture it, drop a
// silent test on it, keep it or bin it.

async function renderLocations() {
    const panel = document.getElementById('panel-locations');
    const data = await nui('getLocations');
    const rows = (data && data.rows) || [];

    document.getElementById('badge-locations').textContent = rows.length || '';

    const live = rows.filter(r => r.enabled).length;

    panel.innerHTML = `
        <div class="panel-header">
            <div>
                <div class="panel-title">Drop Locations</div>
                <div class="panel-subtitle">
                    Where crates can land. Weight biases the pick, and the last location is
                    never chosen twice running.
                </div>
            </div>
            <div class="panel-actions">
                ${rows.length ? `<button class="btn btn-ghost" id="btn-clear-locations">Delete all</button>` : ''}
                <button class="btn btn-primary" id="btn-add-location">+ Add where I'm standing</button>
            </div>
        </div>

        <div class="panel-body">
            ${live === 0 ? `
                <div class="alert alert-warn" style="margin-bottom:16px;">
                    <strong>No locations are enabled.</strong>
                    Drops cannot run at all until at least one is — the scheduler has nowhere
                    to put a crate, and calling one by hand will fail too.
                </div>` : ''}

            ${rows.length === 0
                ? emptyState('—', 'No locations yet',
                    'Go and stand somewhere worth fighting over, then use the button above.')
                : `
                <div class="data-table-wrap">
                    <table class="data-table">
                        <thead>
                            <tr>
                                <th>Label</th><th>Coordinates</th><th>Weight</th>
                                <th>Radius</th><th>On</th><th></th>
                            </tr>
                        </thead>
                        <tbody>${rows.map(renderLocationRow).join('')}</tbody>
                    </table>
                </div>`}

            <div class="alert alert-info" style="margin-top:16px;">
                Pick open ground with more than one way in. A spot with a single road
                belongs to whoever parks on it, which is not a contest.
            </div>
        </div>`;

    wireLocations(panel, rows);
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
                <label class="checkbox">
                    <input type="checkbox" data-toggle-location="${esc(row.id)}" ${row.enabled ? 'checked' : ''}>
                    <span></span>
                </label>
            </td>
            <td style="text-align:right;white-space:nowrap;">
                <button class="btn btn-ghost btn-sm" data-tp-location="${esc(row.id)}">Go to</button>
                <button class="btn btn-ghost btn-sm" data-test-location="${esc(row.id)}">Test drop</button>
                <button class="btn btn-ghost btn-sm" data-edit-location="${esc(row.id)}">Edit</button>
                <button class="btn btn-danger btn-sm" data-del-location="${esc(row.id)}">Delete</button>
            </td>
        </tr>`;
}

function wireLocations(panel, rows) {
    const find = (id) => rows.find(r => String(r.id) === id);

    // Captures your position first, so the modal opens already filled in.
    document.getElementById('btn-add-location').addEventListener('click', async () => {
        const pos = await nui('getPosition');
        openLocationModal(null, pos && pos.x !== undefined ? pos : null);
    });

    document.getElementById('btn-clear-locations')?.addEventListener('click', () => {
        modal('Delete every location?', `
            <p class="text-secondary">
                This removes all ${rows.length} of them. Drops stop happening until you add
                at least one back.
            </p>
            <p class="text-secondary">Loot tables and history are not touched.</p>`,
            async () => {
                const res = await nui('deleteAllLocations');
                reportResult(res, 'Locations cleared', 'Add your own with the button above.');
                renderLocations();
            }, 'Delete them all');
    });

    // Enable/disable without opening the editor — the one field you actually
    // change often.
    panel.querySelectorAll('[data-toggle-location]').forEach(box =>
        box.addEventListener('change', async () => {
            const row = find(box.dataset.toggleLocation);
            if (!row) return;
            const res = await nui('saveLocation', { ...row, enabled: box.checked });
            if (!res || !res.ok) toast('Not saved', (res && res.error) || 'The server refused it.', 'error');
            renderLocations();
        }));

    panel.querySelectorAll('[data-tp-location]').forEach(btn =>
        btn.addEventListener('click', async () => {
            const row = find(btn.dataset.tpLocation);
            if (!row) return;
            await nui('teleport', { x: row.x, y: row.y, z: row.z });
            toast('On your way', row.label, 'success');
        }));

    // A silent drop straight onto this spot — nobody but admins sees it.
    panel.querySelectorAll('[data-test-location]').forEach(btn =>
        btn.addEventListener('click', async () => {
            const row = find(btn.dataset.testLocation);
            const res = await nui('testLocation', { id: row.id });
            if (res && res.ok) toast('Test drop called', row.label + ' — only admins can see it', 'success');
            else toast('Could not start it', (res && res.error) || 'Unknown error', 'error');
        }));

    panel.querySelectorAll('[data-edit-location]').forEach(btn =>
        btn.addEventListener('click', () => openLocationModal(find(btn.dataset.editLocation))));

    panel.querySelectorAll('[data-del-location]').forEach(btn =>
        btn.addEventListener('click', () => {
            const row = find(btn.dataset.delLocation);
            confirmDelete(row ? row.label : 'location', async () => {
                const res = await nui('deleteLocation', { id: row.id });
                reportResult(res, 'Location deleted');
                renderLocations();
            });
        }));
}

// `prefill` is a captured position for a new location.
function openLocationModal(row, prefill) {
    const editing = !!row;
    const x = row?.x ?? prefill?.x ?? '';
    const y = row?.y ?? prefill?.y ?? '';
    const z = row?.z ?? prefill?.z ?? '';

    const round = (v) => (v === '' ? '' : Number(v).toFixed(2));

    modal(editing ? 'Edit location' : 'New location', `
        <div class="form-group">
            <label class="form-label">Label</label>
            <input class="input" id="loc-label" value="${esc(row?.label || '')}"
                   placeholder="What would you call this spot?">
        </div>

        <div class="form-row">
            <div class="form-group"><label class="form-label">X</label>
                <input class="input mono" id="loc-x" value="${esc(round(x))}"></div>
            <div class="form-group"><label class="form-label">Y</label>
                <input class="input mono" id="loc-y" value="${esc(round(y))}"></div>
            <div class="form-group"><label class="form-label">Z</label>
                <input class="input mono" id="loc-z" value="${esc(round(z))}"></div>
        </div>

        <button class="btn btn-ghost btn-sm" id="btn-use-position" style="margin-bottom:14px;">
            ${editing ? 'Move it to where I am standing' : 'Re-capture my position'}
        </button>

        <div class="form-row">
            <div class="form-group">
                <label class="form-label">Weight</label>
                <input class="input" id="loc-weight" value="${esc(row?.weight ?? 5)}">
                <div class="form-hint">Relative to the others, not a percentage.</div>
            </div>
            <div class="form-group">
                <label class="form-label">Zone radius</label>
                <input class="input" id="loc-radius" value="${esc(row?.radius ?? '')}" placeholder="default">
                <div class="form-hint">Blank uses the global setting. Tighter for a yard, wider for open ground.</div>
            </div>
        </div>

        <label class="checkbox">
            <input type="checkbox" id="loc-enabled" ${row?.enabled !== false ? 'checked' : ''}>
            <span>Enabled — drops can land here</span>
        </label>`,

        async () => {
            const label = val('loc-label');
            if (!label) { toast('Give it a name', 'Something you will recognise in the list.', 'error'); return false; }

            if (!val('loc-x') || !val('loc-y')) {
                toast('No coordinates', 'Capture your position, or type them in.', 'error');
                return false;
            }

            const res = await nui('saveLocation', {
                id: row?.id,
                label,
                x: numVal('loc-x'), y: numVal('loc-y'), z: numVal('loc-z'),
                weight: numVal('loc-weight', 5),
                radius: val('loc-radius') ? numVal('loc-radius') : null,
                enabled: checked('loc-enabled'),
            });

            if (!reportResult(res, editing ? 'Location updated' : 'Location added', label)) return false;
            renderLocations();
        });

    document.getElementById('btn-use-position').addEventListener('click', async () => {
        const pos = await nui('getPosition');
        if (!pos || pos.x === undefined) { toast('Could not read your position', '', 'error'); return; }
        document.getElementById('loc-x').value = pos.x.toFixed(2);
        document.getElementById('loc-y').value = pos.y.toFixed(2);
        document.getElementById('loc-z').value = pos.z.toFixed(2);
        toast('Position captured', '', 'success');
    });
}
