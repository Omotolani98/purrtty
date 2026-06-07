/* ════════════════════════════════════════════════════════════════════
   purrtty-app.js — terminal typewriter + global control bus
   ════════════════════════════════════════════════════════════════════ */
(function () {
  'use strict';
  var REDUCE = window.matchMedia('(prefers-reduced-motion: reduce)').matches;

  function esc(s){return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');}

  // global state shared with Tweaks + settings panel
  var STATE = { cat: 'gray', speed: 1, accent: '#3DDC97' };
  var walkers = [];   // {api, hostRoot}
  var catSinks = [];  // fn(variant) to re-render static cat sprites

  /* ── inline output builders ──────────────────────────────────────── */
  function inlineImage(variant){
    var svg = window.PurrSprites.gridToSVG(window.PurrSprites.GRID_SIT, variant, {pixel:4});
    return '<span class="inline-img">' + svg +
      '<span class="meta"><b>cat.png</b> · 18×14 · <span class="ok">rendered inline</span> · GPU</span></span>';
  }
  function inlineChart(){
    var hs=[40,64,30,72,52,80,46,60];
    var bars = hs.map(function(h,i){return '<span class="bar'+(i%4===3?' b2':'')+'" style="height:'+h+'%"></span>';}).join('');
    return '<span class="px-chart">'+bars+'</span>';
  }
  function inlineGlyphs(){
    var g=['','◴','◷','✓','▰','▱','❯','⛶'];
    return '<span class="glyphs">'+g.map(function(x){return '<span class="gl">'+x+'</span>';}).join('')+'</span>';
  }

  /* ── session script ──────────────────────────────────────────────── */
  function buildScript(){
    return [
      {type:'banner', html:'<span class="comment">purrtty 1.0 · pixel-native tty — sprites, charts &amp; glyphs, drawn on the GPU</span>'},
      {type:'cmd', tokens:[{c:'cmd',t:'purr'},{c:'flag',t:' render '},{c:'str',t:'assets/cat.png'}]},
      {type:'out', delay:260, html:'<span class="ln">'+inlineImage(STATE.cat)+'</span>', sprite:true},
      {type:'cmd', tokens:[{c:'cmd',t:'purr'},{c:'flag',t:' chart '},{c:'str',t:'cpu.log'},{c:'flag',t:' --pixel'}]},
      {type:'out', delay:240, html:'<span class="ln">'+inlineChart()+'</span><span class="ln out">▸ 8 buckets · peak 80% · <span class="ok">drawn in 1 frame</span></span>'},
      {type:'cmd', tokens:[{c:'cmd',t:'purr'},{c:'flag',t:' glyphs '},{c:'flag',t:'--set '},{c:'str',t:'nerd'}]},
      {type:'out', delay:220, html:'<span class="ln">'+inlineGlyphs()+'</span><span class="ln out">▸ 3 sets · 1,842 glyphs · ligatures on</span>'},
      {type:'cmd', tokens:[{c:'cmd',t:'rekord'},{c:'flag',t:' replay '},{c:'str',t:'build.cast'},{c:'flag',t:' --inline'}]},
      {type:'out', delay:240, html:'<span class="ln ok">✓ replayed 240 frames inline · pixel-perfect</span>'},
      {type:'prompt'}
    ];
  }

  function mountTerminal(host){
    if(!host) return {destroy:function(){}};
    var dead=false, timers=[];
    function T(fn,ms){var id=setTimeout(fn,ms);timers.push(id);return id;}

    function clear(){host.innerHTML='';}
    function promptHTML(){return '<span class="prompt">❯ </span>';}

    function staticRender(){
      var s=buildScript();var html='';
      s.forEach(function(step){
        if(step.type==='banner') html+='<span class="ln">'+step.html+'</span>';
        else if(step.type==='cmd'){html+='<span class="ln">'+promptHTML()+step.tokens.map(function(t){return '<span class="'+t.c+'">'+esc(t.t)+'</span>';}).join('')+'</span>';}
        else if(step.type==='out') html+=step.html;
        else if(step.type==='prompt') html+='<span class="ln">'+promptHTML()+'<span class="cursor"></span></span>';
      });
      host.innerHTML=html;
    }

    function run(){
      if(dead) return;
      clear();
      var script=buildScript();
      var i=0;
      function next(){
        if(dead) return;
        if(i>=script.length){ T(function(){ if(!dead){ host.style.transition='opacity .5s'; host.style.opacity='0'; T(function(){host.style.opacity='1';run();},600);} }, 3400); return; }
        var step=script[i++];
        if(step.type==='banner'){ add('<span class="ln">'+step.html+'</span>'); T(next,360/STATE.speed); }
        else if(step.type==='out'){ var el=add(step.html); el.style.opacity='0'; el.style.transition='opacity .25s'; requestAnimationFrame(function(){el.style.opacity='1';}); T(next,(step.delay||220)/STATE.speed); }
        else if(step.type==='prompt'){ add('<span class="ln">'+promptHTML()+'<span class="cursor"></span></span>'); }
        else if(step.type==='cmd'){ typeCmd(step.tokens, next); }
      }
      next();

      function add(html){var d=document.createElement('div');d.innerHTML=html;var node=d.firstChild;host.appendChild(node);host.scrollTop=host.scrollHeight;return node;}
      function typeCmd(tokens, done){
        var line=add('<span class="ln">'+promptHTML()+'<span class="typed"></span><span class="cursor"></span></span>');
        var typed=line.querySelector('.typed');
        var full=tokens.map(function(t){return t.t;}).join('');
        var classes=[]; tokens.forEach(function(t){for(var k=0;k<t.t.length;k++)classes.push(t.c);});
        var ci=0;
        (function tick(){
          if(dead) return;
          if(ci>=full.length){ T(done, 420/STATE.speed); return; }
          ci++;
          // rebuild typed span with per-token classes up to ci
          var html=''; var pos=0;
          tokens.forEach(function(t){
            var seg=t.t.slice(0, Math.max(0, Math.min(t.t.length, ci-pos)));
            if(seg) html+='<span class="'+t.c+'">'+esc(seg)+'</span>';
            pos+=t.t.length;
          });
          typed.innerHTML=html;
          host.scrollTop=host.scrollHeight;
          T(tick, (26+Math.random()*40)/STATE.speed);
        })();
      }
    }

    if(REDUCE) staticRender(); else run();

    // re-render sprite outputs when cat variant changes
    var sink=function(){ /* terminal re-runs naturally on loop; nothing live needed */ };
    catSinks.push(sink);

    return {destroy:function(){dead=true;timers.forEach(clearTimeout);}};
  }

  /* ── control bus (Tweaks + settings panel call these) ────────────── */
  function eachRoot(fn){ document.querySelectorAll('.purr').forEach(fn); }
  var bus = {
    state: STATE,
    registerWalker: function(api, root){ walkers.push({api:api, root:root}); },
    setCat: function(v){ STATE.cat=v; walkers.forEach(function(w){w.api.setVariant(v);}); catSinks.forEach(function(s){s(v);}); },
    setSpeed: function(m){ STATE.speed=m; walkers.forEach(function(w){w.api.setSpeed(m);}); },
    setAccent: function(hex){ STATE.accent=hex; eachRoot(function(r){r.style.setProperty('--accent',hex);}); },
    setFont: function(stack){ eachRoot(function(r){r.style.setProperty('--font-term',stack);}); },
    setScanline: function(v){ eachRoot(function(r){r.style.setProperty('--scanline', String(v));}); },
    setTheme: function(mode){ eachRoot(function(r){ r.classList.toggle('light', mode==='light'); }); },
    mountTerminal: mountTerminal
  };
  window.PurrApp = bus;
})();
