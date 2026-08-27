// Live drop control.
//
// The panel an admin actually opens mid-event: what is happening right now, and
// the two buttons for changing it.

const STATE_LOOK = {
    announced: { label: 'Announced',  tag: 'badge-amber', note: 'Inbound. Players have been told roughly where.' },
    inbound:   { label: 'Inbound',    tag: 'badge-amber', note: 'The plane is flying it in.' },
    landed:    { label: 'On the ground', tag: 'badge-red', note: 'Crate is down and can be cracked.' },
    open:      { label: 'Open',       tag: 'badge-green', note: 'Cracked. Anyone nearby can loot it.' },
};

async function renderLive() {
    const panel = document.getElementById('panel-live');
    const data = await nui('getLive');

    if (!data) {
        panel.innerHTML = emptyState('!', 'Could not reach the server', 'Try reopening the panel.');
        return;
    }

    const drop = data.drop;
    const look = drop ? (STATE_LOOK[drop.state] || STATE_LOOK.announced) : null;

    panel.innerHTML = `
        <div class="panel-header">
            <div>
                <div class="panel-title">Live Drop</div>
                <div class="panel-subtitle">What is happening on the map right now</div>
            </div>
            <div class="panel-actions">
                ${drop
                    ? `<button class="btn btn-danger" id="btn-cancel-drop">Cancel drop</button>`
                    : `<button class="btn btn-primary" id="btn-start-drop">Start a drop</button>`}
            </div>
        </div>

        <div class="panel-body">
            ${drop ? `
                <div class="card accent-border" style="margin-bottom:16px;">
                    <div class="card-header">
                        <div class="card-title">
                            ${esc(drop.label || 'Unnamed location')}
                            <span class="badge ${look.tag}" style="margin-left:8px;">${esc(look.label)}</span>
                            ${drop.silent ? '<span class="badge badge-muted" style="margin-left:6px;">Silent test</span>' : ''}
                        </div>
                        <div class="text-muted text-sm">${esc(look.note)}</div>
                    </div>

                    <div class="stat-grid">
                        <div class="stat-card">
                            <div class="stat-label">Cracked by</div>
                            <div class="stat-value">${esc(drop.crackedBy || '—')}</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-label">Zone radius</div>
                            <div class="stat-value">${esc(Math.round(drop.zoneRadius || 0))}m</div>
                        </div>
                        <div class="stat-card">
                            <div class="stat-label">${countdownLabel(drop.state)}</div>
                            <div class="stat-value" id="live-countdown">—</div>
                        </div>
                    </div>
                </div>` : `
                <div class="card" style="margin-bottom:16px;">
                    ${emptyState('—', 'No drop running', 'The scheduler will call one, or you can start one now.')}
                </div>`}

            <div class="card">
                <div class="card-header"><div class="card-title">Scheduler</div></div>
                <div class="stat-grid">
                    <div class="stat-card">
                        <div class="stat-label">Status</div>
                        <div class="stat-value">${data.scheduleEnabled ? 'On' : 'Off'}</div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Players online</div>
                        <div class="stat-value">${esc(data.players)} <span class="text-muted text-sm">/ ${esc(data.minPlayers)} needed</span></div>
                    </div>
                    <div class="stat-card">
                        <div class="stat-label">Next automatic drop</div>
                        <div class="stat-value">${data.nextIn === null || data.nextIn === undefined
                            ? '—'
                            : (data.nextIn <= 0 ? 'due' : Math.ceil(data.nextIn / 60) + 'm')}</div>
                    </div>
                </div>
                ${data.players < data.minPlayers ? `
                    <div class="alert alert-warn" style="margin-top:12px;">
                        Not enough players online for an automatic drop. Starting one by hand ignores this.
                    </div>` : ''}
            </div>
        </div>`;

    if (drop) {
        startLiveCountdown(drop);
        document.getElementById('btn-cancel-drop').addEventListener('click', cancelDrop);
    } else {
        document.getElementById('btn-start-drop').addEventListener('click', openStartDropModal);
    }
}

// Ticks locally from the seconds the server sent, rather than re-asking every
// second. The panel is open for a minute at a time; a poll per second for a
// number the server already gave us is waste.
let _liveTimer = null;

// Which clock matters depends on the state. Once a crate is on the ground,
// "lands in 0:00" is both useless and slightly alarming — what an admin wants
// then is how long it has left before it gives up and despawns.
function countdownLabel(state) {
    if (state === 'announced' || state === 'inbound') return 'Lands in';
    if (state === 'open') return 'Closes in';
    return 'Expires in';
}

function startLiveCountdown(drop) {
    clearInterval(_liveTimer);

    const inbound = drop.state === 'announced' || drop.state === 'inbound';
    let remaining = inbound ? drop.landsIn : drop.expiresIn;
    if (remaining === null || remaining === undefined) return;

    const el = () => document.getElementById('live-countdown');
    const paint = () => {
        const node = el();
        if (!node) { clearInterval(_liveTimer); return; }
        const m = Math.floor(Math.max(0, remaining) / 60);
        const s = Math.max(0, remaining) % 60;
        node.textContent = `${m}:${String(s).padStart(2, '0')}`;
    };

    paint();
    _liveTimer = setInterval(() => {
        remaining -= 1;
        paint();
        if (remaining <= 0) {
            clearInterval(_liveTimer);
            // The state has changed server-side; re-read rather than guess.
            setTimeout(renderLive, 1500);
        }
    }, 1000);
}

async function openStartDropModal() {
    const locations = await nui('getLocations');
    const list = (locations && locations.rows) || [];
    const usable = list.filter(l => l.enabled);

    // Nothing to drop on. Saying so here beats an empty dropdown that looks
    // like the panel is broken.
    if (!usable.length) {
        modal('No locations', `
            <p class="text-secondary">
                ${list.length
                    ? 'Every location is switched off. Turn one on from the Locations tab.'
                    : 'There are no drop locations yet. Go and stand somewhere worth fighting over, then add it from the Locations tab.'}
            </p>`,
            () => { showPanel('locations'); }, 'Open Locations');
        return;
    }

    modal('Start a drop', `
        <div class="form-group">
            <label class="form-label">Location</label>
            <select class="select" id="drop-location">
                <option value="">— Pick by weight —</option>
                ${usable.map(l => `<option value="${esc(l.id)}">${esc(l.label)}</option>`).join('')}
            </select>
            <div class="form-hint">Leaving this on "pick by weight" is what the scheduler does, and it will not repeat the last location.</div>
        </div>

        <label class="checkbox">
            <input type="checkbox" id="drop-silent">
            <span>Silent test — only admins see it</span>
        </label>
        <div class="form-hint" style="margin-top:6px;">
            A real crate with real loot, but no announcement, no blip for players,
            no police call, and it is left out of the history so a test does not
            skew the numbers you tune against.
        </div>`,
        async () => {
            const id = val('drop-location');
            const res = await nui('startDrop', {
                locationId: id ? parseInt(id, 10) : null,
                silent: checked('drop-silent'),
            });
            const silent = checked('drop-silent');
            if (!reportResult(res, silent ? 'Test drop called' : 'Drop called',
                    silent ? 'Only admins can see it.' : 'Players have been told.')) return false;
            renderLive();
        }, 'Call the drop');
}

function cancelDrop() {
    confirmDelete('this drop', async () => {
        const res = await nui('cancelDrop');
        reportResult(res, 'Drop cancelled', 'The crate has been removed.');
        renderLive();
    });
}
