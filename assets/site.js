/* Tierra Métrica — comportamiento compartido */
(function () {
  'use strict';

  /* ── Menú móvil ── */
  var toggle = document.getElementById('navToggle');
  var links  = document.getElementById('navLinks');
  if (toggle && links) {
    toggle.addEventListener('click', function () {
      var open = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!open));
      toggle.setAttribute('aria-label', open ? 'Abrir menú' : 'Cerrar menú');
      links.classList.toggle('open', !open);
    });
    // Cerrar al elegir un destino
    links.addEventListener('click', function (e) {
      if (e.target.closest('a')) {
        toggle.setAttribute('aria-expanded', 'false');
        toggle.setAttribute('aria-label', 'Abrir menú');
        links.classList.remove('open');
      }
    });
  }

  /* ── Carrusel de análisis ── */
  var track = document.getElementById('blogTrack');
  var prev  = document.getElementById('carPrev');
  var next  = document.getElementById('carNext');

  if (track && prev && next) {
    // Avanza una tarjeta completa (ancho + gap)
    function step() {
      var card = track.querySelector('.post-card');
      if (!card) return track.clientWidth;
      var gap = parseFloat(getComputedStyle(track).columnGap) || 20;
      return card.getBoundingClientRect().width + gap;
    }

    function refresh() {
      // 2px de tolerancia: los navegadores redondean scrollLeft
      var max = track.scrollWidth - track.clientWidth;
      prev.disabled = track.scrollLeft <= 2;
      next.disabled = track.scrollLeft >= max - 2;
    }

    prev.addEventListener('click', function () { track.scrollBy({ left: -step(), behavior: 'smooth' }); });
    next.addEventListener('click', function () { track.scrollBy({ left:  step(), behavior: 'smooth' }); });

    track.addEventListener('scroll', refresh, { passive: true });
    window.addEventListener('resize', refresh);
    refresh();
  }
})();
