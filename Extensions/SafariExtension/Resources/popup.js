// Toolbar popup. Forwards a `clip-current` ask to the service worker
// so the network of clipping logic stays in one place.

const button = document.getElementById("save");
const status = document.getElementById("status");

button.addEventListener("click", async () => {
  button.disabled = true;
  status.textContent = "Saving…";
  status.dataset.state = "";

  try {
    const result = await browser.runtime.sendMessage({ kind: "clip-current" });
    if (result?.ok) {
      status.textContent = "Saved to Orbit.";
      status.dataset.state = "ok";
      setTimeout(() => window.close(), 600);
    } else {
      throw new Error(result?.error || "Couldn't reach Orbit.");
    }
  } catch (e) {
    status.textContent = e?.message || "Couldn't reach Orbit.";
    status.dataset.state = "err";
    button.disabled = false;
  }
});
