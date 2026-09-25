// screens-meta.jsx — Splash, Main Menu, Level Select, Settings, Themes

// ─── 1. SPLASH ────────────────────────────────────────────────
function SplashScreen({ theme }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center',
      paddingBottom: 80,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.08}/>}
      {/* Hero spiral piece — large, faded ink */}
      <div style={{
        position: 'absolute', top: '22%', left: '50%', transform: 'translate(-50%, 0)',
        opacity: 0.95,
      }}>
        <MazePiece
          paths={PIECES.spiral.paths}
          width={260} height={260}
          stroke={theme.pieceStroke}
          strokeWidth={5}
          glow={theme.pieceGlow}
        />
      </div>

      {/* Title block at bottom */}
      <div style={{ marginTop: 'auto', textAlign: 'center', padding: '0 28px' }}>
        <div style={{
          fontFamily: theme.fontDisplay, fontWeight: 800,
          fontSize: 44, lineHeight: 0.95, color: theme.ink,
          letterSpacing: -1.5,
          textWrap: 'balance',
        }}>
          MAZE<br/>ARROWS
        </div>
        <div style={{
          marginTop: 16,
          fontFamily: theme.fontUI, fontSize: 15, color: theme.inkMuted,
          fontWeight: 500, letterSpacing: 0.2,
        }}>A puzzle of paths.</div>

        {/* Loading bar */}
        <div style={{
          marginTop: 56, width: 200, height: 4, borderRadius: 4,
          background: 'rgba(0,0,0,0.08)', overflow: 'hidden', marginInline: 'auto',
          position: 'relative',
        }}>
          <div style={{
            position: 'absolute', left: 0, top: 0, bottom: 0, width: '62%',
            background: theme.accent, borderRadius: 4,
            boxShadow: theme.pieceGlow ? `0 0 8px ${theme.accent}` : 'none',
          }}/>
        </div>
        <div style={{
          marginTop: 14, fontFamily: theme.fontUI, fontSize: 11,
          color: theme.inkMuted, letterSpacing: 1.5, textTransform: 'uppercase',
        }}>Loading paths · v1.2</div>
      </div>
    </div>
  );
}

// ─── 2. MAIN MENU ─────────────────────────────────────────────
function MainMenuScreen({ theme }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      display: 'flex', flexDirection: 'column',
      paddingTop: 60,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.06}/>}

      {/* Top profile row */}
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10,
          background: theme.surface, padding: '6px 14px 6px 6px', borderRadius: 999,
          border: `1px solid ${theme.button.glassBorder}`,
        }}>
          <div style={{
            width: 32, height: 32, borderRadius: 999,
            background: `linear-gradient(135deg, ${theme.accent}, ${theme.accent2})`,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 14,
          }}>K</div>
          <div style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.1 }}>
            <span style={{ fontFamily: theme.fontUI, fontSize: 13, fontWeight: 700, color: theme.ink }}>Kai</span>
            <span style={{ fontFamily: theme.fontUI, fontSize: 10, color: theme.inkMuted, textTransform: 'uppercase', letterSpacing: 0.8 }}>7-day streak</span>
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <div style={{
            display: 'flex', alignItems: 'center', gap: 6,
            background: theme.surface, padding: '6px 12px', borderRadius: 999,
            border: `1px solid ${theme.button.glassBorder}`,
            fontFamily: theme.fontUI, fontSize: 13, fontWeight: 700, color: theme.ink,
          }}>
            <IconCoin/> 1,240
          </div>
          <CircleButton theme={theme} size={36}>
            <IconSettings color={theme.inkSoft} size={16}/>
          </CircleButton>
        </div>
      </div>

      {/* Hero */}
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '0 28px' }}>
        <div style={{ position: 'relative' }}>
          <MazePiece
            paths={PIECES.spiral.paths}
            width={180} height={180}
            stroke={theme.pieceStroke}
            strokeWidth={6}
            glow={theme.pieceGlow}
          />
        </div>
        <div style={{
          marginTop: 18,
          fontFamily: theme.fontDisplay, fontWeight: 800,
          fontSize: 46, lineHeight: 0.9, color: theme.ink,
          letterSpacing: -1.6, textAlign: 'center',
        }}>MAZE<br/>ARROWS</div>
        <div style={{ marginTop: 10, fontFamily: theme.fontUI, fontSize: 14, color: theme.inkMuted }}>
          Chapter 2 · Open Paths
        </div>

        {/* Progress strip */}
        <div style={{ width: '100%', marginTop: 22 }}>
          <div style={{
            height: 6, borderRadius: 3, background: 'rgba(0,0,0,0.06)', overflow: 'hidden',
          }}>
            <div style={{
              height: '100%', width: '42%',
              background: `linear-gradient(90deg, ${theme.accent}, ${theme.accent2})`,
              borderRadius: 3,
            }}/>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 6,
            fontFamily: theme.fontUI, fontSize: 11, color: theme.inkMuted, letterSpacing: 0.4, textTransform: 'uppercase',
          }}>
            <span>Level 21 next</span><span>42 / 100</span>
          </div>
        </div>
      </div>

      {/* CTA stack */}
      <div style={{ padding: '0 24px 36px', display: 'flex', flexDirection: 'column', gap: 12 }}>
        <PrimaryButton theme={theme} full>
          <span style={{ display: 'inline-flex', alignItems: 'center', gap: 10 }}>
            <IconPlay color={theme.button.primaryText} size={20}/>
            Play · Level 21
          </span>
        </PrimaryButton>
        <div style={{ display: 'flex', gap: 10 }}>
          <GhostButton theme={theme} full>Levels</GhostButton>
          <GhostButton theme={theme} full>Daily</GhostButton>
        </div>
      </div>
    </div>
  );
}

// ─── 3. LEVEL SELECT ──────────────────────────────────────────
function LevelSelectScreen({ theme }) {
  // 6 cols x 5 rows of level chips, with stars
  const levels = Array.from({ length: 24 }, (_, i) => {
    const n = i + 13;
    const completed = n <= 20;
    const stars = completed ? (n % 3 === 0 ? 2 : 3) : 0;
    const locked = n > 21;
    return { n, completed, stars, locked, current: n === 21 };
  });
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden',
      paddingTop: 60,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}

      {/* Top bar */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          <div style={{ fontFamily: theme.fontUI, fontSize: 10, letterSpacing: 1.3,
            color: theme.inkMuted, textTransform: 'uppercase', fontWeight: 700 }}>Chapter 2</div>
          <div style={{ fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800, color: theme.ink, lineHeight: 1 }}>Open Paths</div>
        </div>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 4,
          padding: '6px 12px', borderRadius: 999,
          background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
          fontFamily: theme.fontUI, fontSize: 13, fontWeight: 700, color: theme.ink,
        }}>
          <IconStar color="#FFB020" size={14}/> 58
        </div>
      </div>

      {/* Chapter card */}
      <div style={{ margin: '8px 20px 16px', padding: 16, borderRadius: 22,
        background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
        display: 'flex', gap: 14, alignItems: 'center',
      }}>
        <div style={{
          width: 62, height: 62, borderRadius: 18,
          background: `linear-gradient(135deg, ${theme.accent}, ${theme.accent2})`,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3)',
        }}>
          <MazePiece paths={PIECES.uTurn.paths} width={42} height={42}
            stroke="#fff" strokeWidth={8} emboss={false}/>
        </div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: theme.fontDisplay, fontSize: 16, fontWeight: 800, color: theme.ink }}>20 of 50 cleared</div>
          <div style={{ fontFamily: theme.fontUI, fontSize: 12, color: theme.inkMuted, marginTop: 2 }}>Clear 5 more to unlock Chapter 3</div>
          <div style={{ marginTop: 8, height: 5, borderRadius: 3, background: 'rgba(0,0,0,0.06)', overflow: 'hidden' }}>
            <div style={{ height: '100%', width: '40%', background: theme.accent, borderRadius: 3 }}/>
          </div>
        </div>
      </div>

      {/* Grid */}
      <div style={{ padding: '0 20px',
        display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10,
      }}>
        {levels.map(l => (
          <div key={l.n} style={{
            aspectRatio: '1', borderRadius: 18, position: 'relative',
            background: l.current
              ? `linear-gradient(180deg, ${theme.accent}, ${theme.accent2 ?? theme.accent})`
              : l.locked ? 'rgba(0,0,0,0.04)' : theme.surface,
            border: l.current ? 'none' : `1px solid ${theme.button.glassBorder}`,
            display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: 4,
            boxShadow: l.current
              ? `0 6px 16px ${theme.accent}55`
              : l.locked ? 'none' : 'inset 0 1px 0 rgba(255,255,255,0.8), 0 2px 6px rgba(0,0,0,0.04)',
          }}>
            {l.locked ? (
              <IconLock color={theme.inkMuted}/>
            ) : (
              <>
                <div style={{
                  fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800,
                  color: l.current ? '#fff' : theme.ink, lineHeight: 1,
                }}>{l.n}</div>
                <div style={{ display: 'flex', gap: 1 }}>
                  {[0,1,2].map(i => (
                    <IconStar key={i} size={9}
                      color={l.current ? '#fff' : i < l.stars ? '#FFB020' : 'rgba(0,0,0,0.12)'}
                      filled={i < l.stars || l.current}/>
                  ))}
                </div>
              </>
            )}
            {l.current && (
              <div style={{
                position: 'absolute', top: -4, right: -4,
                background: '#fff', color: theme.accent,
                fontFamily: theme.fontUI, fontSize: 9, fontWeight: 800,
                padding: '2px 6px', borderRadius: 999, letterSpacing: 0.5, textTransform: 'uppercase',
                boxShadow: '0 2px 4px rgba(0,0,0,0.1)',
              }}>NOW</div>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── 7. SETTINGS ──────────────────────────────────────────────
function SettingsScreen({ theme }) {
  const Row = ({ label, value, toggle, last }) => (
    <div style={{
      display: 'flex', alignItems: 'center', padding: '14px 16px',
      borderBottom: last ? 'none' : `1px solid ${theme.button.glassBorder}`,
    }}>
      <div style={{ flex: 1, fontFamily: theme.fontUI, fontSize: 15, color: theme.ink, fontWeight: 500 }}>{label}</div>
      {toggle !== undefined ? (
        <div style={{
          width: 44, height: 26, borderRadius: 999,
          background: toggle ? theme.success : 'rgba(120,120,140,0.25)',
          padding: 2, boxSizing: 'border-box',
          display: 'flex', alignItems: 'center', justifyContent: toggle ? 'flex-end' : 'flex-start',
        }}>
          <div style={{ width: 22, height: 22, borderRadius: 999, background: '#fff',
            boxShadow: '0 1px 3px rgba(0,0,0,0.25)' }}/>
        </div>
      ) : value && (
        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
          <span style={{ fontFamily: theme.fontUI, fontSize: 14, color: theme.inkMuted }}>{value}</span>
          <svg width="6" height="10" viewBox="0 0 6 10"><path d="M1 1l4 4-4 4" stroke={theme.inkMuted} strokeWidth="1.5" fill="none" strokeLinecap="round"/></svg>
        </div>
      )}
    </div>
  );
  const Group = ({ title, children }) => (
    <div style={{ marginBottom: 18 }}>
      <div style={{
        padding: '0 20px 6px', fontFamily: theme.fontUI, fontSize: 11,
        letterSpacing: 1, textTransform: 'uppercase', color: theme.inkMuted, fontWeight: 700,
      }}>{title}</div>
      <div style={{
        margin: '0 16px', borderRadius: 18, background: theme.surface,
        border: `1px solid ${theme.button.glassBorder}`, overflow: 'hidden',
      }}>{children}</div>
    </div>
  );
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'auto', paddingTop: 60, paddingBottom: 40,
    }}>
      {/* Header */}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px 20px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 24, fontWeight: 800, color: theme.ink }}>Settings</div>
        <div style={{ width: 40 }}/>
      </div>

      <Group title="Audio & Haptics">
        <Row label="Sound effects" toggle={true}/>
        <Row label="Music" toggle={true}/>
        <Row label="Haptic feedback" toggle={true}/>
        <Row label="Haptic intensity" value="Medium" last/>
      </Group>
      <Group title="Gameplay">
        <Row label="Auto-hint after 30s" toggle={false}/>
        <Row label="Show piece outlines" toggle={true}/>
        <Row label="Confirm restart" toggle={false} last/>
      </Group>
      <Group title="Theme & Locale">
        <Row label="Theme" value="Aurora Light"/>
        <Row label="Match my region" toggle={true}/>
        <Row label="Language" value="English" last/>
      </Group>
      <Group title="Account">
        <Row label="Sign in with Apple"/>
        <Row label="Restore purchases"/>
        <Row label="About & credits" last/>
      </Group>
    </div>
  );
}

// ─── 8. THEME / CUSTOMIZATION ─────────────────────────────────
function ThemeScreen({ theme, themes }) {
  const list = Object.entries(themes);
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'auto', paddingTop: 60, paddingBottom: 40,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px 14px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 24, fontWeight: 800, color: theme.ink }}>Theme</div>
        <div style={{ width: 40 }}/>
      </div>

      {/* Locale match toggle banner */}
      <div style={{
        margin: '0 16px 16px', padding: '14px 16px', borderRadius: 18,
        background: `linear-gradient(135deg, ${theme.accent}22, ${theme.accent2 ?? theme.accent}22)`,
        border: `1px solid ${theme.button.glassBorder}`,
        display: 'flex', alignItems: 'center', gap: 12,
      }}>
        <div style={{
          width: 38, height: 38, borderRadius: 12, flexShrink: 0,
          background: theme.accent, color: '#fff',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 13,
        }}>JP</div>
        <div style={{ flex: 1 }}>
          <div style={{ fontFamily: theme.fontUI, fontSize: 14, fontWeight: 700, color: theme.ink }}>Match my locale</div>
          <div style={{ fontFamily: theme.fontUI, fontSize: 12, color: theme.inkMuted, marginTop: 2 }}>Suggests Sakura theme for Japan</div>
        </div>
        <div style={{
          width: 44, height: 26, borderRadius: 999,
          background: theme.success, padding: 2, boxSizing: 'border-box',
          display: 'flex', justifyContent: 'flex-end',
        }}>
          <div style={{ width: 22, height: 22, borderRadius: 999, background: '#fff', boxShadow: '0 1px 3px rgba(0,0,0,0.25)' }}/>
        </div>
      </div>

      {/* Grid of themes */}
      <div style={{ padding: '0 16px',
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12,
      }}>
        {list.map(([key, t]) => {
          const selected = key === 'aurora';
          const premium = ['sakura','atlas','nordic'].includes(key);
          return (
            <div key={key} style={{
              borderRadius: 20, overflow: 'hidden', position: 'relative',
              background: t.appBg,
              border: selected ? `2px solid ${theme.accent}` : `1px solid ${theme.button.glassBorder}`,
              boxShadow: selected ? `0 8px 20px ${theme.accent}30` : '0 4px 10px rgba(0,0,0,0.06)',
            }}>
              <div style={{ padding: 12, height: 110, position: 'relative', overflow: 'hidden' }}>
                {t.motif && <ThemeMotif kind={t.motif} color={t.inkMuted} opacity={t.pieceGlow ? 1 : 0.08}/>}
                <div style={{ position: 'absolute', inset: 0, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  <MazePiece paths={PIECES.snake.paths} width={120} height={80}
                    stroke={t.pieceStroke} strokeWidth={6} glow={t.pieceGlow}/>
                </div>
              </div>
              <div style={{
                padding: '10px 12px',
                background: t.pieceGlow ? 'rgba(0,0,0,0.4)' : 'rgba(255,255,255,0.7)',
                backdropFilter: 'blur(8px)',
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              }}>
                <div>
                  <div style={{ fontFamily: t.fontDisplay, fontSize: 14, fontWeight: 800, color: t.ink }}>{t.name}</div>
                  {t.locale && (
                    <div style={{ fontFamily: t.fontUI, fontSize: 10, color: t.inkMuted, letterSpacing: 0.6, textTransform: 'uppercase', marginTop: 1 }}>Locale · {t.locale}</div>
                  )}
                </div>
                {selected ? (
                  <div style={{ width: 22, height: 22, borderRadius: 999, background: theme.accent,
                    display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                    <svg width="12" height="12" viewBox="0 0 12 12"><path d="M2 6l3 3 5-6" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
                  </div>
                ) : premium ? (
                  <div style={{ fontFamily: theme.fontUI, fontSize: 9, fontWeight: 800, color: theme.accent, letterSpacing: 0.6, textTransform: 'uppercase' }}>Pass</div>
                ) : null}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}

Object.assign(window, { SplashScreen, MainMenuScreen, LevelSelectScreen, SettingsScreen, ThemeScreen });
