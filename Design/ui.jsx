// ui.jsx — Shared UI primitives across screens (buttons, hearts, top bar)

function Heart({ filled = true, color = '#FF5A6E', empty = 'rgba(120,120,140,0.25)', size = 22 }) {
  const c = filled ? color : empty;
  return (
    <svg width={size} height={size * 0.9} viewBox="0 0 24 22">
      <defs>
        <linearGradient id={`hg-${color}-${filled}`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor={c} stopOpacity={filled ? 1 : 1} />
          <stop offset="1" stopColor={c} stopOpacity={filled ? 0.75 : 1} />
        </linearGradient>
      </defs>
      <path
        d="M12 21s-9-5.5-9-12a5 5 0 0 1 9-3 5 5 0 0 1 9 3c0 6.5-9 12-9 12z"
        fill={`url(#hg-${color}-${filled})`}
      />
      {filled && (
        <path
          d="M7 6 Q 8 5 10 5.5"
          stroke="rgba(255,255,255,0.5)"
          strokeWidth="1.2"
          fill="none"
          strokeLinecap="round"
        />
      )}
    </svg>
  );
}

function HeartRow({ total = 4, filled = 4, color = '#FF5A6E', size = 22, gap = 4 }) {
  return (
    <div style={{ display: 'flex', gap, alignItems: 'center' }}>
      {Array.from({ length: total }).map((_, i) => (
        <Heart key={i} filled={i < filled} color={color} size={size} />
      ))}
    </div>
  );
}

function CircleButton({ children, dark, theme, size = 40, style }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size / 2,
      background: theme.button.glass,
      border: `1px solid ${theme.button.glassBorder}`,
      backdropFilter: 'blur(10px)',
      WebkitBackdropFilter: 'blur(10px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      boxShadow: theme.pieceGlow
        ? 'inset 0 1px 0 rgba(255,255,255,0.1)'
        : 'inset 0 1px 0 rgba(255,255,255,0.9), 0 2px 6px rgba(0,0,0,0.06)',
      color: theme.inkSoft,
      ...style,
    }}>{children}</div>
  );
}

function ChevronBack({ color, size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <path d="M10 3l-5 5 5 5" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
function IconRefresh({ color, size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <path d="M3 9a6 6 0 0 1 10.5-4M15 9A6 6 0 0 1 4.5 13" stroke={color} strokeWidth="2" strokeLinecap="round"/>
      <path d="M13 2v3.5h-3.5M5 16v-3.5h3.5" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
function IconHint({ color, size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <path d="M9 1.5a5 5 0 0 0-3 9v2h6v-2a5 5 0 0 0-3-9z" stroke={color} strokeWidth="1.8" strokeLinejoin="round"/>
      <path d="M7 15h4M7.5 17h3" stroke={color} strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  );
}
function IconUndo({ color, size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <path d="M2.5 7H12a4 4 0 0 1 0 8H7" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
      <path d="M5 4l-2.5 3L5 10" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/>
    </svg>
  );
}
function IconSettings({ color, size = 18 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18" fill="none">
      <circle cx="9" cy="9" r="2.5" stroke={color} strokeWidth="1.8"/>
      <path d="M9 1v2M9 15v2M1 9h2M15 9h2M3.3 3.3l1.4 1.4M13.3 13.3l1.4 1.4M3.3 14.7l1.4-1.4M13.3 4.7l1.4-1.4" stroke={color} strokeWidth="1.8" strokeLinecap="round"/>
    </svg>
  );
}
function IconStar({ color, size = 18, filled = true }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18">
      <path d="M9 1.5l2.3 4.7 5.2.7-3.8 3.6.9 5.1L9 13.3l-4.6 2.4.9-5.1L1.5 6.9l5.2-.7z"
        fill={filled ? color : 'none'} stroke={color} strokeWidth="1.5" strokeLinejoin="round"/>
    </svg>
  );
}
function IconLock({ color, size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 16 16" fill="none">
      <rect x="3" y="7" width="10" height="7" rx="1.5" stroke={color} strokeWidth="1.6"/>
      <path d="M5 7V5a3 3 0 0 1 6 0v2" stroke={color} strokeWidth="1.6" strokeLinecap="round"/>
    </svg>
  );
}
function IconPlay({ color, size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 22 22" fill={color}>
      <path d="M6 4.5v13a1 1 0 0 0 1.5.86l11-6.5a1 1 0 0 0 0-1.72l-11-6.5A1 1 0 0 0 6 4.5z"/>
    </svg>
  );
}
function IconCoin({ size = 16 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 18 18">
      <defs>
        <linearGradient id="cg" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#FFD86B"/>
          <stop offset="1" stopColor="#E2A53A"/>
        </linearGradient>
      </defs>
      <circle cx="9" cy="9" r="8" fill="url(#cg)" stroke="#A87A1F" strokeWidth="0.6"/>
      <circle cx="9" cy="9" r="5.5" fill="none" stroke="#A87A1F" strokeWidth="0.6" opacity="0.5"/>
      <text x="9" y="12" textAnchor="middle" fontSize="8" fontWeight="900" fill="#7A5410" fontFamily="system-ui">$</text>
    </svg>
  );
}

// Premium button — gradient + drop shadow ledge
function PrimaryButton({ children, theme, size = 'lg', full = false, style }) {
  const padY = size === 'lg' ? 18 : 14;
  const padX = size === 'lg' ? 28 : 22;
  const fs = size === 'lg' ? 22 : 17;
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      width: full ? '100%' : 'auto', boxSizing: 'border-box',
      padding: `${padY}px ${padX}px`,
      background: theme.button.primary,
      color: theme.button.primaryText,
      fontFamily: theme.fontDisplay,
      fontSize: fs, fontWeight: 800,
      borderRadius: 999,
      boxShadow: theme.button.primaryShadow,
      letterSpacing: 0.3,
      textTransform: 'uppercase',
      position: 'relative',
      ...style,
    }}>
      <div style={{
        position: 'absolute', inset: 1, borderRadius: 999, pointerEvents: 'none',
        background: 'linear-gradient(180deg, rgba(255,255,255,0.35) 0%, rgba(255,255,255,0) 50%)',
      }}/>
      <span style={{ position: 'relative' }}>{children}</span>
    </div>
  );
}

function GhostButton({ children, theme, full, style }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      width: full ? '100%' : 'auto', boxSizing: 'border-box',
      padding: '14px 22px',
      background: theme.button.glass,
      color: theme.ink,
      border: `1.5px solid ${theme.button.glassBorder}`,
      fontFamily: theme.fontDisplay,
      fontSize: 16, fontWeight: 700,
      borderRadius: 999,
      letterSpacing: 0.2,
      textTransform: 'uppercase',
      backdropFilter: 'blur(10px)',
      ...style,
    }}>{children}</div>
  );
}

// Bottom action pill — icon + counter (for hint/undo)
function ActionPill({ icon, count, label, theme, badge }) {
  return (
    <div style={{
      display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
      position: 'relative',
    }}>
      <div style={{
        width: 56, height: 56, borderRadius: 18,
        background: theme.surface,
        border: `1px solid ${theme.button.glassBorder}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: theme.pieceGlow
          ? 'inset 0 1px 0 rgba(255,255,255,0.08), 0 4px 12px rgba(0,0,0,0.25)'
          : 'inset 0 1px 0 rgba(255,255,255,0.9), 0 4px 12px rgba(0,0,0,0.08), 0 1px 2px rgba(0,0,0,0.04)',
        color: theme.ink,
        position: 'relative',
      }}>
        {icon}
        {badge && (
          <div style={{
            position: 'absolute', top: -4, right: -4, minWidth: 20, height: 20,
            padding: '0 5px', borderRadius: 10,
            background: theme.accent, color: '#fff',
            fontSize: 11, fontWeight: 800, fontFamily: theme.fontUI,
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            boxShadow: '0 2px 4px rgba(0,0,0,0.18)',
          }}>{badge}</div>
        )}
      </div>
      <div style={{
        fontFamily: theme.fontUI, fontSize: 11, fontWeight: 600,
        color: theme.inkMuted, letterSpacing: 0.4, textTransform: 'uppercase',
      }}>{label}</div>
    </div>
  );
}

// Top bar shared across game-like screens
function GameTopBar({ theme, level, hearts, totalHearts = 4, onClose }) {
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '16px 20px',
    }}>
      <CircleButton theme={theme}>
        <ChevronBack color={theme.inkSoft}/>
      </CircleButton>
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4 }}>
        <div style={{
          fontFamily: theme.fontUI, fontSize: 11, fontWeight: 700,
          color: theme.inkMuted, letterSpacing: 1.2, textTransform: 'uppercase',
        }}>Level</div>
        <div style={{
          fontFamily: theme.fontDisplay, fontSize: 22, fontWeight: 800,
          color: theme.ink, lineHeight: 1,
        }}>{level}</div>
      </div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
        <CircleButton theme={theme}>
          <IconRefresh color={theme.inkSoft}/>
        </CircleButton>
        {onClose && (
          <CircleButton theme={theme}>
            <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
              <path d="M2 2l10 10M12 2L2 12" stroke={theme.inkSoft} strokeWidth="2" strokeLinecap="round"/>
            </svg>
          </CircleButton>
        )}
      </div>
    </div>
  );
}

// Hearts row, centered below top bar
function HeartsBanner({ theme, filled = 4, total = 4 }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'center', padding: '0 0 12px' }}>
      <div style={{
        display: 'flex', gap: 6, padding: '8px 16px', borderRadius: 999,
        background: theme.surface,
        border: `1px solid ${theme.button.glassBorder}`,
        boxShadow: theme.pieceGlow
          ? 'inset 0 1px 0 rgba(255,255,255,0.06)'
          : 'inset 0 1px 0 rgba(255,255,255,0.9), 0 2px 6px rgba(0,0,0,0.05)',
      }}>
        <HeartRow filled={filled} total={total} color={theme.heartFill} size={18} />
      </div>
    </div>
  );
}

Object.assign(window, {
  Heart, HeartRow, CircleButton, ChevronBack, IconRefresh, IconHint, IconUndo,
  IconSettings, IconStar, IconLock, IconPlay, IconCoin,
  PrimaryButton, GhostButton, ActionPill, GameTopBar, HeartsBanner,
});
