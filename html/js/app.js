// Panel shell: open/close, navigation, and which renderer owns which tab.
//
// Loaded last, so every panel's render function already exists by the time the
// table below is built.

const PANELS = {
    live:      renderLive,
    locations: renderLocations,
    loot:      renderLoot,
    history:   renderHistory,
    settings:  renderSettings,
};

let currentPanel = 'live';

function showPanel(name) {
    if (!PANELS[name]) return;
    currentPanel = name;

    document.querySelectorAll('.nav-item').forEach(item =>
        item.classList.toggle('active', item.dataset.panel === name));

    document.querySelectorAll('.panel').forEach(panel =>
        panel.classList.toggle('hidden', panel.id !== 'panel-' + name));

    PANELS[name]();
}

function openPanel(payload) {
    document.getElementById('admin-overlay').classList.remove('hidden');

    const badge = document.getElementById('sidebar-admin-badge');
    if (badge) {
        badge.innerHTML = `
            <div class="admin-badge-name">${esc(payload?.name || 'Admin')}</div>
            <div class="admin-badge-role">Airdrop control</div>`;
    }

    showPanel('live');
}

function closePanel() {
    document.getElementById('admin-overlay').classList.add('hidden');
    closeModal();
    fetch('https://cipher-airdrops/closePanel', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: '{}',
    }).catch(() => {});
}

window.addEventListener('message', (event) => {
    const data = event.data || {};
    if (data.action === 'open') openPanel(data.payload);
    if (data.action === 'close') closePanel();

    // The server pushes this when a drop changes state, so an admin watching
    // the Live tab sees it land without reopening the panel.
    if (data.action === 'refreshLive' && currentPanel === 'live') renderLive();
});

document.addEventListener('DOMContentLoaded', () => {
    document.querySelectorAll('.nav-item').forEach(item =>
        item.addEventListener('click', () => showPanel(item.dataset.panel)));

    document.getElementById('btn-close').addEventListener('click', closePanel);
});

// Escape closes the panel, unless a modal is open — then it closes the modal
// first, which is what every other panel in the line does.
document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;

    if (document.getElementById('modal-root').innerHTML.trim() !== '') {
        closeModal();
        return;
    }
    closePanel();
});
