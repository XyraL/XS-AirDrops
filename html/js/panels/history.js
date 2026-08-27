// Past drops.
//
// This is the tuning view. The number that matters is how many crates were
// abandoned: a high abandon rate means the drops are landing where nobody is,
// or the loot is not worth the trip, and both are fixed on the other two tabs.

async function renderHistory() {
    const panel = document.getElementById('panel-history');
    const data = await nui('getHistory');
    const rows = (data && data.rows) || [];
    const stats = (data && data.stats) || {};

    const total = Number(stats.total) || 0;
    const cracked = Number(stats.cracked) || 0;
    const abandoned = Number(stats.abandoned) || 0;
    const crackRate = total > 0 ? Math.round((cracked / total) * 100) : 0;

    panel.innerHTML = `
        <div class="panel-header">
            <div>
                <div class="panel-title">History</div>
                <div class="panel-subtitle">Every drop that has happened, and whether anyone bothered.</div>
            </div>
        </div>

        <div class="panel-body">
            <div class="stat-grid" style="margin-bottom:18px;">
                <div class="stat-card">
                    <div class="stat-label">Drops</div>
                    <div class="stat-value">${total}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Cracked</div>
                    <div class="stat-value">${cracked} <span class="text-muted text-sm">${crackRate}%</span></div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Abandoned</div>
                    <div class="stat-value ${abandoned > cracked ? 'text-warn' : ''}">${abandoned}</div>
                </div>
            </div>

            ${total > 0 && crackRate < 50 ? `
                <div class="alert alert-warn" style="margin-bottom:16px;">
                    More than half of your drops are going untouched. Usually that means they are
                    landing somewhere nobody goes, the warning window is too short to travel in,
                    or the loot is not worth the fight.
                </div>` : ''}

            ${rows.length === 0
                ? emptyState('—', 'Nothing yet', 'Drops will appear here once they have run.')
                : `
                <div class="data-table-wrap">
                    <table class="data-table">
                        <thead>
                            <tr><th>When</th><th>Location</th><th>Called by</th><th>Cracked by</th><th>Contents</th><th>Outcome</th></tr>
                        </thead>
                        <tbody>
                            ${rows.map(renderHistoryRow).join('')}
                        </tbody>
                    </table>
                </div>`}
        </div>`;

    panel.querySelectorAll('[data-contents]').forEach(btn =>
        btn.addEventListener('click', () => {
            const row = rows.find(r => String(r.id) === btn.dataset.contents);
            showContents(row);
        }));
}

const OUTCOME_TAG = {
    'looted out': 'badge-green',
    emptied: 'badge-green',
    abandoned: 'badge-muted',
    cancelled: 'badge-red',
};

function renderHistoryRow(row) {
    let contents = [];
    try {
        contents = typeof row.contents === 'string' ? JSON.parse(row.contents) : (row.contents || []);
    } catch (e) { contents = []; }

    return `
        <tr>
            <td class="text-muted text-sm">${esc(timeAgo(row.age_seconds))}</td>
            <td><strong>${esc(row.label)}</strong></td>
            <td class="text-muted">${esc(row.called_by || 'scheduler')}</td>
            <td>${esc(row.cracked_by_name || '—')}</td>
            <td>
                ${contents.length
                    ? `<button class="btn btn-ghost btn-sm" data-contents="${esc(row.id)}">${contents.length} stacks</button>`
                    : '<span class="text-muted">—</span>'}
            </td>
            <td>
                <span class="badge ${OUTCOME_TAG[row.outcome] || 'badge-muted'}">
                    ${esc(row.outcome || 'running')}
                </span>
            </td>
        </tr>`;
}

function showContents(row) {
    if (!row) return;

    let contents = [];
    try {
        contents = typeof row.contents === 'string' ? JSON.parse(row.contents) : (row.contents || []);
    } catch (e) { contents = []; }

    modal(`What was in it — ${row.label}`, `
        <div class="data-table-wrap">
            <table class="data-table">
                <thead><tr><th>Item</th><th>Count</th><th>Tier</th></tr></thead>
                <tbody>
                    ${contents.map(entry => `
                        <tr>
                            <td class="mono">${esc(entry.item)}</td>
                            <td>${esc(entry.count)}</td>
                            <td class="text-muted">${esc(entry.tier || '—')}</td>
                        </tr>`).join('')}
                </tbody>
            </table>
        </div>`,
        null);
}
