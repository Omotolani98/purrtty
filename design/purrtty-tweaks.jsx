/* ════════════════════════════════════════════════════════════════════
   purrtty-tweaks.jsx — live design knobs → drive the canvas via PurrApp
   ════════════════════════════════════════════════════════════════════ */
const PURR_TWEAK_DEFAULTS = /*EDITMODE-BEGIN*/{
  "accent": "#3DDC97",
  "font": "'JetBrains Mono', ui-monospace, monospace",
  "scanline": 5,
  "theme": "dark",
  "cat": "gray",
  "speed": 1
}/*EDITMODE-END*/;

function PurrttyTweaks() {
  const [t, setTweak] = useTweaks(PURR_TWEAK_DEFAULTS);

  React.useEffect(() => {
    const P = window.PurrApp;
    if (!P) return;
    P.setAccent(t.accent);
    P.setFont(t.font);
    P.setScanline(t.scanline / 100);
    P.setTheme(t.theme);
    P.setCat(t.cat);
    P.setSpeed(t.speed);
  }, [t]);

  return (
    <TweaksPanel title="Tweaks">
      <TweakSection label="Signal" />
      <TweakColor label="Accent" value={t.accent}
        options={['#3DDC97', '#FFB454', '#7AA2F7', '#F2787B']}
        onChange={(v) => setTweak('accent', v)} />

      <TweakSection label="Terminal" />
      <TweakRadio label="Font" value={t.font}
        options={[
          { value: "'JetBrains Mono', ui-monospace, monospace", label: 'JetBrains' },
          { value: "'IBM Plex Mono', ui-monospace, monospace", label: 'Plex' },
          { value: "'Space Mono', ui-monospace, monospace", label: 'Space' }
        ]}
        onChange={(v) => setTweak('font', v)} />
      <TweakSlider label="CRT scanlines" value={t.scanline} min={0} max={16} step={1} unit="%"
        onChange={(v) => setTweak('scanline', v)} />
      <TweakRadio label="Theme" value={t.theme}
        options={[{ value: 'dark', label: 'Dark' }, { value: 'light', label: 'Light' }]}
        onChange={(v) => setTweak('theme', v)} />

      <TweakSection label="Mascot" />
      <TweakRadio label="Cat" value={t.cat}
        options={[{ value: 'gray', label: 'Mochi' }, { value: 'tabby', label: 'Biscuit' }, { value: 'green', label: 'Phosphor' }]}
        onChange={(v) => setTweak('cat', v)} />
      <TweakSlider label="Walk speed" value={t.speed} min={0.3} max={2.5} step={0.1} unit="×"
        onChange={(v) => setTweak('speed', v)} />
    </TweaksPanel>
  );
}

(function () {
  const el = document.getElementById('tweaks-root');
  if (el) ReactDOM.createRoot(el).render(<PurrttyTweaks />);
})();
