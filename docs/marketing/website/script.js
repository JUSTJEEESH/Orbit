// Orbit marketing site — minimal progressive enhancement.
// All CSS-level styling works without this file; this adds two things:
//   1. Scroll-triggered fade-in on `.reveal` elements
//   2. Live copyright year in the footer
//
// Respects prefers-reduced-motion (handled in CSS too, but the
// IntersectionObserver also bails early to avoid wasted work).

(function () {
  'use strict';

  // --- Live year --------------------------------------------------------
  const yearEl = document.getElementById('copy-year');
  if (yearEl) {
    yearEl.textContent = String(new Date().getFullYear());
  }

  // --- Reveal-on-scroll -------------------------------------------------
  const reduceMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const reveals = document.querySelectorAll('.reveal');

  if (reduceMotion || !('IntersectionObserver' in window)) {
    // No animation — just make everything visible immediately.
    reveals.forEach((el) => el.classList.add('is-visible'));
    return;
  }

  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-visible');
          observer.unobserve(entry.target);
        }
      }
    },
    {
      rootMargin: '0px 0px -10% 0px',
      threshold: 0.12,
    }
  );

  reveals.forEach((el) => observer.observe(el));
})();
