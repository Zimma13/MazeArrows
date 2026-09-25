// onboarding-paywall.jsx — 3-page onboarding paywall (§5) + closing block (§3 Шаг 6):
// streak + First Steps checklist, push soft-ask, theme pick, L5 continue.

// Shared page shell for the paywall (progress dots, close X, compliance footer)
function PaywallShell({ theme, page, total = 3, showClose = true, children, cta, ctaSub }) {
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: theme.appBg, display: 'flex', flexDirection: 'column',
      paddingTop: 58,
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.04}/>}
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', position: 'relative', padding: '6px 20px 4px' }}>
        <div style={{ display: 'flex', gap: 7 }}>
          {Array.from({ length: total }).map((_, i) => (
            <div key={i} style={{
              width: i === page - 1 ? 22 : 7, height: 7, borderRadius: 999,
              background: i === page - 1 ? theme.accent : theme.button.glassBorder,
            }}/>
          ))}
        </div>
        {showClose && (
          <div style={{ position: 'absolute', right: 18, top: 2, width: 26, height: 26, borderRadius: 999,
            background: theme.button.glass, border: `1px solid ${theme.button.glassBorder}`,
            display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
            <svg width="11" height="11" viewBox="0 0 12 12"><path d="M2 2l8 8M10 2l-8 8" stroke={theme.inkMuted} strokeWidth="1.8" strokeLinecap="round"/></svg>
          </div>
        )}
      </div>

      <div style={{ flex: 1, overflow: 'hidden', display: 'flex', flexDirection: 'column', padding: '4px 22px 0' }}>
        {children}
      </div>

      <div style={{ padding: '10px 22px 20px' }}>
        <PrimaryButton theme={theme} full>{cta}</PrimaryButton>
        {ctaSub && <div style={{ marginTop: 9, textAlign: 'center', fontFamily: theme.fontUI, fontSize: 12, color: theme.inkSoft }}>{ctaSub}</div>}
        <div style={{ marginTop: 12, textAlign: 'center', fontFamily: theme.fontUI, fontSize: 10.5, color: theme.inkMuted, letterSpacing: 0.2 }}>
          Восстановить покупки&nbsp;·&nbsp;Условия&nbsp;·&nbsp;Конфиденциальность
        </div>
      </div>
    </div>
  );
}

// ─── PAYWALL P1 · Value stack + live Photo-Maze inset ─────────
function OB_PaywallValue({ theme }) {
  const bullets = [
    'Безлимитные подсказки — как та, что помогла тебе',
    'Преврати любое фото в лабиринт',
    'Играй без рекламы',
    'Эксклюзивные темы + ежедневный бонус',
  ];
  return (
    <PaywallShell theme={theme} page={1} cta="Продолжить">
      <div style={{ display: 'flex', justifyContent: 'center', gap: 6, marginTop: 2 }}>
        {['arrowRight', 'arrowUp', 'arrowLeft'].map((t, i) => (
          <div key={i} style={{ filter: `drop-shadow(0 4px 10px ${theme.accent}44)` }}>
            <MazePiece paths={PIECES[t].paths} width={44} height={44} stroke={theme.accent} strokeWidth={9} emboss={false}/>
          </div>
        ))}
      </div>
      <div style={{
        marginTop: 6, textAlign: 'center', fontFamily: theme.fontDisplay, fontWeight: 800,
        fontSize: 34, letterSpacing: -1, color: theme.ink, lineHeight: 1,
      }}>Играй без границ</div>

      <div style={{
        marginTop: 16, borderRadius: 18, overflow: 'hidden', position: 'relative',
        height: 118, border: `1px solid ${theme.button.glassBorder}`,
        background: 'linear-gradient(115deg, #F4A15E 0%, #E4677E 45%, #7A5BD6 100%)',
        boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.3), 0 6px 18px rgba(0,0,0,0.1)',
      }}>
        <svg style={{ position: 'absolute', inset: 0, opacity: 0.85 }} viewBox="0 0 320 118" preserveAspectRatio="none">
          {[24, 60, 96].map((y, i) => (
            <path key={i} d={`M8 ${y} L${90 + i * 30} ${y} L${90 + i * 30} ${y + 22} L180 ${y + 22}`}
              fill="none" stroke="#fff" strokeWidth="4" strokeLinecap="round" strokeLinejoin="round" opacity={0.9 - i * 0.15}/>
          ))}
        </svg>
        <div style={{ position: 'absolute', left: 14, bottom: 12, color: '#fff',
          fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 17, textShadow: '0 2px 8px rgba(0,0,0,0.35)' }}>
          Любое фото — лабиринт
        </div>
        <div style={{ position: 'absolute', right: 12, top: 10, fontFamily: theme.fontUI, fontSize: 9.5,
          color: 'rgba(255,255,255,0.85)', letterSpacing: 0.6, textTransform: 'uppercase',
          background: 'rgba(0,0,0,0.18)', padding: '3px 8px', borderRadius: 999 }}>Premium</div>
      </div>

      <div style={{ marginTop: 14, display: 'flex', flexDirection: 'column', gap: 9 }}>
        {bullets.map((b, i) => (
          <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
            <div style={{ width: 24, height: 24, borderRadius: 999, background: theme.success, flexShrink: 0,
              display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <svg width="13" height="13" viewBox="0 0 14 14"><path d="M2 7.5l3.2 3.2L12 4" stroke="#fff" strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
            </div>
            <div style={{ fontFamily: theme.fontUI, fontSize: 14, color: theme.ink, fontWeight: 500, lineHeight: 1.3 }}>{b}</div>
          </div>
        ))}
      </div>
    </PaywallShell>
  );
}

// ─── PAYWALL P2 · Trial timeline ──────────────────────────────
function OB_PaywallTimeline({ theme }) {
  const nodes = [
    { ic: '🔓', k: 'Сегодня', t: 'Полный Premium бесплатно', c: theme.success },
    { ic: '🔔', k: 'День 2', t: 'Напомним — уведомлением или прямо в игре', c: theme.accent },
    { ic: '⭐', k: 'День 3', t: 'С 3-го дня — $5.99/нед. Отмена — в любой момент', c: theme.accent2 },
  ];
  return (
    <PaywallShell theme={theme} page={2} cta="Дальше">
      <div style={{ marginTop: 4, textAlign: 'center', fontFamily: theme.fontUI, fontSize: 12.5, color: theme.inkSoft, letterSpacing: 0.3 }}>
        Как работает бесплатный период
      </div>
      <div style={{
        marginTop: 4, textAlign: 'center', fontFamily: theme.fontDisplay, fontWeight: 800,
        fontSize: 28, letterSpacing: -0.6, color: theme.ink,
      }}>3 дня бесплатно</div>

      <div style={{ marginTop: 26, position: 'relative', paddingLeft: 8 }}>
        <div style={{ position: 'absolute', left: 27, top: 12, bottom: 34, width: 3, borderRadius: 3,
          background: `linear-gradient(180deg, ${theme.success}, ${theme.accent}, ${theme.accent2})` }}/>
        {nodes.map((n, i) => (
          <div key={i} style={{ display: 'flex', gap: 16, alignItems: 'flex-start', marginBottom: 20, position: 'relative' }}>
            <div style={{ width: 40, height: 40, borderRadius: 999, background: theme.surface, flexShrink: 0,
              border: `2px solid ${n.c}`, display: 'flex', alignItems: 'center', justifyContent: 'center',
              fontSize: 19, boxShadow: `0 4px 12px ${n.c}33`, zIndex: 1 }}>{n.ic}</div>
            <div style={{ paddingTop: 2 }}>
              <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 16, color: theme.ink }}>{n.k}</div>
              <div style={{ marginTop: 2, fontFamily: theme.fontUI, fontSize: 13.5, color: theme.inkSoft, lineHeight: 1.35 }}>{n.t}</div>
            </div>
          </div>
        ))}
      </div>

      <div style={{ marginTop: 'auto', marginBottom: 4, padding: '10px 14px', borderRadius: 14,
        background: theme.button.glass, border: `1px solid ${theme.button.glassBorder}`,
        display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ fontSize: 17 }}>🔔</div>
        <div style={{ fontFamily: theme.fontUI, fontSize: 12, color: theme.inkSoft, lineHeight: 1.35 }}>
          Push-разрешение спросим <b>после</b> старта триала. Отказал — напомним баннером в игре.
        </div>
      </div>
    </PaywallShell>
  );
}

// ─── PAYWALL P3 · Plan picker ─────────────────────────────────
function OB_PaywallPlans({ theme }) {
  return (
    <PaywallShell theme={theme} page={3}
      cta="Попробовать 3 дня бесплатно"
      ctaSub="Отмена в любой момент · Списание 21 июля">
      <div style={{
        marginTop: 6, textAlign: 'center', fontFamily: theme.fontDisplay, fontWeight: 800,
        fontSize: 27, letterSpacing: -0.6, color: theme.ink,
      }}>Выбери план</div>

      <div style={{ marginTop: 20, display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div style={{
          position: 'relative', padding: '16px 18px', borderRadius: 20,
          background: theme.surface, border: `2.5px solid ${theme.accent}`,
          boxShadow: `0 8px 22px ${theme.accent}22`,
        }}>
          <div style={{ position: 'absolute', top: -11, right: 18, padding: '3px 12px', borderRadius: 999,
            background: theme.accent, color: '#fff', fontFamily: theme.fontUI, fontSize: 10.5, fontWeight: 800,
            letterSpacing: 0.4, textTransform: 'uppercase' }}>Популярный</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 22, height: 22, borderRadius: 999, border: `2px solid ${theme.accent}`,
              display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
              <div style={{ width: 11, height: 11, borderRadius: 999, background: theme.accent }}/>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 17, color: theme.ink }}>Неделя</div>
              <div style={{ fontFamily: theme.fontUI, fontSize: 13, color: theme.inkSoft }}>3 дня бесплатно, затем $5.99/нед</div>
            </div>
          </div>
        </div>

        <div style={{
          position: 'relative', padding: '16px 18px', borderRadius: 20,
          background: theme.surface, border: `1.5px solid ${theme.button.glassBorder}`,
        }}>
          <div style={{ position: 'absolute', top: -11, right: 18, padding: '3px 12px', borderRadius: 999,
            background: theme.success, color: '#fff', fontFamily: theme.fontUI, fontSize: 10.5, fontWeight: 800,
            letterSpacing: 0.4, textTransform: 'uppercase' }}>−90%</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 22, height: 22, borderRadius: 999, border: `2px solid ${theme.inkMuted}`, flexShrink: 0 }}/>
            <div style={{ flex: 1 }}>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 17, color: theme.ink }}>Год</div>
                <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 17, color: theme.ink }}>$29.99/год</div>
              </div>
              <div style={{ fontFamily: theme.fontUI, fontSize: 13, color: theme.inkSoft }}>≈ $0.58/нед · без триала</div>
            </div>
          </div>
        </div>
      </div>

      <div style={{ marginTop: 14, textAlign: 'center', fontFamily: theme.fontUI, fontSize: 11.5, color: theme.inkMuted, lineHeight: 1.4 }}>
        Триал только у недельного плана. Годовой — реальная цена, без «бесплатно сегодня».
      </div>
    </PaywallShell>
  );
}

// ─── STREAK + First Steps checklist (§3 Шаг 6) ────────────────
function OB_Streak({ theme }) {
  const items = [
    { t: 'Первый полёт', done: true },
    { t: 'Первое комбо', done: true },
    { t: 'Пройди уровень 5', done: false },
    { t: 'Сыграй ежедневный лабиринт', done: false },
    { t: 'Вернись завтра', done: false, note: 'серия дней продолжится' },
  ];
  return (
    <div style={{
      width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: theme.appBg, display: 'flex', flexDirection: 'column',
      alignItems: 'center', padding: '74px 22px 24px',
    }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <div style={{
        width: 92, height: 92, borderRadius: 999, position: 'relative',
        background: `radial-gradient(circle at 38% 30%, #FFE08A, #FF8F65 60%, ${theme.accent} 110%)`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', flexDirection: 'column',
        boxShadow: `0 12px 30px ${theme.accent}44, inset 0 2px 0 rgba(255,255,255,0.5)`,
      }}>
        <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 40, color: '#fff', lineHeight: 1 }}>1</div>
        <div style={{ fontFamily: theme.fontUI, fontSize: 10, fontWeight: 700, color: '#fff', letterSpacing: 1, textTransform: 'uppercase' }}>день</div>
      </div>
      <div style={{ marginTop: 16, fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 26, color: theme.ink, letterSpacing: -0.5, textAlign: 'center' }}>
        День 1 из твоей серии!
      </div>
      <div style={{ marginTop: 8, display: 'inline-flex', alignItems: 'center', gap: 7, padding: '6px 14px', borderRadius: 999,
        background: 'linear-gradient(180deg, #FFF6E0, #FFE5A0)', border: '1px solid rgba(208,140,0,0.25)',
        fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 14, color: '#7A5410' }}>
        <IconCoin/> +25 · подарок за старт
      </div>

      <div style={{ marginTop: 20, width: '100%', padding: 18, borderRadius: 22, background: theme.surface,
        border: `1px solid ${theme.button.glassBorder}`, boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7), 0 8px 22px rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
          <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 16, color: theme.ink }}>Первые шаги</div>
          <div style={{ fontFamily: theme.fontUI, fontSize: 12, fontWeight: 700, color: theme.accent }}>40%</div>
        </div>
        <div style={{ height: 7, borderRadius: 999, background: theme.button.glassBorder, overflow: 'hidden', marginBottom: 14 }}>
          <div style={{ width: '40%', height: '100%', borderRadius: 999, background: theme.accent }}/>
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
          {items.map((it, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 11 }}>
              <div style={{ width: 22, height: 22, borderRadius: 7, flexShrink: 0,
                background: it.done ? theme.success : 'transparent',
                border: it.done ? 'none' : `2px solid ${theme.button.glassBorder}`,
                display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {it.done && <svg width="12" height="12" viewBox="0 0 14 14"><path d="M2 7.5l3.2 3.2L12 4" stroke="#fff" strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>}
              </div>
              <div style={{ flex: 1 }}>
                <span style={{ fontFamily: theme.fontUI, fontSize: 14, fontWeight: it.done ? 600 : 500,
                  color: it.done ? theme.inkMuted : theme.ink, textDecoration: it.done ? 'line-through' : 'none' }}>{it.t}</span>
                {it.note && <span style={{ fontFamily: theme.fontUI, fontSize: 11.5, color: theme.inkMuted }}> · {it.note}</span>}
              </div>
            </div>
          ))}
        </div>
      </div>
      <div style={{ flex: 1 }}/>
      <PrimaryButton theme={theme} full size="md">Забрать подарок</PrimaryButton>
    </div>
  );
}

// ─── PUSH soft-ask pre-prompt ─────────────────────────────────
function OB_Push({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden', background: theme.appBg }}>
      <div style={{ position: 'absolute', inset: 0, opacity: 0.25, filter: 'blur(1px)' }}>
        <OB_Streak theme={theme}/>
      </div>
      <div style={{ position: 'absolute', inset: 0, background: 'rgba(10,10,20,0.35)' }}/>
      <div style={{ position: 'absolute', left: 22, right: 22, bottom: 34, padding: 22, borderRadius: 26,
        background: theme.surface, boxShadow: '0 20px 50px rgba(0,0,0,0.28)' }}>
        <div style={{ width: 54, height: 54, borderRadius: 16, margin: '0 auto',
          background: `linear-gradient(180deg, ${theme.accent}, ${theme.accent2})`,
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 26,
          boxShadow: `0 8px 20px ${theme.accent}44` }}>🔔</div>
        <div style={{ marginTop: 14, textAlign: 'center', fontFamily: theme.fontDisplay, fontWeight: 800,
          fontSize: 19, color: theme.ink, lineHeight: 1.2 }}>
          Напомнить о ежедневном лабиринте и твоей серии?
        </div>
        <div style={{ marginTop: 8, textAlign: 'center', fontFamily: theme.fontUI, fontSize: 13, color: theme.inkSoft, lineHeight: 1.4 }}>
          Один тихий пуш в день. Никакого спама.
        </div>
        <div style={{ marginTop: 18 }}>
          <PrimaryButton theme={theme} full size="md">Да, напомни</PrimaryButton>
        </div>
        <div style={{ marginTop: 10, textAlign: 'center', fontFamily: theme.fontUI, fontSize: 14, fontWeight: 600, color: theme.inkMuted }}>Не сейчас</div>
      </div>
    </div>
  );
}

// ─── THEME PICK (endowment, skippable) ────────────────────────
function OB_ThemePick({ theme, themes }) {
  const opts = [
    { key: 'aurora', sub: 'Мягкий светлый' },
    { key: 'neon', sub: 'Тёмный неон' },
    { key: 'petal', sub: 'Нежная пастель' },
  ];
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: theme.appBg, display: 'flex', flexDirection: 'column', padding: '78px 22px 26px' }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 28, color: theme.ink, letterSpacing: -0.6 }}>Выбери свой стиль</div>
        <div style={{ marginTop: 8, fontFamily: theme.fontUI, fontSize: 13.5, color: theme.inkSoft }}>Тема применится мгновенно. Это твоя доска.</div>
      </div>
      <div style={{ marginTop: 26, display: 'flex', flexDirection: 'column', gap: 14 }}>
        {opts.map((o) => {
          const t = themes[o.key];
          const selected = o.key === 'aurora';
          return (
            <div key={o.key} style={{
              display: 'flex', alignItems: 'center', gap: 16, padding: 12, borderRadius: 20,
              background: theme.surface, border: `2px solid ${selected ? theme.accent : theme.button.glassBorder}`,
              boxShadow: selected ? `0 8px 22px ${theme.accent}22` : 'none',
            }}>
              <div style={{ width: 76, height: 76, borderRadius: 14, overflow: 'hidden', flexShrink: 0 }}>
                <div style={{ transform: 'scale(0.72)', transformOrigin: 'top left', width: 106, height: 106 }}>
                  <PuzzleBoard theme={t} width={106} height={106} radius={14} pieceStrokeWidth={7}
                    showMotif={false} pieces={[
                      { type: 'arrowRight', x: 30, y: 30, w: 40, h: 16 },
                      { type: 'arrowUp', x: 72, y: 62, w: 16, h: 40 },
                      { type: 'hookRD', x: 34, y: 70, w: 34, h: 34 },
                    ]}/>
                </div>
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 17, color: theme.ink }}>{t.name}</div>
                <div style={{ fontFamily: theme.fontUI, fontSize: 12.5, color: theme.inkSoft }}>{o.sub}</div>
              </div>
              {selected && <div style={{ width: 26, height: 26, borderRadius: 999, background: theme.accent,
                display: 'flex', alignItems: 'center', justifyContent: 'center', marginRight: 6 }}>
                <svg width="13" height="13" viewBox="0 0 14 14"><path d="M2 7.5l3.2 3.2L12 4" stroke="#fff" strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>
              </div>}
            </div>
          );
        })}
      </div>
      <div style={{ flex: 1 }}/>
      <div style={{ textAlign: 'center', fontFamily: theme.fontUI, fontSize: 11.5, color: theme.inkMuted, marginBottom: 14 }}>Ещё 3 темы — в Premium</div>
      <GhostButton theme={theme} full>Позже</GhostButton>
    </div>
  );
}

// ─── L5 continue / world map handoff ──────────────────────────
function OB_Continue({ theme }) {
  return (
    <div style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden',
      background: theme.appBg, display: 'flex', flexDirection: 'column', padding: '90px 22px 28px' }}>
      {theme.motif && <ThemeMotif kind={theme.motif} color={theme.inkMuted} opacity={0.05}/>}
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontFamily: theme.fontUI, fontSize: 12, fontWeight: 700, letterSpacing: 1.4, color: theme.inkMuted, textTransform: 'uppercase' }}>Ты в ударе</div>
        <div style={{ marginTop: 8, fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 32, color: theme.ink, letterSpacing: -1 }}>4 уровня пройдено</div>
      </div>

      <div style={{ marginTop: 26, padding: 18, borderRadius: 22, background: theme.surface,
        border: `1px solid ${theme.button.glassBorder}`, boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.7), 0 8px 22px rgba(0,0,0,0.05)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'space-between' }}>
          {[1, 2, 3, 4, 5].map(n => {
            const done = n <= 4, next = n === 5;
            return (
              <React.Fragment key={n}>
                <div style={{ width: 40, height: 40, borderRadius: 999, flexShrink: 0,
                  background: done ? theme.success : next ? theme.accent : theme.button.glass,
                  border: next ? `2px solid ${theme.accent}` : 'none',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontFamily: theme.fontDisplay, fontWeight: 800, fontSize: 15,
                  color: done || next ? '#fff' : theme.inkMuted,
                  boxShadow: next ? `0 6px 16px ${theme.accent}55` : 'none' }}>
                  {done ? '✓' : n}
                </div>
                {n < 5 && <div style={{ flex: 1, height: 3, borderRadius: 3, background: n < 4 ? theme.success : theme.button.glassBorder }}/>}
              </React.Fragment>
            );
          })}
        </div>
        <div style={{ marginTop: 14, display: 'flex', alignItems: 'center', gap: 8, padding: '10px 14px', borderRadius: 12,
          background: theme.button.glass }}>
          <IconLock color={theme.inkMuted}/>
          <div style={{ fontFamily: theme.fontUI, fontSize: 12.5, color: theme.inkSoft }}>Глава 2 — видна, но заперта. Пройди главу 1.</div>
        </div>
      </div>

      <div style={{ flex: 1 }}/>
      <PrimaryButton theme={theme} full>Дальше → Уровень 5</PrimaryButton>
      <div style={{ marginTop: 10 }}>
        <GhostButton theme={theme} full>На карту мира</GhostButton>
      </div>
    </div>
  );
}

Object.assign(window, {
  PaywallShell, OB_PaywallValue, OB_PaywallTimeline, OB_PaywallPlans,
  OB_Streak, OB_Push, OB_ThemePick, OB_Continue,
});
