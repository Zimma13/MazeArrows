// screens-game.jsx — Game screen, Win screen, Fail screen

// ─── 4. GAME SCREEN ───────────────────────────────────────────
function GameScreen({ theme, layout = 'level20', level = 20, hearts = 4, totalHearts = 4, pieceOverride }) {
  // Apply overrides for piece states (free/blocked/hint demo)
  const layoutDef = LAYOUTS[layout] ?? LAYOUTS.level20;
  const pieces = pieceOverride
    ? layoutDef.map((p, i) => pieceOverride(p, i) ?? p)
    : layoutDef;

  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      paddingTop: 60,
      display: 'flex', flexDirection: 'column',
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <GameTopBar theme={theme} level={level} onClose/>
      <HeartsBanner theme={theme} filled={hearts} total={totalHearts}/>

      {/* Puzzle board */}
      <div style={{ flex: 1, padding: '0 18px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <PuzzleBoard
          theme={theme}
          pieces={pieces}
          width={366} height={500}
          pieceStrokeWidth={5.5}
        />
      </div>

      {/* Action bar */}
      <div style={{
        display: 'flex', justifyContent: 'space-evenly', alignItems: 'flex-end',
        padding: '16px 24px 36px',
      }}>
        <ActionPill theme={theme} label="Hint" badge="3"
          icon={<IconHint color={theme.ink}/>}/>
        <ActionPill theme={theme} label="Undo" badge="5"
          icon={<IconUndo color={theme.ink}/>}/>
        <ActionPill theme={theme} label="Shuffle" badge="1"
          icon={<svg width="18" height="18" viewBox="0 0 18 18" fill="none">
            <path d="M2 5l3-2 3 2M5 3v8" stroke={theme.ink} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M16 13l-3 2-3-2M13 15V7" stroke={theme.ink} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
            <path d="M2 14h3a5 5 0 0 0 5-5M16 4h-3a5 5 0 0 0-5 5" stroke={theme.ink} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>}/>
        <ActionPill theme={theme} label="Restart"
          icon={<IconRefresh color={theme.ink}/>}/>
      </div>
    </div>
  );
}

// ─── 5. WIN SCREEN ────────────────────────────────────────────
function WinScreen({ theme, level = 20 }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      paddingTop: 60,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}

      {/* Behind: dim ghost of cleared board */}
      <div style={{ position: 'absolute', inset: 0, top: 60, padding: 30, display: 'flex',
        justifyContent: 'center', alignItems: 'flex-start', opacity: 0.18, filter: 'blur(2px)' }}>
        <PuzzleBoard theme={theme} pieces={LAYOUTS.preview} width={330} height={420} showMotif={false}/>
      </div>

      {/* Confetti specks */}
      <svg style={{ position: 'absolute', inset: 0 }} viewBox="0 0 400 800" preserveAspectRatio="xMidYMid slice">
        {Array.from({ length: 24 }).map((_, i) => {
          const x = (i * 53) % 400;
          const y = 100 + ((i * 31) % 400);
          const rot = (i * 47) % 360;
          const colors = [theme.accent, theme.accent2 ?? theme.accent, theme.heartFill, '#FFB020'];
          return (
            <rect key={i} x={x} y={y} width="6" height="14" rx="1"
              fill={colors[i % colors.length]}
              transform={`rotate(${rot} ${x+3} ${y+7})`} opacity="0.85"/>
          );
        })}
      </svg>

      <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column',
        alignItems: 'center', padding: '30px 28px 36px' }}>

        <div style={{
          fontFamily: theme.fontUI, fontSize: 12, fontWeight: 700, letterSpacing: 1.5,
          color: theme.inkMuted, textTransform: 'uppercase',
        }}>Level {level}</div>
        <div style={{
          marginTop: 6,
          fontFamily: theme.fontDisplay, fontSize: 56, fontWeight: 800,
          color: theme.ink, letterSpacing: -1.5, lineHeight: 1,
        }}>Cleared!</div>

        {/* Stars row */}
        <div style={{ display: 'flex', gap: 12, marginTop: 26, alignItems: 'flex-end' }}>
          {[18, 0, 18].map((dip, i) => (
            <div key={i} style={{ marginTop: dip }}>
              <div style={{
                width: i === 1 ? 76 : 60, height: i === 1 ? 76 : 60,
                borderRadius: '50%',
                background: `radial-gradient(circle at 35% 30%, #FFE08A, #FFB020 60%, #E08C00 100%)`,
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                boxShadow: `0 8px 20px #E08C0055, inset 0 2px 0 rgba(255,255,255,0.45)`,
              }}>
                <IconStar color="#fff" size={i === 1 ? 38 : 30}/>
              </div>
            </div>
          ))}
        </div>

        {/* Stats card */}
        <div style={{
          marginTop: 30, width: '100%', padding: 18, borderRadius: 22,
          background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
          display: 'flex', justifyContent: 'space-around',
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7), 0 8px 20px rgba(0,0,0,0.05)',
        }}>
          {[
            { label: 'Time', value: '1:24' },
            { label: 'Moves', value: '11' },
            { label: 'Hints', value: '0' },
          ].map((s, i, arr) => (
            <React.Fragment key={s.label}>
              <div style={{ textAlign: 'center', flex: 1 }}>
                <div style={{
                  fontFamily: theme.fontDisplay, fontSize: 24, fontWeight: 800,
                  color: theme.ink, lineHeight: 1,
                }}>{s.value}</div>
                <div style={{
                  marginTop: 4, fontFamily: theme.fontUI, fontSize: 10, fontWeight: 700,
                  letterSpacing: 1, color: theme.inkMuted, textTransform: 'uppercase',
                }}>{s.label}</div>
              </div>
              {i < arr.length - 1 && <div style={{ width: 1, background: theme.button.glassBorder }}/>}
            </React.Fragment>
          ))}
        </div>

        {/* Coin reward */}
        <div style={{
          marginTop: 14, display: 'flex', alignItems: 'center', gap: 8,
          padding: '8px 16px', borderRadius: 999,
          background: 'linear-gradient(180deg, #FFF6E0, #FFE5A0)',
          border: '1px solid rgba(208,140,0,0.25)',
          fontFamily: theme.fontDisplay, fontSize: 16, fontWeight: 800, color: '#7A5410',
        }}>
          <IconCoin/> +120
        </div>

        <div style={{ flex: 1 }}/>

        <PrimaryButton theme={theme} full>Next level</PrimaryButton>
        <div style={{ marginTop: 10, display: 'flex', gap: 10, width: '100%' }}>
          <GhostButton theme={theme} full>Replay</GhostButton>
          <GhostButton theme={theme} full>Share</GhostButton>
        </div>
      </div>
    </div>
  );
}

// ─── 6. FAIL SCREEN ───────────────────────────────────────────
function FailScreen({ theme, level = 15 }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      paddingTop: 60,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}

      {/* Behind: blocked board (red highlights) */}
      <div style={{ position: 'absolute', inset: 0, top: 60, padding: 30, display: 'flex',
        justifyContent: 'center', alignItems: 'flex-start', opacity: 0.22, filter: 'blur(1.5px)' }}>
        <PuzzleBoard theme={theme} pieces={LAYOUTS.preview.map((p,i)=>({...p, state: i<2 ? 'blocked' : 'normal'}))}
          width={330} height={420} showMotif={false}/>
      </div>

      <div style={{ position: 'relative', height: '100%', display: 'flex', flexDirection: 'column',
        alignItems: 'center', padding: '40px 28px 36px' }}>

        <div style={{
          fontFamily: theme.fontUI, fontSize: 12, fontWeight: 700, letterSpacing: 1.5,
          color: theme.inkMuted, textTransform: 'uppercase',
        }}>Level {level}</div>
        <div style={{
          marginTop: 6,
          fontFamily: theme.fontDisplay, fontSize: 48, fontWeight: 800,
          color: theme.ink, letterSpacing: -1.5, lineHeight: 1, textAlign: 'center',
        }}>Out of<br/>moves</div>

        {/* Broken-heart visual */}
        <div style={{ marginTop: 28, position: 'relative' }}>
          <div style={{
            width: 110, height: 110, borderRadius: '50%',
            background: `radial-gradient(circle at 35% 30%, ${theme.danger}cc, ${theme.danger} 70%)`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: `0 10px 24px ${theme.danger}55, inset 0 2px 0 rgba(255,255,255,0.3)`,
          }}>
            <svg width="56" height="52" viewBox="0 0 24 22">
              <path d="M12 21s-9-5.5-9-12a5 5 0 0 1 9-3 5 5 0 0 1 9 3c0 6.5-9 12-9 12z"
                fill="#fff"/>
              <path d="M12 5l-2 6 3 1-1 5 4-7-3-1 1-4z" fill={theme.danger}/>
            </svg>
          </div>
        </div>

        {/* Stat */}
        <div style={{
          marginTop: 26, padding: '14px 22px', borderRadius: 18,
          background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
          fontFamily: theme.fontUI, fontSize: 14, color: theme.inkSoft, textAlign: 'center',
        }}>
          You cleared <b style={{ color: theme.ink }}>8 of 11</b> pieces ·
          <span style={{ marginLeft: 6, color: theme.inkMuted }}>3 paths blocked</span>
        </div>

        <div style={{ flex: 1 }}/>

        {/* Retry options */}
        <div style={{
          width: '100%', padding: 14, borderRadius: 22,
          background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
          display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 14,
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7), 0 6px 20px rgba(0,0,0,0.05)',
        }}>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 4px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <Heart filled color={theme.heartFill} size={22}/>
              <span style={{ fontFamily: theme.fontUI, fontSize: 14, fontWeight: 600, color: theme.ink }}>Continue · 1 heart</span>
            </div>
            <div style={{ fontFamily: theme.fontDisplay, fontSize: 13, fontWeight: 800, color: theme.accent,
              display: 'flex', alignItems: 'center', gap: 4 }}>
              <IconCoin size={14}/> 50
            </div>
          </div>
          <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '8px 4px',
          }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
              <div style={{ width: 22, height: 22, borderRadius: 6,
                background: theme.accent2 ?? theme.accent, display: 'flex',
                alignItems: 'center', justifyContent: 'center', color: '#fff', fontSize: 10, fontWeight: 800,
                fontFamily: theme.fontUI }}>▶</div>
              <span style={{ fontFamily: theme.fontUI, fontSize: 14, fontWeight: 600, color: theme.ink }}>Watch ad · free retry</span>
            </div>
            <span style={{ fontFamily: theme.fontUI, fontSize: 11, fontWeight: 700, color: theme.success,
              textTransform: 'uppercase', letterSpacing: 0.6 }}>Free</span>
          </div>
        </div>

        <PrimaryButton theme={theme} full>Retry</PrimaryButton>
        <div style={{ marginTop: 10, width: '100%' }}>
          <GhostButton theme={theme} full>Back to levels</GhostButton>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { GameScreen, WinScreen, FailScreen });
