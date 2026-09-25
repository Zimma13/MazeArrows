// screens-meta2.jsx — Additional screens: Daily Maze, Game Modes, World Map,
// Achievements/Quests, plus Game-screen overlay variants (Objective, Combo,
// Preview-path).

// ─── DAILY MAZE ───────────────────────────────────────────────
function DailyMazeScreen({ theme }) {
  const today = 14;
  const month = 'May';
  // build a 4×7 grid simulating current month, last 28 days
  const days = Array.from({ length: 28 }, (_, i) => i + 1);
  const completed = new Set([1,2,3,5,6,7,8,9,10,11,12]);
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'auto', paddingTop: 60, paddingBottom: 40 }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800, color: theme.ink }}>Daily Maze</div>
        <div style={{ width: 40 }}/>
      </div>

      {/* Streak hero */}
      <div style={{ margin: '8px 16px 16px', padding: 18, borderRadius: 22,
        background: `linear-gradient(135deg, ${theme.accent}, ${theme.accent2 ?? theme.accent})`,
        color: '#fff', position: 'relative', overflow: 'hidden',
        boxShadow: `0 12px 30px ${theme.accent}33`,
      }}>
        <div style={{ position: 'absolute', right: -20, top: -20, opacity: 0.18 }}>
          <MazePiece paths={PIECES.spiral.paths} width={140} height={140} stroke="#fff" strokeWidth={5} emboss={false}/>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontFamily: theme.fontUI, fontSize: 11, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', opacity: 0.85 }}>
          🔥 7-day streak
        </div>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 34, fontWeight: 800, lineHeight: 1, marginTop: 6, letterSpacing: -1 }}>
          {month} {today}
        </div>
        <div style={{ fontFamily: theme.fontUI, fontSize: 13, marginTop: 4, opacity: 0.9 }}>
          Today's puzzle · golden frame
        </div>
        <div style={{ marginTop: 14 }}>
          <div style={{ display: 'inline-block', padding: '12px 22px', borderRadius: 999,
            background: 'rgba(255,255,255,0.95)', color: theme.ink,
            fontFamily: theme.fontDisplay, fontSize: 15, fontWeight: 800, letterSpacing: 0.3, textTransform: 'uppercase',
            boxShadow: '0 4px 0 rgba(0,0,0,0.18)',
          }}>▶ Play today's maze</div>
        </div>
      </div>

      {/* Reward strip */}
      <div style={{ padding: '0 16px 4px', fontFamily: theme.fontUI, fontSize: 11,
        color: theme.inkMuted, letterSpacing: 1, textTransform: 'uppercase', fontWeight: 700 }}>Streak rewards</div>
      <div style={{ padding: '6px 16px 14px', display: 'flex', gap: 8, overflow: 'auto' }}>
        {[
          { day: 3, icon: '💎', label: 'Gem', got: true },
          { day: 7, icon: '⭐', label: '+3 hints', got: true },
          { day: 14, icon: '🎨', label: 'Skin', got: false, current: true },
          { day: 21, icon: '💛', label: '5 hearts', got: false },
          { day: 30, icon: '👑', label: 'Crown skin', got: false },
        ].map(r => (
          <div key={r.day} style={{
            flexShrink: 0, width: 78, padding: 10, borderRadius: 14,
            background: r.current
              ? `linear-gradient(135deg, ${theme.accent}, ${theme.accent2 ?? theme.accent})`
              : r.got ? theme.surface : 'rgba(0,0,0,0.04)',
            border: `1px solid ${r.current ? 'transparent' : theme.button.glassBorder}`,
            textAlign: 'center', position: 'relative',
            color: r.current ? '#fff' : theme.ink,
            boxShadow: r.current ? `0 6px 14px ${theme.accent}40` : 'none',
          }}>
            <div style={{ fontSize: 22 }}>{r.icon}</div>
            <div style={{ fontFamily: theme.fontDisplay, fontSize: 12, fontWeight: 800, marginTop: 2 }}>D{r.day}</div>
            <div style={{ fontFamily: theme.fontUI, fontSize: 10, opacity: 0.85 }}>{r.label}</div>
            {r.got && !r.current && (
              <div style={{ position: 'absolute', top: -4, right: -4, width: 18, height: 18, borderRadius: 999,
                background: theme.success, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                <svg width="10" height="10" viewBox="0 0 10 10"><path d="M2 5l2 2 4-4" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round"/></svg>
              </div>
            )}
          </div>
        ))}
      </div>

      {/* Calendar */}
      <div style={{ margin: '8px 16px 16px', padding: 16, borderRadius: 22,
        background: theme.surface, border: `1px solid ${theme.button.glassBorder}` }}>
        <div style={{ fontFamily: theme.fontUI, fontSize: 11, letterSpacing: 1, textTransform: 'uppercase',
          color: theme.inkMuted, fontWeight: 700, marginBottom: 10 }}>{month} · 11 of 14 cleared</div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 6 }}>
          {days.map(d => {
            const isToday = d === today;
            const done = completed.has(d);
            const future = d > today;
            return (
              <div key={d} style={{
                aspectRatio: '1', borderRadius: 10, position: 'relative',
                background: isToday
                  ? `linear-gradient(135deg, ${theme.accent}, ${theme.accent2 ?? theme.accent})`
                  : done ? 'rgba(63,182,128,0.15)' : future ? 'rgba(0,0,0,0.03)' : 'rgba(239,68,88,0.12)',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                color: isToday ? '#fff' : done ? theme.success : future ? theme.inkMuted : theme.danger,
                fontFamily: theme.fontDisplay, fontSize: 13, fontWeight: 800,
                boxShadow: isToday ? `0 4px 10px ${theme.accent}55` : 'none',
              }}>
                {isToday ? '★' : done ? '✓' : d}
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ─── GAME MODES ───────────────────────────────────────────────
function GameModesScreen({ theme }) {
  const modes = [
    { key: 'classic',   name: 'Classic',     desc: 'Lives, levels, progression',     icon: '🎯', unlocked: true,  primary: true },
    { key: 'relax',     name: 'Relax',       desc: 'No lives, no pressure',          icon: '🌿', unlocked: true },
    { key: 'challenge', name: 'Challenge',   desc: 'Limited mistakes per level',     icon: '⚡', unlocked: true },
    { key: 'timed',     name: 'Timed',       desc: 'Beat the clock',                 icon: '⏱', unlocked: true },
    { key: 'zen',       name: 'Zen Daily',   desc: 'One slow puzzle a day',          icon: '🌸', unlocked: true },
    { key: 'hard',      name: 'Hard',        desc: 'No hints, denser boards',        icon: '🔥', unlocked: false, requires: 'Clear 30 levels' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'auto', paddingTop: 60, paddingBottom: 40 }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px 16px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800, color: theme.ink }}>Game modes</div>
        <div style={{ width: 40 }}/>
      </div>
      <div style={{ padding: '0 16px', display: 'flex', flexDirection: 'column', gap: 10 }}>
        {modes.map(m => (
          <div key={m.key} style={{
            padding: 16, borderRadius: 22, display: 'flex', alignItems: 'center', gap: 14,
            background: m.primary
              ? `linear-gradient(135deg, ${theme.accent}, ${theme.accent2 ?? theme.accent})`
              : theme.surface,
            border: m.primary ? 'none' : `1px solid ${theme.button.glassBorder}`,
            boxShadow: m.primary
              ? `0 8px 20px ${theme.accent}33`
              : 'inset 0 1px 0 rgba(255,255,255,0.7), 0 4px 10px rgba(0,0,0,0.04)',
            opacity: m.unlocked ? 1 : 0.55, position: 'relative',
          }}>
            <div style={{
              width: 54, height: 54, borderRadius: 16,
              background: m.primary ? 'rgba(255,255,255,0.2)' : theme.appBg,
              display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 28,
              border: m.primary ? '1px solid rgba(255,255,255,0.3)' : `1px solid ${theme.button.glassBorder}`,
            }}>{m.icon}</div>
            <div style={{ flex: 1, color: m.primary ? '#fff' : theme.ink }}>
              <div style={{ fontFamily: theme.fontDisplay, fontSize: 18, fontWeight: 800, lineHeight: 1.1 }}>{m.name}</div>
              <div style={{ fontFamily: theme.fontUI, fontSize: 13, marginTop: 4, opacity: m.primary ? 0.9 : 0.7 }}>{m.desc}</div>
              {!m.unlocked && (
                <div style={{
                  marginTop: 6, display: 'inline-flex', alignItems: 'center', gap: 4,
                  padding: '3px 8px', borderRadius: 999,
                  background: 'rgba(0,0,0,0.06)', fontFamily: theme.fontUI, fontSize: 10,
                  letterSpacing: 0.6, textTransform: 'uppercase', fontWeight: 700, color: theme.inkMuted,
                }}><IconLock color={theme.inkMuted} size={10}/> {m.requires}</div>
              )}
            </div>
            {m.unlocked && (
              <svg width="8" height="14" viewBox="0 0 8 14">
                <path d="M1 1l6 6-6 6" stroke={m.primary ? '#fff' : theme.inkMuted} strokeWidth="2" fill="none" strokeLinecap="round"/>
              </svg>
            )}
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── WORLD MAP / CHAPTER JOURNEY ──────────────────────────────
function WorldMapScreen({ theme }) {
  const worlds = [
    { id: 1, name: 'Open Paths',  region: 'Tutorial',  cleared: 12, total: 12, current: false, piece: 'snake',  color: theme.accent },
    { id: 2, name: 'Twin Knots',  region: 'Now',       cleared: 8,  total: 20, current: true,  piece: 'comb',   color: theme.accent2 ?? theme.accent },
    { id: 3, name: 'Frost Field', region: 'Frozen',    cleared: 0,  total: 25, current: false, piece: 'spiral', color: '#5AA8E8', locked: false },
    { id: 4, name: 'Lantern Way', region: 'Festival',  cleared: 0,  total: 25, current: false, piece: 'stairs', color: '#D4A52A', locked: true, req: 'Clear Frost Field' },
    { id: 5, name: 'Atlas Tile',  region: 'Desert',    cleared: 0,  total: 30, current: false, piece: 'coil',   color: '#C6502E', locked: true, req: 'Premium pass' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'auto', paddingTop: 60, paddingBottom: 40 }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px 12px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800, color: theme.ink }}>Maze Journey</div>
        <div style={{ width: 40 }}/>
      </div>
      <div style={{ padding: '0 20px 8px', fontFamily: theme.fontUI, fontSize: 13, color: theme.inkMuted, textAlign: 'center' }}>
        World 2 of 5 · 20 of 112 levels cleared
      </div>

      {/* Vertical chapter path */}
      <div style={{ padding: '20px 18px 28px', position: 'relative' }}>
        {/* Dotted path between cards */}
        <svg style={{ position: 'absolute', left: 0, top: 30, right: 0, bottom: 0, pointerEvents: 'none' }} viewBox="0 0 360 800" preserveAspectRatio="none">
          <path d="M 80 60 Q 280 160 80 280 Q 280 400 80 520 Q 280 640 80 760"
            stroke={theme.inkMuted} strokeWidth="2" strokeDasharray="4 6" fill="none" opacity="0.4"/>
        </svg>

        <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', gap: 24 }}>
          {worlds.map((w, i) => {
            const sideRight = i % 2 === 1;
            return (
              <div key={w.id} style={{
                display: 'flex', justifyContent: sideRight ? 'flex-end' : 'flex-start',
              }}>
                <div style={{
                  width: 240, borderRadius: 22, position: 'relative',
                  background: w.current
                    ? `linear-gradient(135deg, ${w.color}, ${theme.accent2 ?? w.color})`
                    : theme.surface,
                  border: w.current ? 'none' : `1px solid ${theme.button.glassBorder}`,
                  boxShadow: w.current ? `0 10px 24px ${w.color}45` : '0 4px 10px rgba(0,0,0,0.05)',
                  opacity: w.locked ? 0.65 : 1,
                  padding: 14,
                  color: w.current ? '#fff' : theme.ink,
                }}>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                    <div style={{
                      width: 48, height: 48, borderRadius: 12,
                      background: w.current ? 'rgba(255,255,255,0.2)' : `${w.color}22`,
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                    }}>
                      {w.locked ? (
                        <IconLock color={theme.inkMuted}/>
                      ) : (
                        <MazePiece paths={PIECES[w.piece]?.paths ?? PIECES.snake.paths}
                          width={36} height={36}
                          stroke={w.current ? '#fff' : w.color}
                          strokeWidth={6} emboss={false}/>
                      )}
                    </div>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontFamily: theme.fontUI, fontSize: 10, letterSpacing: 1, textTransform: 'uppercase',
                        fontWeight: 700, opacity: w.current ? 0.85 : 0.6 }}>World {w.id} · {w.region}</div>
                      <div style={{ fontFamily: theme.fontDisplay, fontSize: 17, fontWeight: 800, lineHeight: 1.1, marginTop: 2 }}>
                        {w.name}
                      </div>
                    </div>
                  </div>
                  {w.locked ? (
                    <div style={{ marginTop: 10, fontFamily: theme.fontUI, fontSize: 11, color: theme.inkMuted, fontWeight: 600 }}>
                      Requires: {w.req}
                    </div>
                  ) : (
                    <>
                      <div style={{ marginTop: 10, height: 6, borderRadius: 3,
                        background: w.current ? 'rgba(255,255,255,0.25)' : 'rgba(0,0,0,0.06)',
                        overflow: 'hidden',
                      }}>
                        <div style={{ height: '100%', width: `${(w.cleared/w.total)*100}%`,
                          background: w.current ? '#fff' : w.color, borderRadius: 3 }}/>
                      </div>
                      <div style={{ marginTop: 6, fontFamily: theme.fontUI, fontSize: 11, fontWeight: 600,
                        opacity: w.current ? 0.95 : 0.7,
                      }}>{w.cleared}/{w.total} · {w.current ? 'Continue →' : w.cleared === w.total ? 'Mastered' : 'Tap to enter'}</div>
                    </>
                  )}
                </div>
              </div>
            );
          })}
        </div>
      </div>
    </div>
  );
}

// ─── ACHIEVEMENTS / QUESTS ────────────────────────────────────
function QuestsScreen({ theme }) {
  const quests = [
    { label: 'Clear 5 levels',          progress: 3, total: 5,  reward: '+50',  icon: <IconCoin/> },
    { label: 'No hints in 3 levels',    progress: 1, total: 3,  reward: '+1 ❤︎', icon: '❤' },
    { label: 'Complete daily 3 days',   progress: 2, total: 3,  reward: 'Skin',  icon: '🎨' },
  ];
  const achievements = [
    { name: 'First Path',    desc: 'Clear level 1',     icon: '🧭', got: true },
    { name: 'Streaker',      desc: '7-day streak',      icon: '🔥', got: true },
    { name: 'Perfectionist', desc: '10 perfect clears', icon: '✨', got: true },
    { name: 'Cartographer',  desc: 'Clear 50 levels',   icon: '🗺',  got: false, prog: '32/50' },
    { name: 'Skin Collector',desc: 'Unlock 5 themes',   icon: '🎨', got: false, prog: '2/5' },
    { name: 'Untouchable',   desc: '0 fails in chapter',icon: '🛡',  got: false, prog: '—' },
    { name: 'Speedster',     desc: 'Clear under 30s',   icon: '⚡', got: false, prog: '0/1' },
    { name: 'Master',        desc: 'Clear every world', icon: '👑', got: false, prog: '1/5' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'auto', paddingTop: 60, paddingBottom: 40 }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '12px 20px 16px' }}>
        <CircleButton theme={theme}><ChevronBack color={theme.inkSoft}/></CircleButton>
        <div style={{ fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800, color: theme.ink }}>Quests</div>
        <div style={{ width: 40 }}/>
      </div>

      {/* Daily quests */}
      <div style={{ padding: '0 20px 6px', fontFamily: theme.fontUI, fontSize: 11, letterSpacing: 1,
        textTransform: 'uppercase', color: theme.inkMuted, fontWeight: 700,
        display: 'flex', justifyContent: 'space-between',
      }}>
        <span>Daily quests</span>
        <span style={{ color: theme.accent }}>Resets in 6h 12m</span>
      </div>
      <div style={{ margin: '0 16px 18px', borderRadius: 22, overflow: 'hidden',
        background: theme.surface, border: `1px solid ${theme.button.glassBorder}` }}>
        {quests.map((q, i) => (
          <div key={q.label} style={{
            padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 12,
            borderBottom: i < quests.length - 1 ? `1px solid ${theme.button.glassBorder}` : 'none',
          }}>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: theme.fontUI, fontSize: 14, fontWeight: 600, color: theme.ink }}>{q.label}</div>
              <div style={{ marginTop: 6, display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ flex: 1, height: 6, borderRadius: 3, background: 'rgba(0,0,0,0.06)', overflow: 'hidden' }}>
                  <div style={{ height: '100%', width: `${(q.progress/q.total)*100}%`,
                    background: q.progress === q.total ? theme.success : theme.accent, borderRadius: 3 }}/>
                </div>
                <span style={{ fontFamily: theme.fontUI, fontSize: 11, fontWeight: 700, color: theme.inkMuted }}>{q.progress}/{q.total}</span>
              </div>
            </div>
            <div style={{
              padding: '6px 10px', borderRadius: 999,
              background: 'linear-gradient(180deg, #FFF6E0, #FFE5A0)',
              border: '1px solid rgba(208,140,0,0.25)',
              fontFamily: theme.fontDisplay, fontSize: 12, fontWeight: 800, color: '#7A5410',
              display: 'flex', alignItems: 'center', gap: 4,
            }}>
              {typeof q.icon === 'string' ? <span>{q.icon}</span> : q.icon} {q.reward}
            </div>
          </div>
        ))}
      </div>

      {/* Achievements */}
      <div style={{ padding: '0 20px 6px', fontFamily: theme.fontUI, fontSize: 11, letterSpacing: 1,
        textTransform: 'uppercase', color: theme.inkMuted, fontWeight: 700 }}>Achievements · 3 of 8</div>
      <div style={{ margin: '0 16px', display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 10 }}>
        {achievements.map(a => (
          <div key={a.name} style={{
            padding: 12, borderRadius: 18,
            background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
            display: 'flex', gap: 10, alignItems: 'center',
            opacity: a.got ? 1 : 0.6, position: 'relative',
          }}>
            <div style={{
              width: 40, height: 40, borderRadius: 12, flexShrink: 0,
              background: a.got
                ? 'linear-gradient(135deg, #FFE08A, #E08C00)'
                : 'rgba(0,0,0,0.05)',
              display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 20,
              boxShadow: a.got ? 'inset 0 1px 0 rgba(255,255,255,0.4)' : 'none',
            }}>{a.got ? a.icon : <IconLock color={theme.inkMuted}/>}</div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ fontFamily: theme.fontDisplay, fontSize: 13, fontWeight: 800, color: theme.ink,
                overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{a.name}</div>
              <div style={{ fontFamily: theme.fontUI, fontSize: 11, color: theme.inkMuted, marginTop: 1 }}>
                {a.got ? a.desc : a.prog}
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── GAME · OBJECTIVE VARIANT ─────────────────────────────────
// Same game screen but with objective banner + a Gem on the board.
function GameObjectiveScreen({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden', paddingTop: 60,
      display: 'flex', flexDirection: 'column' }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <GameTopBar theme={theme} level={28} onClose/>

      {/* Objective banner replaces hearts banner */}
      <div style={{ display: 'flex', justifyContent: 'center', padding: '0 16px 12px' }}>
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10, padding: '8px 14px', borderRadius: 999,
          background: theme.surface, border: `1px solid ${theme.button.glassBorder}`,
          boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.9), 0 2px 6px rgba(0,0,0,0.05)',
        }}>
          <Gem size={22}/>
          <div style={{ display: 'flex', flexDirection: 'column', lineHeight: 1.1 }}>
            <div style={{ fontFamily: theme.fontUI, fontSize: 9, letterSpacing: 1.2, textTransform: 'uppercase',
              fontWeight: 700, color: theme.inkMuted }}>Objective</div>
            <div style={{ fontFamily: theme.fontDisplay, fontSize: 14, fontWeight: 800, color: theme.ink }}>Free the crystal · 0 / 1</div>
          </div>
          <div style={{ width: 1, height: 24, background: theme.button.glassBorder, marginInline: 4 }}/>
          <HeartRow filled={3} total={4} color={theme.heartFill} size={14}/>
        </div>
      </div>

      <div style={{ flex: 1, padding: '0 18px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ position: 'relative' }}>
          <PuzzleBoard theme={theme} pieces={LAYOUTS.level5} width={344} height={460} pieceStrokeWidth={5.5}/>
          {/* Gem in the middle */}
          <div style={{ position: 'absolute', left: '50%', top: '50%',
            transform: 'translate(-50%, -50%)', filter: `drop-shadow(0 6px 12px ${theme.accent}55)`,
            animation: 'float-up 3s infinite alternate ease-in-out',
          }}>
            <Gem size={62}/>
          </div>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-evenly', alignItems: 'flex-end', padding: '16px 24px 36px' }}>
        <ActionPill theme={theme} label="Hint" badge="3" icon={<IconHint color={theme.ink}/>}/>
        <ActionPill theme={theme} label="Undo" badge="5" icon={<IconUndo color={theme.ink}/>}/>
        <ActionPill theme={theme} label="Restart" icon={<IconRefresh color={theme.ink}/>}/>
      </div>
    </div>
  );
}

// ─── GAME · COMBO VARIANT ─────────────────────────────────────
function GameComboScreen({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden' }}>
      <GameScreen theme={theme}/>
      {/* Combo flash overlay */}
      <div style={{
        position: 'absolute', left: '50%', top: '46%',
        transform: 'translate(-50%, -50%)', textAlign: 'center', pointerEvents: 'none',
      }}>
        <div style={{
          padding: '8px 22px', borderRadius: 999, marginBottom: 12,
          background: `linear-gradient(135deg, ${theme.accent}, ${theme.accent2 ?? theme.accent})`,
          color: '#fff', fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 14,
          letterSpacing: 1.5, textTransform: 'uppercase',
          boxShadow: `0 8px 24px ${theme.accent}66`, display: 'inline-block',
        }}>Chain clear!</div>
        <div style={{
          fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 84, lineHeight: 0.9,
          color: theme.accent, letterSpacing: -3,
          textShadow: `0 4px 30px ${theme.accent}77, 0 0 60px ${theme.accent}33`,
        }}>×3</div>
        <div style={{
          marginTop: 4, fontFamily: theme.fontUI, fontWeight: 700, fontSize: 14,
          color: theme.ink, letterSpacing: 1.4, textTransform: 'uppercase',
        }}>Combo bonus +30</div>
      </div>
      {/* Radial glow halo behind text */}
      <div style={{
        position: 'absolute', left: '50%', top: '46%',
        transform: 'translate(-50%, -50%)', width: 320, height: 320, pointerEvents: 'none',
        background: `radial-gradient(circle, ${theme.accent}22 0%, transparent 70%)`,
        zIndex: -1,
      }}/>
    </div>
  );
}

// ─── GAME · PREVIEW PATH VARIANT ──────────────────────────────
function GamePreviewScreen({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative',
      background: theme.appBg, overflow: 'hidden', paddingTop: 60,
      display: 'flex', flexDirection: 'column' }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <GameTopBar theme={theme} level={12} onClose/>
      <HeartsBanner theme={theme} filled={4} total={4}/>

      <div style={{ flex: 1, padding: '0 18px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
        <div style={{ position: 'relative' }}>
          <PuzzleBoard theme={theme} pieces={LAYOUTS.level5} width={344} height={460} pieceStrokeWidth={5.5}/>

          {/* Preview overlay — selected piece highlight + dotted exit trajectory */}
          <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
            viewBox="0 0 344 460">
            {/* Glow ring on selected piece (uTurn at top-left of board) */}
            <circle cx="110" cy="105" r="62" fill="none"
              stroke={theme.accent} strokeWidth="2" opacity="0.35"/>
            <circle cx="110" cy="105" r="62" fill={theme.accent} opacity="0.07"/>
            {/* Dotted exit path going up */}
            <path d="M 110 80 L 110 -10"
              stroke={theme.accent} strokeWidth="3" strokeDasharray="6 8"
              strokeLinecap="round" fill="none"/>
            {/* Exit dot */}
            <g transform="translate(110 0)">
              <circle r="10" fill={theme.accent} opacity="0.3"/>
              <circle r="6" fill={theme.accent}/>
            </g>
            {/* Label */}
            <g transform="translate(124 92)">
              <rect x="0" y="-12" width="72" height="24" rx="12" fill={theme.accent}/>
              <text x="36" y="4" textAnchor="middle"
                fontFamily="Geist, system-ui" fontSize="11" fontWeight="800"
                fill="#fff" letterSpacing="0.5">EXITS ↑</text>
            </g>
          </svg>

          {/* Finger touch indicator */}
          <div style={{ position: 'absolute', left: 86, top: 130, width: 48, height: 48, borderRadius: '50%',
            background: 'rgba(255,255,255,0.5)', border: `1.5px solid ${theme.accent}`,
            boxShadow: `0 0 24px ${theme.accent}66`,
          }}/>
        </div>
      </div>

      <div style={{ display: 'flex', justifyContent: 'space-evenly', alignItems: 'flex-end', padding: '16px 24px 36px' }}>
        <ActionPill theme={theme} label="Hint" badge="3" icon={<IconHint color={theme.ink}/>}/>
        <ActionPill theme={theme} label="Undo" badge="5" icon={<IconUndo color={theme.ink}/>}/>
        <ActionPill theme={theme} label="Restart" icon={<IconRefresh color={theme.ink}/>}/>
      </div>
    </div>
  );
}

Object.assign(window, {
  DailyMazeScreen, GameModesScreen, WorldMapScreen, QuestsScreen,
  GameObjectiveScreen, GameComboScreen, GamePreviewScreen,
});
