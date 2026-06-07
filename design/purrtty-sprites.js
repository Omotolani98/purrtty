/* ════════════════════════════════════════════════════════════════════
   purrtty-sprites.js — CSS/SVG pixel-cat renderer + walk cycle
   One grid, palette-swapped for gray / tabby / green. Crisp at any size.
   ════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';

  /* ── pixel grids ────────────────────────────────────────────────────
     legend: '.' transparent · k outline · g body · l belly/light
             s stripe · e eye · p nose/paw-pad · b blush
     Side-view chonk loaf, facing right. ~22×14.                        */

  // frame A — legs spread (contact)
  var GRID_A = [
    '............kk...kk....',
    '...kk.......kgk.kgk....',
    '..kggk.....kgggkgggk...',
    '..kggk....kgsgggsgggk..',
    '..kgggkkkkggggggggggk..',
    '.kggggggggggggggegggk..',
    '.kggsggggsgggggggggbpk.',
    '.kgllllllllllllllllgk..',
    '.kgllllllllllllllllgk..',
    '.kggkkggkkggggkggkkgk..',
    '.kggk.kggk.kggk.kggk...',
    '.kppk.kppk.kppk.kppk...',
    '.kkk..kkk..kkk..kkk....',
    '......................'
  ].join('\n');

  // frame B — legs gathered (passing) + 1px body lift handled in CSS
  var GRID_B = [
    '............kk...kk....',
    '...kk.......kgk.kgk....',
    '..kggk.....kgggkgggk...',
    '..kggk....kgsgggsgggk..',
    '..kgggkkkkggggggggggk..',
    '.kggggggggggggggegggk..',
    '.kggsggggsgggggggggbpk.',
    '.kgllllllllllllllllgk..',
    '.kgllllllllllllllllgk..',
    '.kgggkkgggkkggkkgggggk.',
    '..kggk..kggkkggk..kggk.',
    '..kppk..kppkkppk..kppk.',
    '..kkk...kkk.kkk...kkk..',
    '......................'
  ].join('\n');

  // sitting pose (front-ish loaf) for the inline "render" demo + cards
  var GRID_SIT = [
    '...kk........kk...',
    '..kggk......kggk..',
    '..kgsgkkkkkkgsgk..',
    '.kggggggggggggggk.',
    '.kgggggggggggggggk',
    'kggeggggggggggeggk',
    'kgggggggkkgggggggk',
    'kggggggkppkggggggk',
    'kgblgggggggggglbgk',
    'kgllllllllllllllgk',
    'kgllllllllllllllgk',
    'kggkkgggggggkkggk.',
    '.kkk.kkkkkkkk.kkk.',
    '.................'
  ].join('\n');

  /* ── palettes ───────────────────────────────────────────────────── */
  var PALETTES = {
    gray: {
      k: '#23252b', g: '#aab1b8', l: '#c8cdd3', s: '#7c838b',
      e: '#1b1d22', p: '#f0a6bf', b: '#f3b9cd'
    },
    tabby: {
      k: '#3a2a1c', g: '#e7a85a', l: '#fbf2e2', s: '#c8842f',
      e: '#2a1d12', p: '#e58aa6', b: '#f0a8c0'
    },
    green: {
      k: '#0c3b27', g: '#3DDC97', l: '#aef5d2', s: '#1f9c66',
      e: '#06231a', p: '#0c3b27', b: '#27c486'
    }
  };

  /* ── grid → SVG ─────────────────────────────────────────────────── */
  function gridToSVG(grid, paletteName, opts) {
    opts = opts || {};
    var pal = PALETTES[paletteName] || PALETTES.gray;
    var rows = grid.replace(/^\n+|\n+$/g, '').split('\n');
    var W = rows.reduce(function (m, r) { return Math.max(m, r.length); }, 0);
    var H = rows.length;
    var rects = '';
    for (var r = 0; r < H; r++) {
      var line = rows[r];
      for (var c = 0; c < line.length; c++) {
        var ch = line[c];
        if (ch === '.' || ch === ' ') continue;
        var fill = pal[ch];
        if (!fill) continue;
        rects += '<rect x="' + c + '" y="' + r + '" width="1" height="1" fill="' + fill + '"/>';
      }
    }
    var w = opts.width || (W * (opts.pixel || 6));
    var h = (w / W) * H;
    var flip = opts.flip ? ' style="transform:scaleX(-1)"' : '';
    return '<svg class="px-sprite" viewBox="0 0 ' + W + ' ' + H + '" width="' + w +
      '" height="' + Math.round(h) + '" shape-rendering="crispEdges"' + flip +
      ' xmlns="http://www.w3.org/2000/svg" role="img" aria-label="pixel cat">' +
      rects + '</svg>';
  }

  /* ── walking mascot ──────────────────────────────────────────────── */
  // A bobbing, waddling sit-loaf that paces left↔right along the bottom.
  // (A loaf hop reads as a cat far better than thin side-view legs.)
  function mountWalker(host, opts) {
    opts = opts || {};
    var variant = opts.variant || 'gray';
    var pixel = opts.pixel || 5;
    opts.speed = opts.speed || 1;

    var wrap = document.createElement('div');
    wrap.className = 'px-walker';
    var inner = document.createElement('div');
    inner.className = 'px-walker-bob';
    wrap.appendChild(inner);

    // shadow puddle under the cat
    var shadow = document.createElement('div');
    shadow.className = 'px-walker-shadow';
    wrap.appendChild(shadow);

    host.appendChild(wrap);

    var dir = 1;            // 1 → right, -1 → left
    var x = 12;
    var step = 0;           // waddle phase
    var stepTimer = null, moveRAF = null;
    var reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

    function render() {
      inner.innerHTML = gridToSVG(GRID_SIT, variant, { pixel: pixel });
    }
    function setVariant(v) { variant = v; render(); }
    function setSpeed(m) { opts.speed = m; }

    function waddle() {
      if (reduce) return;
      step = (step + 1) % 4;
      // lean + bob: 4-phase waddle
      var lean = [-4, 0, 4, 0][step];
      var lift = [0, -3, 0, -3][step];
      inner.style.transform = 'translateY(' + lift + 'px) rotate(' + (dir < 0 ? -lean : lean) + 'deg)';
      shadow.style.transform = 'scaleX(' + (lift ? 0.82 : 1) + ')';
      stepTimer = setTimeout(waddle, 150 / (opts.speed || 1));
    }

    var last = null;
    function move(ts) {
      if (last == null) last = ts;
      var dt = (ts - last) / 1000; last = ts;
      var hostW = host.clientWidth;
      var spriteW = wrap.offsetWidth;
      var pad = 8;
      x += dir * 24 * (opts.speed || 1) * dt;
      if (x < pad) { x = pad; dir = 1; }
      else if (x > hostW - spriteW - pad) { x = hostW - spriteW - pad; dir = -1; }
      // face travel direction (sit pose is symmetric, but flip for personality)
      wrap.style.left = x + 'px';
      wrap.style.setProperty('--facing', dir < 0 ? '-1' : '1');
      moveRAF = requestAnimationFrame(move);
    }

    render();
    if (!reduce) {
      waddle();
      moveRAF = requestAnimationFrame(move);
    } else {
      wrap.style.left = '42%';
    }

    return {
      setVariant: setVariant,
      setSpeed: setSpeed,
      destroy: function () { clearTimeout(stepTimer); cancelAnimationFrame(moveRAF); wrap.remove(); }
    };
  }

  window.PurrSprites = {
    gridToSVG: gridToSVG,
    mountWalker: mountWalker,
    GRID_A: GRID_A, GRID_B: GRID_B, GRID_SIT: GRID_SIT,
    PALETTES: PALETTES
  };
})();
