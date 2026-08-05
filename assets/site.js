/* Tierra Métrica — comportamiento compartido */
(function () {
  'use strict';

  var menosMovimiento = window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  /* ── Menú móvil ── */
  var toggle = document.getElementById('navToggle');
  var links  = document.getElementById('navLinks');
  if (toggle && links) {
    toggle.addEventListener('click', function () {
      var abierto = toggle.getAttribute('aria-expanded') === 'true';
      toggle.setAttribute('aria-expanded', String(!abierto));
      toggle.setAttribute('aria-label', abierto ? 'Abrir menú' : 'Cerrar menú');
      links.classList.toggle('open', !abierto);
    });
    links.addEventListener('click', function (e) {
      if (e.target.closest('a')) {
        toggle.setAttribute('aria-expanded', 'false');
        toggle.setAttribute('aria-label', 'Abrir menú');
        links.classList.remove('open');
      }
    });
  }

  /* ── Aparición escalonada de elementos al entrar en pantalla ── */
  var aRevelar = document.querySelectorAll('.reveal');
  if (aRevelar.length) {
    if (menosMovimiento || !('IntersectionObserver' in window)) {
      // Sin animación: se muestran de inmediato
      Array.prototype.forEach.call(aRevelar, function (el) { el.classList.add('visible'); });
    } else {
      var observador = new IntersectionObserver(function (entradas) {
        entradas.forEach(function (entrada) {
          if (!entrada.isIntersecting) return;
          var i = Array.prototype.indexOf.call(aRevelar, entrada.target);
          entrada.target.style.transitionDelay = (Math.max(i, 0) * 110) + 'ms';
          entrada.target.classList.add('visible');
          observador.unobserve(entrada.target);
        });
      }, { threshold: 0.15 });
      Array.prototype.forEach.call(aRevelar, function (el) { observador.observe(el); });
    }
  }

  /* ── Carrusel de análisis ── */
  var pista = document.getElementById('blogTrack');
  if (!pista) return;

  var anterior = document.getElementById('carPrev');
  var siguiente = document.getElementById('carNext');
  var puntos   = document.getElementById('carDots');
  var botonPlay = document.getElementById('carPlay');
  var iconoPlay = document.getElementById('carPlayIcon');
  var textoPlay = document.getElementById('carPlayTxt');

  var tarjetas = pista.querySelectorAll('.post-card');
  var total = tarjetas.length;
  if (!total) return;

  var INTERVALO = 6000;
  var temporizador = null;
  var corriendo = false;

  function paso() {
    var primera = tarjetas[0];
    if (!primera) return pista.clientWidth;
    var hueco = parseFloat(getComputedStyle(pista).columnGap) || 20;
    return primera.getBoundingClientRect().width + hueco;
  }

  function indiceActual() {
    var i = Math.round(pista.scrollLeft / paso());
    return Math.min(Math.max(i, 0), total - 1);
  }

  /* Indicadores */
  var listaPuntos = [];
  if (puntos) {
    for (var i = 0; i < total; i++) {
      (function (idx) {
        var b = document.createElement('button');
        b.className = 'car-dot';
        b.type = 'button';
        b.setAttribute('role', 'tab');
        b.setAttribute('aria-label', 'Ir al análisis ' + (idx + 1) + ' de ' + total);
        b.addEventListener('click', function () {
          pista.scrollTo({ left: idx * paso(), behavior: menosMovimiento ? 'auto' : 'smooth' });
          pausar();
        });
        puntos.appendChild(b);
        listaPuntos.push(b);
      })(i);
    }
  }

  function refrescar() {
    // 2px de tolerancia: los navegadores redondean scrollLeft
    var max = pista.scrollWidth - pista.clientWidth;
    if (anterior)  anterior.disabled  = pista.scrollLeft <= 2;
    if (siguiente) siguiente.disabled = pista.scrollLeft >= max - 2;

    var act = indiceActual();
    listaPuntos.forEach(function (p, idx) {
      p.setAttribute('aria-current', idx === act ? 'true' : 'false');
    });
  }

  /* Avance automático. WCAG 2.2.2 exige poder detenerlo: hay botón,
     y además se pausa solo al interactuar o al perder visibilidad. */
  function arrancar() {
    if (menosMovimiento || corriendo || total < 2) return;
    corriendo = true;
    temporizador = setInterval(function () {
      var max = pista.scrollWidth - pista.clientWidth;
      if (pista.scrollLeft >= max - 2) {
        pista.scrollTo({ left: 0, behavior: 'smooth' });
      } else {
        pista.scrollBy({ left: paso(), behavior: 'smooth' });
      }
    }, INTERVALO);
    if (botonPlay) {
      botonPlay.setAttribute('aria-label', 'Pausar el avance automático');
      if (textoPlay) textoPlay.textContent = 'Pausar';
      if (iconoPlay) iconoPlay.innerHTML =
        '<rect x="6" y="5" width="4" height="14" rx="1"/><rect x="14" y="5" width="4" height="14" rx="1"/>';
    }
  }

  function pausar() {
    corriendo = false;
    clearInterval(temporizador);
    temporizador = null;
    if (botonPlay) {
      botonPlay.setAttribute('aria-label', 'Reanudar el avance automático');
      if (textoPlay) textoPlay.textContent = 'Reanudar';
      if (iconoPlay) iconoPlay.innerHTML = '<path d="M7 4l12 8-12 8z"/>';
    }
  }

  if (botonPlay) {
    botonPlay.addEventListener('click', function () {
      if (corriendo) { pausar(); } else { arrancar(); }
    });
  }

  if (anterior) {
    anterior.addEventListener('click', function () {
      pista.scrollBy({ left: -paso(), behavior: menosMovimiento ? 'auto' : 'smooth' });
      pausar();
    });
  }
  if (siguiente) {
    siguiente.addEventListener('click', function () {
      pista.scrollBy({ left: paso(), behavior: menosMovimiento ? 'auto' : 'smooth' });
      pausar();
    });
  }

  // Si el visitante está leyendo o navegando con teclado, no se le mueve debajo
  pista.addEventListener('mouseenter', pausar);
  pista.addEventListener('focusin', pausar);
  pista.addEventListener('touchstart', pausar, { passive: true });

  // Tampoco corre en una pestaña que no se está viendo
  document.addEventListener('visibilitychange', function () {
    if (document.hidden) { clearInterval(temporizador); temporizador = null; }
    else if (corriendo) { corriendo = false; arrancar(); }
  });

  pista.addEventListener('scroll', refrescar, { passive: true });
  window.addEventListener('resize', refrescar);

  refrescar();
  arrancar();
})();
