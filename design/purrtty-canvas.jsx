/* ════════════════════════════════════════════════════════════════════
   purrtty-canvas.jsx — design canvas: terminal · sprites · settings
   ════════════════════════════════════════════════════════════════════ */
const { useState, useEffect, useRef } = React;
const App = window;

const ACCENTS = ['#3DDC97', '#FFB454', '#7AA2F7', '#F2787B'];
const FONTS = [
  { label: 'JetBrains', stack: "'JetBrains Mono', ui-monospace, monospace" },
  { label: 'Plex', stack: "'IBM Plex Mono', ui-monospace, monospace" },
  { label: 'Space', stack: "'Space Mono', ui-monospace, monospace" }
];
const CATS = [
  { id: 'gray', name: 'mochi', sub: 'gray chonk · the default', pal: ['#23252b', '#aab1b8', '#c8cdd3', '#f0a6bf'] },
  { id: 'tabby', name: 'biscuit', sub: 'orange tabby · warm', pal: ['#3a2a1c', '#e7a85a', '#fbf2e2', '#e58aa6'] },
  { id: 'green', name: 'phosphor', sub: 'crt green · themed', pal: ['#0c3b27', '#3DDC97', '#aef5d2', '#1f9c66'] }
];

/* ── window chrome shell ─────────────────────────────────────────── */
function Win({ title, fav, children }) {
  return (
    <div className="win">
      <div className="win-bar">
        <div className="lights"><i className="r"></i><i className="y"></i><i className="g"></i></div>
        <div className="win-title">
          {fav}
          <span>{title}</span>
          <span className="blink"></span>
        </div>
      </div>
      {children}
    </div>
  );
}

/* favicon = tiny pixel cat head */
function FavCat() {
  const ref = useRef(null);
  useEffect(() => {
    if (ref.current) ref.current.innerHTML =
      window.PurrSprites.gridToSVG(window.PurrSprites.GRID_SIT, 'gray', { pixel: 1, width: 15 });
  }, []);
  return <span className="fav" ref={ref}></span>;
}

/* ── hero terminal ───────────────────────────────────────────────── */
function HeroTerminal() {
  const rootRef = useRef(null);
  const termRef = useRef(null);
  useEffect(() => {
    if (rootRef.current) rootRef.current.style.setProperty('--accent', window.PurrApp.state.accent);
    const term = window.PurrApp.mountTerminal(termRef.current);
    const walker = window.PurrSprites.mountWalker(termRef.current, {
      variant: window.PurrApp.state.cat, pixel: 4, speed: window.PurrApp.state.speed
    });
    window.PurrApp.registerWalker(walker, rootRef.current);
    return () => { term.destroy(); walker.destroy(); };
  }, []);
  return (
    <div className="purr" ref={rootRef} style={{ height: '100%' }}>
      <Win title="purrtty — ~/demos" fav={<FavCat />}>
        <div className="term" ref={termRef}></div>
      </Win>
    </div>
  );
}

/* ── cat catalog card ────────────────────────────────────────────── */
function CatCard({ cat }) {
  const stageRef = useRef(null);
  useEffect(() => {
    if (stageRef.current)
      stageRef.current.innerHTML =
        window.PurrSprites.gridToSVG(window.PurrSprites.GRID_SIT, cat.id, { pixel: 8 });
  }, [cat.id]);
  return (
    <div className="purr" style={{ height: '100%' }}>
      <div className="catcard">
        <div className="stage"><div ref={stageRef} className="idle-bob"></div></div>
        <div className="info">
          <div className="nm">{cat.name}{cat.id === 'gray' && <span className="live">default</span>}</div>
          <div className="sub">{cat.sub}</div>
          <div className="palette">{cat.pal.map((c, i) => <i key={i} style={{ background: c }}></i>)}</div>
        </div>
      </div>
    </div>
  );
}

/* ── controls ────────────────────────────────────────────────────── */
function Seg({ value, options, onChange, acc }) {
  return (
    <div className="seg">
      {options.map(o => (
        <button key={o.value} className={(value === o.value ? 'on' : '') + (acc ? ' acc' : '')}
          onClick={() => onChange(o.value)}>{o.label}</button>
      ))}
    </div>
  );
}
function Toggle({ on, onChange }) {
  return <div className={'tog' + (on ? ' on' : '')} onClick={() => onChange(!on)}><div className="knob"></div></div>;
}
function Slider({ value, min, max, step, onChange, fmt }) {
  const ref = useRef(null);
  const pct = (value - min) / (max - min) * 100;
  function set(clientX) {
    const r = ref.current.getBoundingClientRect();
    let p = (clientX - r.left) / r.width;
    p = Math.max(0, Math.min(1, p));
    let v = min + p * (max - min);
    v = Math.round(v / step) * step;
    onChange(+v.toFixed(4));
  }
  function down(e) {
    set(e.clientX);
    const mv = (ev) => set(ev.clientX);
    const up = () => { window.removeEventListener('pointermove', mv); window.removeEventListener('pointerup', up); };
    window.addEventListener('pointermove', mv); window.addEventListener('pointerup', up);
  }
  return (
    <div className="ctl">
      <div className="slide" ref={ref} onPointerDown={down} style={{ cursor: 'pointer' }}>
        <div className="fill" style={{ width: pct + '%' }}></div>
        <div className="thumb" style={{ left: pct + '%' }}></div>
      </div>
      <span className="slide-val">{fmt ? fmt(value) : value}</span>
    </div>
  );
}
function MiniCat({ id }) {
  const ref = useRef(null);
  useEffect(() => { if (ref.current) ref.current.innerHTML = window.PurrSprites.gridToSVG(window.PurrSprites.GRID_SIT, id, { pixel: 2, width: 40 }); }, [id]);
  return <span ref={ref}></span>;
}

/* ── settings panel ──────────────────────────────────────────────── */
function PrefsPanel() {
  const rootRef = useRef(null);
  const [theme, setTheme] = useState('dark');
  const [accent, setAccent] = useState('#3DDC97');
  const [font, setFont] = useState(FONTS[0].stack);
  const [scan, setScan] = useState(0.05);
  const [cat, setCat] = useState('gray');
  const [speed, setSpeed] = useState(1);
  const [mascot, setMascot] = useState(true);
  const [imgProto, setImgProto] = useState(true);
  const [glyphs, setGlyphs] = useState(true);
  const [gpu, setGpu] = useState(true);

  // drive this panel's own look
  useEffect(() => { if (rootRef.current) { rootRef.current.style.setProperty('--accent', accent); rootRef.current.style.setProperty('--scanline', String(scan)); rootRef.current.classList.toggle('light', theme === 'light'); } }, [accent, scan, theme]);

  const SIDE = [
    { id: 'general', label: 'General', ic: 'M3 5h14M3 10h14M3 15h9' },
    { id: 'appear', label: 'Appearance', ic: 'M10 3a7 7 0 100 14 4 4 0 010-8 3 3 0 003-3 3 3 0 00-3-3z' },
    { id: 'sprites', label: 'Sprites & Cat', ic: 'M4 7l2-3 2 3M12 7l2-3 2 3M4 7v6a4 4 0 008 0V7' },
    { id: 'pixels', label: 'Pixel Protocol', ic: 'M3 3h6v6H3zM11 3h6v6h-6zM3 11h6v6H3zM11 11h6v6h-6z' },
    { id: 'keys', label: 'Keybindings', ic: 'M3 6h14v8H3zM6 9h0M9 9h0M12 9h0' }
  ];

  return (
    <div className="purr" ref={rootRef} style={{ height: '100%' }}>
      <Win title="purrtty — preferences" fav={<FavCat />}>
        <div className="prefs">
          <div className="prefs-side">
            <div className="grp">// settings</div>
            {SIDE.map(s => (
              <div key={s.id} className={'item' + (s.id === 'sprites' ? ' active' : '')}>
                <svg className="ic" viewBox="0 0 20 20" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round"><path d={s.ic} /></svg>
                {s.label}
              </div>
            ))}
          </div>
          <div className="prefs-body">
            <h2 className="prefs-h">Sprites &amp; Cat</h2>
            <p className="prefs-sub">// the mascot, themeable sprites, and the pixel protocols that draw them</p>

            <div className="row">
              <div className="lbl"><div className="t">Mascot cat</div><div className="d">who paces your terminal</div></div>
              <div className="ctl">
                <div className="cat-pick">
                  {CATS.map(c => (
                    <button key={c.id} className={cat === c.id ? 'on' : ''} onClick={() => { setCat(c.id); window.PurrApp.setCat(c.id); }}>
                      <MiniCat id={c.id} />
                      <span className="cap">{c.name}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="row">
              <div className="lbl"><div className="t">Walk speed</div><div className="d">mascot pace multiplier</div></div>
              <Slider value={speed} min={0.3} max={2.5} step={0.1} onChange={(v) => { setSpeed(v); window.PurrApp.setSpeed(v); }} fmt={(v) => v.toFixed(1) + '×'} />
            </div>

            <div className="row">
              <div className="lbl"><div className="t">Show mascot</div><div className="d">disable for focus mode</div></div>
              <div className="ctl"><Toggle on={mascot} onChange={setMascot} /></div>
            </div>

            <div className="row">
              <div className="lbl"><div className="t">Accent</div><div className="d">prompt · cursor · sprites</div></div>
              <div className="ctl">
                <div className="swatches">
                  {ACCENTS.map(a => <button key={a} className={accent === a ? 'on' : ''} style={{ background: a }} onClick={() => { setAccent(a); window.PurrApp.setAccent(a); }}></button>)}
                </div>
              </div>
            </div>

            <div className="row">
              <div className="lbl"><div className="t">CRT scanlines</div><div className="d">phosphor glow overlay</div></div>
              <Slider value={scan} min={0} max={0.16} step={0.01} onChange={(v) => { setScan(v); window.PurrApp.setScanline(v); }} fmt={(v) => Math.round(v / 0.16 * 100) + '%'} />
            </div>

            <div className="row">
              <div className="lbl"><div className="t">Pixel protocol</div><div className="d">image/sprite · glyphs · GPU</div></div>
              <div className="ctl" style={{ gap: 18 }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: 7, fontFamily: 'var(--font-term)', fontSize: 12, color: 'var(--dim)' }}>img <Toggle on={imgProto} onChange={setImgProto} /></span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 7, fontFamily: 'var(--font-term)', fontSize: 12, color: 'var(--dim)' }}>glyphs <Toggle on={glyphs} onChange={setGlyphs} /></span>
                <span style={{ display: 'flex', alignItems: 'center', gap: 7, fontFamily: 'var(--font-term)', fontSize: 12, color: 'var(--dim)' }}>gpu <Toggle on={gpu} onChange={setGpu} /></span>
              </div>
            </div>
          </div>
        </div>
      </Win>
    </div>
  );
}

/* ── canvas layout ───────────────────────────────────────────────── */
function PurrttyCanvas() {
  const { DesignCanvas, DCSection, DCArtboard } = window;
  return (
    <DesignCanvas>
      <DCSection id="terminal" title="The terminal" subtitle="purrtty — pixel-native tty · fully live">
        <DCArtboard id="hero" label="purrtty · live session" width={940} height={600}>
          <HeroTerminal />
        </DCArtboard>
      </DCSection>

      <DCSection id="sprites" title="Cat sprites" subtitle="Themeable pixel mascots — pick one">
        {CATS.map(c => (
          <DCArtboard key={c.id} id={'cat-' + c.id} label={c.name + ' · ' + c.id} width={280} height={300}>
            <CatCard cat={c} />
          </DCArtboard>
        ))}
      </DCSection>

      <DCSection id="settings" title="Settings" subtitle="Sprites, pixel protocol & appearance — controls are live, drive the terminal">
        <DCArtboard id="prefs" label="preferences · sprites & pixels" width={820} height={560}>
          <PrefsPanel />
        </DCArtboard>
      </DCSection>
    </DesignCanvas>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<PurrttyCanvas />);
