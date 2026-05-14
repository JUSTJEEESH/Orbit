// Orbit Safari Web Extension — service worker.
//
// Wires three entry points:
//   1. Toolbar button (browser.action.onClicked) — sends URL + title.
//   2. Context menu "Save page" — same payload as the toolbar.
//   3. Context menu "Save selection" — same payload + selected text.
//
// All paths converge on `clip(payload)`, which forwards a single
// "clip" message to the native Swift handler. The handler writes
// the payload into the App Group inbox where the host app drains it.

const NATIVE_MESSAGE = "clip";

browser.runtime.onInstalled.addListener(async () => {
  try {
    await browser.contextMenus.create({
      id: "orbit-save-page",
      title: browser.i18n.getMessage("context_save_page"),
      contexts: ["page", "frame"]
    });
    await browser.contextMenus.create({
      id: "orbit-save-selection",
      title: browser.i18n.getMessage("context_save_selection"),
      contexts: ["selection"]
    });
  } catch (e) {
    // Re-installs can throw "already exists" — harmless.
    console.log("Orbit: context menu install:", e?.message ?? e);
  }
});

browser.action.onClicked.addListener(async (tab) => {
  await clipFromTab(tab);
});

browser.contextMenus.onClicked.addListener(async (info, tab) => {
  if (!tab) return;
  if (info.menuItemId === "orbit-save-selection") {
    await clipFromTab(tab, info.selectionText || "");
  } else if (info.menuItemId === "orbit-save-page") {
    await clipFromTab(tab);
  }
});

// Popup uses this same channel so the toolbar fallback works even when
// activeTab can't fire (e.g., new tab page).
browser.runtime.onMessage.addListener(async (request, sender) => {
  if (request?.kind === "clip-current") {
    const [tab] = await browser.tabs.query({ active: true, currentWindow: true });
    return clipFromTab(tab, request.selection || "");
  }
});

async function clipFromTab(tab, selection = "") {
  if (!tab) return { ok: false };
  const payload = {
    kind: NATIVE_MESSAGE,
    url: tab.url || "",
    title: tab.title || "",
    selection,
    capturedAt: new Date().toISOString()
  };
  try {
    const response = await browser.runtime.sendNativeMessage("com.joshgreen.orbit.safari", payload);
    return response ?? { ok: false };
  } catch (e) {
    console.log("Orbit: native message failed:", e?.message ?? e);
    return { ok: false, error: String(e) };
  }
}
