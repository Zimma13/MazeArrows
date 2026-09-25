// onboarding-screens.jsx — Day-0 onboarding: cold start, ATT, tutorial L1–L3,
// L4 auto-start. Reuses PIECES / MazePiece / PuzzleBoard / ui primitives.
// Copy is Russian (per onboarding-spec.md §3–§4).

// ─── Tutorial board layouts (spec §4, 6×6 grid → % coords) ─────
const TUT_LAYOUTS = {
  L1: [
    { id: 'A', type: 'arrowLeft',  x: 16.7, y: 25,   w: 30, h: 13 },
    { id: 'B', type: 'arrowRight', x: 83.3, y: 25,   w: 30, h: 13 },
    { id: 'C', type: 'arrowDown',  x: 41.7, y: 66.7, w: 13, h: 30 },
    { id: 'D', type: 'arrowUp',    x: 58.3, y: 50,   w: 13, h: 30 },
  ],
  L2: [
    { id: 'X', type: 'arrowRight', x: 18,   y: 58.3, w: 30, h: 13 },
    { id: 'B', type: 'arrowUp',    x: 75,   y: 50,   w: 13, h: 30 },
    { id: 'C', type: 'arrowLeft',  x: 33.3, y: 25,   w: 30, h: 13 },
    { id: 'D', type: 'arrowDown',  x: 58.3, y: 83.3, w: 13, h: 30 },
    { id: 'E', type: 'arrowRight', x: 33.3, y: 9,    w: 30, h: 13 },
  ],
  L3: [
    { id: 'A', type: 'arrowRight', x: 83.3, y: 9,    w: 30, h: 13 },
    { id: 'B', type: 'arrowDown',  x: 91.7, y: 50,   w: 13, h: 30 },
    { id: 'C', type: 'arrowUp',    x: 25,   y: 50,   w: 13, h: 30 },
    { id: 'D', type: 'arrowLeft',  x: 50,   y: 58.3, w: 30, h: 13 },
    { id: 'E', type: 'arrowUp',    x: 58.3, y: 83.3, w: 13, h: 30 },
    { id: 'F', type: 'arrowLeft',  x: 18,   y: 91.7, w: 26, h: 13 },
  ],
};

// A compact square tutorial board with dim + spotlight cutout + hand ghost.
function TutorialBoard({
  theme, layout, size = 300,
  spotlight,           // { x, y } in % — target piece to reveal
  highlightId,         // piece id to render in a special state
  highlightState,      // 'hint' | 'blocked' | 'free'
  ghostTrail,          // id of piece flying out (slow-mo)
  hand = true,
}) {
  const pieces = TUT_LAYOUTS[layout] ?? [];
  const px = (p) => (p / 100) * size;
  return (
    <div style={{ position: 'relative', width: size, height: size }}>
      <PuzzleBoard theme={theme} width={size} height={size} radius={26}
        pieceStrokeWidth={7} showMotif={false}
        pieces={pieces.map(p => ({
          type: p.type, x: p.x, y: p.y, w: p.w, h: p.h,
          state: p.id === highlightId ? highlightState : (p.id === ghostTrail ? 'ghost' : 'normal'),
          color: p.id === highlightId && highlightState === 'hint' ? '#FFB020'
               : p.id === highlightId && highlightState === 'free' ? theme.accent : undefined,
        }))}
      />

      {/* slow-mo fly-out trail */}
      {ghostTrail && (() => {
        const g = pieces.find(p => p.id === ghostTrail);
        if (!g) return null;
        return [0.62, 0.42, 0.24].map((op, i) => (
          <div key={i} style={{
            position: 'absolute', left: px(g.x) - px(g.w) / 2 - (i + 1) * 16,
            top: px(g.y) - px(g.h) / 2,
            width: px(g.w), height: px(g.h), opacity: op,
            transform: `scale(${1 - i * 0.14})`, transformOrigin: 'center',
          }}>
            <MazePiece paths={PIECES[g.type].paths} width={px(g.w)} height={px(g.h)}
              stroke={theme.accent} strokeWidth={6} emboss={false}/>
          </div>
        ));
      })()}

      {/* dim + spotlight */}
      {spotlight && (
        <div style={{ position: 'absolute', inset: 0, borderRadius: 26, overflow: 'hidden' }}>
          <div style={{
            position: 'absolute',
            left: px(spotlight.x), top: px(spotlight.y),
            width: 4, height: 4, borderRadius: '50%',
            transform: 'translate(-50%,-50%)',
            boxShadow: `0 0 0 42px rgba(15,16,30,0.02), 0 0 0 9999px rgba(15,16,30,0.55)`,
          }}/>
          {/* highlight ring */}
          <div style={{
            position: 'absolute', left: px(spotlight.x), top: px(spotlight.y),
            width: 66, height: 66, borderRadius: '50%',
            transform: 'translate(-50%,-50%)',
            border: `2px solid ${theme.accent}`, opacity: 0.9,
            boxShadow: `0 0 22px ${theme.accent}88`,
          }}/>
        </div>
      )}

      {/* hand-ghost cursor */}
      {spotlight && hand && (
        <div style={{
          position: 'absolute', left: px(spotlight.x) + 20, top: px(spotlight.y) + 20,
          transform: 'translate(-50%,-50%)', pointerEvents: 'none',
        }}>
          <div style={{
            width: 34, height: 34, borderRadius: '50%',
            border: `3px solid ${theme.accent}`, opacity: 0.35,
            position: 'absolute', left: -6, top: -6,
          }}/>
          <svg width="30" height="34" viewBox="0 0 30 34">
            <path d="M11 3a3 3 0 0 1 6 0v13l3-3a2.6 2.6 0 0 1 4 3l-6 9a7 7 0 0 1-6 3.5h-3a7 7 0 0 1-7-7V16a2.6 2.6 0 0 1 5 0v-2a2.6 2.6 0 0 1 5 0V3z"
              fill="#fff" stroke={theme.ink} strokeWidth="1.6" strokeLinejoin="round"/>
          </svg>
        </div>
      )}
    </div>
  );
}

// Plaque above the board — Monument-Valley style 2–4 words.
function Plaque({ theme, children, tone = 'ink' }) {
  const bg = tone === 'danger' ? theme.danger : tone === 'hint' ? '#FFB020' : theme.surface;
  const fg = tone === 'ink' ? theme.ink : '#fff';
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 8,
      padding: '11px 20px', borderRadius: 999,
      background: bg, color: fg,
      border: tone === 'ink' ? `1px solid ${theme.button.glassBorder}` : 'none',
      boxShadow: tone === 'ink'
        ? 'inset 0 1px 0 rgba(255,255,255,0.8), 0 6px 16px rgba(0,0,0,0.08)'
        : '0 8px 20px rgba(0,0,0,0.14)',
      fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 19, letterSpacing: -0.2,
    }}>{children}</div>
  );
}

function SkipBtn({ theme }) {
  return (
    <div style={{
      position: 'absolute', top: 58, right: 16, zIndex: 30,
      fontFamily: theme.fontUI, fontSize: 13, fontWeight: 600,
      color: theme.inkMuted, opacity: 0.6,
      padding: '6px 12px', borderRadius: 999,
      background: theme.button.glass, border: `1px solid ${theme.button.glassBorder}`,
    }}>Пропустить</div>
  );
}

// Shell for a tutorial level screen
function TutStage({ theme, plaque, plaqueTone, sub, children, hud, skip = true }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      paddingTop: 96, paddingBottom: 28,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      {skip && <SkipBtn theme={theme}/>}
      <div style={{ textAlign: 'center', minHeight: 78 }}>
        <Plaque theme={theme} tone={plaqueTone}>{plaque}</Plaque>
        {sub && <div style={{
          marginTop: 12, fontFamily: theme.fontUI, fontSize: 13.5, color: theme.inkSoft,
          maxWidth: 250, marginInline: 'auto', lineHeight: 1.4,
        }}>{sub}</div>}
      </div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        {children}
      </div>
      {hud}
    </div>
  );
}

// ─── COLD START · Splash ──────────────────────────────────────
function OB_ColdStart({ theme }) { return <SplashScreen theme={theme}/>; }

// ─── ATT system prompt over board L1 ──────────────────────────
function OB_ATT({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', background: theme.appBg, overflow: 'hidden' }}>
      <div style={{ position: 'absolute', inset: 0, top: 96, display: 'flex', justifyContent: 'center', opacity: 0.5, filter: 'blur(0.5px)' }}>
        <TutorialBoard theme={theme} layout="L1" size={300} hand={false}/>
      </div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(10,10,20,0.28)' }}/>
      {/* native ATT alert */}
      <div style={{
        position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)',
        width: 270, borderRadius: 14, overflow: 'hidden',
        background: 'rgba(248,248,248,0.94)', backdropFilter: 'blur(20px)',
        boxShadow: '0 20px 60px rgba(0,0,0,0.3)', textAlign: 'center',
        fontFamily: '-apple-system, system-ui',
      }}>
        <div style={{ padding: '20px 18px 16px' }}>
          <div style={{ fontSize: 16, fontWeight: 700, color: '#000', lineHeight: 1.3 }}>
            «Maze&nbsp;Arrows» запрашивает разрешение отслеживать вас в приложениях&nbsp;и на&nbsp;сайтах
          </div>
          <div style={{ fontSize: 13, color: '#333', marginTop: 8, lineHeight: 1.4 }}>
            Разрешите доступ, чтобы реклама была релевантнее.
          </div>
        </div>
        <div style={{ borderTop: '0.5px solid rgba(0,0,0,0.18)', display: 'flex', flexDirection: 'column' }}>
          <div style={{ padding: '11px 0', fontSize: 16, color: '#007AFF', borderBottom: '0.5px solid rgba(0,0,0,0.18)' }}>Попросить не отслеживать</div>
          <div style={{ padding: '11px 0', fontSize: 16, fontWeight: 600, color: '#007AFF' }}>Разрешить</div>
        </div>
      </div>
      <div style={{
        position: 'absolute', bottom: 26, left: 0, right: 0, textAlign: 'center',
        fontFamily: theme.fontUI, fontSize: 11.5, color: theme.inkMuted,
      }}>Системный промпт · 5–10-я секунда · без пре-экрана</div>
    </div>
  );
}

// ─── LEVEL 1 · Тапни по стрелке ───────────────────────────────
function OB_Level1({ theme }) {
  return (
    <TutStage theme={theme} plaque="Тапни по стрелке">
      <TutorialBoard theme={theme} layout="L1" size={300}
        spotlight={{ x: 16.7, y: 25 }} highlightId="A" highlightState="free"/>
    </TutStage>
  );
}

// ─── LEVEL 1 · Slow-mo fly-out (WOW) ──────────────────────────
function OB_Level1Fly({ theme }) {
  return (
    <TutStage theme={theme} plaque="Отлично!" plaqueTone="success" skip={false}
      sub="Первый вылет — в slow-mo. Направление стрелки = направление вылета."
      hud={<div style={{
        fontFamily: theme.fontUI, fontSize: 11.5, color: theme.inkMuted, letterSpacing: 0.4,
      }}>runFlyOut ×0.5 · light haptic · трейл частиц</div>}>
      <TutorialBoard theme={theme} layout="L1" size={300} hand={false} ghostTrail="A"/>
    </TutStage>
  );
}

// ─── LEVEL 2 · Путь занят ─────────────────────────────────────
function OB_Level2({ theme }) {
  return (
    <TutStage theme={theme} plaque="Путь занят" plaqueTone="danger"
      sub="Тап в занятый путь = красная вспышка. Жизнь не теряется.">
      <TutorialBoard theme={theme} layout="L2" size={300}
        spotlight={{ x: 18, y: 58.3 }} highlightId="X" highlightState="blocked" hand={false}/>
    </TutStage>
  );
}

function OB_Level2b({ theme }) {
  return (
    <TutStage theme={theme} plaque="Сначала освободи путь"
      sub="Фигура B перекрывает выход X. Убери её — и путь откроется.">
      <TutorialBoard theme={theme} layout="L2" size={300}
        spotlight={{ x: 75, y: 50 }} highlightId="B" highlightState="free"/>
    </TutStage>
  );
}

// ─── LEVEL 3 · Порядок решает + демо хинта ────────────────────
function OB_Level3Hint({ theme }) {
  return (
    <TutStage theme={theme} plaque="Подсказка покажет ход" plaqueTone="hint"
      sub="Форс-хинт ведёт на C — открывашку цепочки. Демо бесплатно."
      hud={
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8, padding: '9px 16px',
          borderRadius: 999, background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.8), 0 4px 12px rgba(0,0,0,0.06)',
        }}>
          <IconHint color="#FFB020"/>
          <span style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 15, color: theme.ink }}>Подсказки: 3</span>
        </div>
      }>
      <TutorialBoard theme={theme} layout="L3" size={300}
        spotlight={{ x: 25, y: 50 }} highlightId="C" highlightState="hint"/>
    </TutStage>
  );
}

// ─── LEVEL 3 · Combo «Серия!» + victory ───────────────────────
function OB_Level3Combo({ theme }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      display: 'flex', flexDirection: 'column', alignItems: 'center',
      paddingTop: 96, paddingBottom: 28,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      {/* confetti */}
      <svg style={{ position: 'absolute', inset: 0 }} viewBox="0 0 360 780" preserveAspectRatio="xMidYMid slice">
        {Array.from({ length: 22 }).map((_, i) => {
          const x = (i * 53) % 360, y = 120 + ((i * 71) % 360), rot = (i * 47) % 360;
          const cols = [theme.accent, theme.accent2, theme.heartFill, '#FFB020'];
          return <rect key={i} x={x} y={y} width="6" height="14" rx="1" fill={cols[i % 4]}
            transform={`rotate(${rot} ${x} ${y})`} opacity="0.8"/>;
        })}
      </svg>
      <div style={{ textAlign: 'center', position: 'relative' }}>
        <div style={{
          display: 'inline-block', padding: '8px 22px', borderRadius: 999,
          background: `linear-gradient(180deg, ${theme.accent}, ${theme.accent2})`,
          color: '#fff', fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 26,
          letterSpacing: -0.3, boxShadow: `0 10px 26px ${theme.accent}55`,
        }}>Серия! ×3</div>
        <div style={{ marginTop: 12, fontFamily: theme.fontUI, fontSize: 13.5, color: theme.inkSoft }}>
          Три верных тапа подряд — C → D → E
        </div>
      </div>
      <div style={{ flex: 1, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ filter: `drop-shadow(0 0 20px ${theme.accent}55)` }}>
          <TutorialBoard theme={theme} layout="L3" size={280} hand={false}/>
        </div>
      </div>
      <div style={{ fontFamily: theme.fontUI, fontSize: 11.5, color: theme.inkMuted }}>
        victoryBurst → пейволл приземляется немедленно
      </div>
    </div>
  );
}

// ─── LEVEL 4 · авто-старт с жизнями + тултип ──────────────────
function OB_Level4({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative' }}>
      <GameScreen theme={theme} layout="level5" level={4} hearts={3} totalHearts={3}/>
      {/* tooltip pointing at hearts banner */}
      <div style={{
        position: 'absolute', top: 128, left: '50%', transform: 'translateX(-50%)',
        width: 250, padding: '12px 16px', borderRadius: 16,
        background: theme.ink, color: '#fff', textAlign: 'center',
        fontFamily: theme.fontUI, fontSize: 13, lineHeight: 1.4, fontWeight: 500,
        boxShadow: '0 12px 28px rgba(0,0,0,0.25)',
      }}>
        3 жизни. Тап в закрытый путь = <b>−1 жизнь</b>
        <div style={{
          position: 'absolute', top: -7, left: '50%', transform: 'translateX(-50%) rotate(45deg)',
          width: 14, height: 14, background: theme.ink, borderRadius: 2,
        }}/>
      </div>
    </div>
  );
}

Object.assign(window, {
  TutorialBoard, Plaque, TutStage, TUT_LAYOUTS,
  OB_ColdStart, OB_ATT, OB_Level1, OB_Level1Fly, OB_Level2, OB_Level2b,
  OB_Level3Hint, OB_Level3Combo, OB_Level4,
});
