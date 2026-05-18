<script>
  import { onMount } from 'svelte';

  let showBanner = false;
  let isIOS = false;
  let deferredPrompt = null;

  const DISMISS_KEY = 'pwa_install_dismissed';
  const DISMISS_MS = 10_000;

  function wasDismissedRecently() {
    try {
      const val = localStorage.getItem(DISMISS_KEY);
      if (!val) return false;
      return (Date.now() - parseInt(val, 10)) < DISMISS_MS;
    } catch {
      return false;
    }
  }

  function dismiss() {
    try { localStorage.setItem(DISMISS_KEY, Date.now().toString()); } catch {}
    showBanner = false;
    setTimeout(() => { showBanner = true; }, DISMISS_MS);
  }

  async function install() {
    if (!deferredPrompt) return;
    deferredPrompt.prompt();
    const { outcome } = await deferredPrompt.userChoice;
    deferredPrompt = null;
    if (outcome === 'accepted') showBanner = false;
  }

  onMount(() => {
    const isStandalone =
      window.navigator.standalone === true ||
      window.matchMedia('(display-mode: standalone)').matches;
    if (isStandalone || wasDismissedRecently()) return;

    const ua = navigator.userAgent;
    isIOS = /iphone|ipad|ipod/i.test(ua);

    if (isIOS) {
      showBanner = true;
    } else {
      window.addEventListener('beforeinstallprompt', (e) => {
        e.preventDefault();
        deferredPrompt = e;
        showBanner = true;
      });
    }

    window.addEventListener('appinstalled', () => { showBanner = false; });
  });
</script>

{#if showBanner}
  <div class="install-banner" role="dialog" aria-label="Install app">
    <img src="/apple-touch-icon.png" alt="" class="banner-icon" />
    <div class="banner-body">
      <p class="banner-title">Superligaen</p>
      {#if isIOS}
        <p class="banner-text">
          To install, tap
          <!-- iOS share icon -->
          <svg class="inline-icon" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <path d="M9 1v11M5 4l4-4 4 4" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"/>
            <path d="M3 8v7a1 1 0 001 1h10a1 1 0 001-1V8" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
          </svg>
          and then <strong>Add to Home Screen</strong>
          <!-- iOS add icon -->
          <svg class="inline-icon" viewBox="0 0 18 18" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
            <rect x="1" y="1" width="16" height="16" rx="3" stroke="currentColor" stroke-width="1.6"/>
            <path d="M9 5v8M5 9h8" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/>
          </svg>
        </p>
      {:else}
        <p class="banner-text">Add to your home screen for quick access.</p>
      {/if}
    </div>

    {#if !isIOS}
      <button class="install-btn" on:click={install}>Install</button>
    {/if}

    <button class="close-btn" on:click={dismiss} aria-label="Dismiss">
      <svg viewBox="0 0 14 14" fill="none" xmlns="http://www.w3.org/2000/svg" aria-hidden="true">
        <path d="M1 1l12 12M13 1L1 13" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>
      </svg>
    </button>

    <!-- Triangle pointer toward the Safari toolbar -->
    {#if isIOS}
      <div class="banner-arrow" aria-hidden="true"></div>
    {/if}
  </div>
{/if}

<style>
  .install-banner {
    position: fixed;
    bottom: 1rem;
    left: 1rem;
    right: 1rem;
    z-index: 9999;
    display: flex;
    align-items: center;
    gap: 0.75rem;
    padding: 0.875rem 0.875rem 0.875rem 0.875rem;
    background: #ffffff;
    border-radius: 14px;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.18), 0 1px 4px rgba(0, 0, 0, 0.1);
  }

  .banner-icon {
    width: 52px;
    height: 52px;
    border-radius: 12px;
    flex-shrink: 0;
  }

  .banner-body {
    flex: 1;
    min-width: 0;
  }

  .banner-title {
    font-size: 0.9rem;
    font-weight: 700;
    color: #111;
    margin: 0 0 0.15rem 0;
    line-height: 1.2;
  }

  .banner-text {
    font-size: 0.8rem;
    color: #444;
    margin: 0;
    line-height: 1.4;
  }

  .banner-text strong {
    font-weight: 700;
    color: #111;
  }

  .inline-icon {
    display: inline;
    width: 1em;
    height: 1em;
    vertical-align: -0.15em;
    color: #007aff;
  }

  .install-btn {
    flex-shrink: 0;
    padding: 0.4rem 0.9rem;
    background: #2563eb;
    color: #fff;
    border: none;
    border-radius: 999px;
    font-size: 0.85rem;
    font-weight: 600;
    cursor: pointer;
  }

  .install-btn:active {
    opacity: 0.85;
  }

  .close-btn {
    flex-shrink: 0;
    align-self: flex-start;
    width: 24px;
    height: 24px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: none;
    border: none;
    cursor: pointer;
    color: #aaa;
    padding: 0;
    border-radius: 50%;
  }

  .close-btn:active {
    color: #555;
  }

  .close-btn svg {
    width: 12px;
    height: 12px;
  }

  .banner-arrow {
    position: absolute;
    bottom: -8px;
    left: 50%;
    transform: translateX(-50%);
    width: 0;
    height: 0;
    border-left: 9px solid transparent;
    border-right: 9px solid transparent;
    border-top: 9px solid #ffffff;
    filter: drop-shadow(0 2px 2px rgba(0,0,0,0.08));
  }
</style>
