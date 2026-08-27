// Shared helpers for the panel.
//
// Everything that renders officer- or admin-typed text goes through esc(). The
// MDT shipped 154 unescaped innerHTML writes before anyone noticed, and a loot
// table is exactly the same shape of problem: an item name is free text typed
// by one admin and rendered into another admin's panel.

function esc(value) {
    if (value === null || value === undefined) return '';
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;');
}

// One request shape for the whole panel. Returns the parsed body, or null when
// the callback is missing or errored — every caller has to handle null anyway,
// so throwing here would just move the check.
async function nui(endpoint, payload = {}) {
    try {
        const res = await fetch(`https://cipher-airdrops/${endpoint}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload),
        });
        return await res.json();
    } catch (e) {
        return null;
    }
}

// ── Toasts ──────────────────────────────────────────────────────────────────

const TOAST_ICONS = { info: 'i', success: '✓', error: '✕', warning: '!' };

function toast(title, body = '', type = 'info', duration = 4200) {
    const el = document.createElement('div');
    el.className = `toast ${type}`;
    el.innerHTML = `
        <div class="toast-icon">${TOAST_ICONS[type] || 'i'}</div>
        <div class="toast-content">
            <div class="toast-title">${esc(title)}</div>
            ${body ? `<div class="toast-body">${esc(body)}</div>` : ''}
        </div>`;

    document.getElementById('toast-container').appendChild(el);

    setTimeout(() => {
        el.style.transition = 'opacity .3s ease, transform .3s ease';
        el.style.opacity = '0';
        el.style.transform = 'translateX(20px)';
        setTimeout(() => el.remove(), 300);
    }, duration);
}

// A server callback that returns { ok = false, error = '...' } is reported with
// the reason it gave. "Failed" tells an admin nothing about what to change.
function reportResult(result, successTitle, successBody) {
    if (result && result.ok) {
        toast(successTitle, successBody || '', 'success');
        return true;
    }
    toast('Could not save', (result && result.error) || 'The server refused it.', 'error');
    return false;
}

// ── Modals ──────────────────────────────────────────────────────────────────

function closeModal() {
    document.getElementById('modal-root').innerHTML = '';
}

// `onConfirm` may return false to keep the modal open, which is what validation
// failures need — closing on a rejected save loses whatever was typed.
//
// Passing no `onConfirm` makes it a read-only view: one button that dismisses
// it. Offering "Cancel" next to "Close" on something with nothing to cancel
// asks the reader to work out a difference that does not exist.
function modal(title, bodyHtml, onConfirm, confirmLabel = 'Save') {
    const root = document.getElementById('modal-root');
    const readOnly = typeof onConfirm !== 'function';

    root.innerHTML = `
        <div class="modal-backdrop">
            <div class="modal">
                <div class="modal-header">
                    <div class="modal-title">${esc(title)}</div>
                    <button class="modal-close" data-modal-cancel>&times;</button>
                </div>
                <div class="modal-body">${bodyHtml}</div>
                <div class="modal-footer">
                    ${readOnly ? '' : '<button class="btn btn-ghost" data-modal-cancel>Cancel</button>'}
                    <button class="btn ${readOnly ? 'btn-ghost' : 'btn-primary'}" data-modal-confirm>
                        ${esc(readOnly ? 'Close' : confirmLabel)}
                    </button>
                </div>
            </div>
        </div>`;

    root.querySelectorAll('[data-modal-cancel]').forEach(el =>
        el.addEventListener('click', closeModal));

    root.querySelector('[data-modal-confirm]').addEventListener('click', async (e) => {
        if (readOnly) { closeModal(); return; }

        const btn = e.currentTarget;
        btn.disabled = true;
        const keepOpen = await onConfirm();
        btn.disabled = false;
        if (keepOpen !== false) closeModal();
    });

    // Focus the first field so a modal opened to type in is ready to type in.
    const first = root.querySelector('input, textarea, select');
    if (first) first.focus();
}

const val = (id) => (document.getElementById(id)?.value || '').trim();
const numVal = (id, fallback = 0) => {
    const n = parseFloat(val(id));
    return Number.isFinite(n) ? n : fallback;
};
const checked = (id) => document.getElementById(id)?.checked === true;

function confirmDelete(what, onYes) {
    modal('Delete ' + what, `
        <p class="text-secondary">This cannot be undone.</p>`,
        onYes, 'Delete');
}

// ── Formatting ──────────────────────────────────────────────────────────────

// Takes an age in seconds, worked out by the database.
//
// Deliberately not a timestamp: a MySQL TIMESTAMP comes back in the server's
// local time, and the player reading this panel may be in any timezone at all,
// so subtracting one from the other on the client is wrong by the offset
// between them. The same reasoning applies to the drop countdown, which is why
// that also travels as seconds rather than a moment in time.
function timeAgo(seconds) {
    const secs = Number(seconds);
    if (!Number.isFinite(secs) || secs < 0) return '—';

    if (secs < 60) return 'just now';
    if (secs < 3600) return `${Math.floor(secs / 60)}m ago`;
    if (secs < 86400) return `${Math.floor(secs / 3600)}h ago`;
    return `${Math.floor(secs / 86400)}d ago`;
}

function emptyState(icon, title, subtitle) {
    return `
        <div class="empty-state">
            <div class="empty-icon">${esc(icon)}</div>
            <div class="empty-title">${esc(title)}</div>
            ${subtitle ? `<div class="empty-subtitle">${esc(subtitle)}</div>` : ''}
        </div>`;
}
