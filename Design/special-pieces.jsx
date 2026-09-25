// special-pieces.jsx — Variants of MazePiece with overlays for special types.
// Each variant takes the same `paths` (a maze fragment) and layers on visual
// affordances: ice frost, gold stroke, lock badge, bomb fuse, chain link, etc.

// ─── Gold gradient piece ───────────────────────────────────────
function PieceGold({ paths, width = 120, height = 120, strokeWidth = 6 }) {
  const id = React.useId();
  return (
    <svg viewBox="-10 -10 120 120" width={width} height={height} style={{ overflow: 'visible' }}>
      <defs>
        <linearGradient id={`gold-${id}`} x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#FFE38B"/>
          <stop offset="0.5" stopColor="#E2A53A"/>
          <stop offset="1" stopColor="#A0691A"/>
        </linearGradient>
        <filter id={`glow-${id}`} x="-30%" y="-30%" width="160%" height="160%">
          <feGaussianBlur stdDeviation="1.6" result="b"/>
          <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
        </filter>
      </defs>
      <g filter={`url(#glow-${id})`}>
        {paths.map((p, i) => (
          <g key={i}>
            <path d={p.d} fill="none" stroke={`url(#gold-${id})`} strokeWidth={strokeWidth}
              strokeLinecap="round" strokeLinejoin="round"/>
            <path d={p.d} fill="none" stroke="#FFF5C2" strokeWidth={strokeWidth*0.35}
              strokeLinecap="round" strokeLinejoin="round" opacity="0.55"
              style={{ mixBlendMode: 'screen' }}/>
            {(p.arrows ?? []).map((a, j) => (
              <ArrowHead key={j} x={a.x} y={a.y} dir={a.dir}
                stroke={`url(#gold-${id})`} strokeWidth={strokeWidth*0.95} size={strokeWidth*1.1}/>
            ))}
          </g>
        ))}
      </g>
    </svg>
  );
}

// ─── Heavy piece — thicker stroke + extra weight ──────────────
function PieceHeavy({ paths, width = 120, height = 120, stroke = '#1A1B2E' }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke={stroke} strokeWidth={11}/>
      {/* Anchor weight dots at endpoints */}
      <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox="-10 -10 120 120" width={width} height={height}>
        {paths.map((p, i) =>
          (p.arrows ?? []).map((a, j) => (
            <circle key={`${i}-${j}`} cx={a.x} cy={a.y} r="3" fill={stroke} opacity="0.4"/>
          ))
        )}
      </svg>
    </div>
  );
}

// ─── Fragile piece — visible crack overlay ────────────────────
function PieceFragile({ paths, width = 120, height = 120, stroke = '#1A1B2E', cracked = 1 }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke={stroke} strokeWidth={6}/>
      {/* Crack overlay drawn on top */}
      <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox="-10 -10 120 120" width={width} height={height}>
        <g stroke="#fff" strokeWidth="1.2" strokeLinecap="round" fill="none" opacity="0.85">
          {/* cracks scaled by cracked count (1 or 2) */}
          <path d="M 30 50 l 4 -3 l -2 -4 l 5 -1"/>
          <path d="M 60 30 l -3 4 l 4 2"/>
          {cracked > 1 && <>
            <path d="M 45 70 l 5 2 l -2 4 l 4 1"/>
            <path d="M 70 60 l 3 -3 l -4 -2"/>
          </>}
        </g>
      </svg>
    </div>
  );
}

// ─── Frozen piece — ice frost overlay ─────────────────────────
function PieceFrozen({ paths, width = 120, height = 120 }) {
  const id = React.useId();
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke="#4D7FAA" strokeWidth={6}/>
      <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox="-10 -10 120 120" width={width} height={height}>
        <defs>
          <radialGradient id={`ice-${id}`}>
            <stop offset="0" stopColor="#BFE6FF" stopOpacity="0.55"/>
            <stop offset="1" stopColor="#BFE6FF" stopOpacity="0"/>
          </radialGradient>
        </defs>
        <rect x="-10" y="-10" width="120" height="120" fill={`url(#ice-${id})`}/>
        {/* Frost flakes */}
        <g stroke="#fff" strokeWidth="1" strokeLinecap="round" opacity="0.9">
          {[[20,20],[80,30],[30,75],[75,80]].map(([x,y],i)=>(
            <g key={i} transform={`translate(${x} ${y})`}>
              <line x1="-4" y1="0" x2="4" y2="0"/>
              <line x1="0" y1="-4" x2="0" y2="4"/>
              <line x1="-3" y1="-3" x2="3" y2="3"/>
              <line x1="-3" y1="3" x2="3" y2="-3"/>
            </g>
          ))}
        </g>
      </svg>
    </div>
  );
}

// ─── Lock piece — closed padlock badge ────────────────────────
function PieceLock({ paths, width = 120, height = 120, color = '#5B5BD6' }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke={color} strokeWidth={6}/>
      <div style={{
        position: 'absolute', top: -4, right: -4,
        width: 32, height: 32, borderRadius: 999,
        background: 'linear-gradient(180deg, #2A2A4A, #16162C)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 4px 8px rgba(0,0,0,0.22), inset 0 1px 0 rgba(255,255,255,0.15)',
        border: `2px solid ${color}`,
      }}>
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <rect x="2.5" y="6" width="9" height="6" rx="1.2" fill="#FFD86B"/>
          <path d="M4.5 6V4.2a2.5 2.5 0 0 1 5 0V6" stroke="#FFD86B" strokeWidth="1.4" fill="none"/>
        </svg>
      </div>
    </div>
  );
}

// ─── Key piece — key badge ────────────────────────────────────
function PieceKey({ paths, width = 120, height = 120, color = '#3FB680' }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke={color} strokeWidth={6}/>
      <div style={{
        position: 'absolute', top: -4, right: -4,
        width: 32, height: 32, borderRadius: 999,
        background: 'linear-gradient(180deg, #FFF, #E8E8E8)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 4px 8px rgba(0,0,0,0.18), inset 0 1px 0 rgba(255,255,255,0.6)',
        border: `2px solid ${color}`,
      }}>
        <svg width="16" height="16" viewBox="0 0 16 16">
          <circle cx="5" cy="8" r="2.6" fill="none" stroke="#7A5410" strokeWidth="1.5"/>
          <path d="M7.5 8h6M11 8v2M13 8v2.5" stroke="#7A5410" strokeWidth="1.5" strokeLinecap="round" fill="none"/>
        </svg>
      </div>
    </div>
  );
}

// ─── Bomb piece — red core + fuse ────────────────────────────
function PieceBomb({ paths, width = 120, height = 120 }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke="#C4153A" strokeWidth={7}/>
      <div style={{
        position: 'absolute', top: -6, right: -6,
        width: 36, height: 36, borderRadius: 999,
        background: 'radial-gradient(circle at 35% 30%, #FF6B7A, #C4153A 70%, #7A0A20 100%)',
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        boxShadow: '0 4px 10px rgba(196,21,58,0.5), inset 0 2px 0 rgba(255,255,255,0.25)',
      }}>
        {/* Fuse */}
        <svg width="20" height="20" viewBox="0 0 20 20" style={{ position: 'absolute', top: -8, right: -2 }}>
          <path d="M10 14 Q 13 10 12 6 Q 11 3 14 1" stroke="#3A2A1A" strokeWidth="1.5" fill="none" strokeLinecap="round"/>
          <circle cx="14" cy="1" r="2.5" fill="#FFB020"/>
          <circle cx="14" cy="1" r="1.2" fill="#FFE8A0"/>
        </svg>
      </div>
    </div>
  );
}

// ─── Chain piece — chain link indicator ───────────────────────
function PieceChain({ paths, width = 120, height = 120, color = '#7B6BA8' }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke={color} strokeWidth={6}/>
      <div style={{
        position: 'absolute', bottom: -4, left: -6,
        width: 36, height: 22, borderRadius: 999,
        background: 'rgba(255,255,255,0.95)',
        border: `1.5px solid ${color}`,
        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 1,
        boxShadow: '0 3px 6px rgba(0,0,0,0.12)',
      }}>
        <svg width="22" height="14" viewBox="0 0 22 14">
          <ellipse cx="6" cy="7" rx="4" ry="3" fill="none" stroke={color} strokeWidth="1.5"/>
          <ellipse cx="11" cy="7" rx="4" ry="3" fill="none" stroke={color} strokeWidth="1.5"/>
          <ellipse cx="16" cy="7" rx="4" ry="3" fill="none" stroke={color} strokeWidth="1.5"/>
        </svg>
      </div>
    </div>
  );
}

// ─── Double-arrow piece — two heads (player chooses dir) ───────
function PieceDouble({ width = 120, height = 120 }) {
  const paths = [{
    d: 'M 50 90 L 50 50 L 90 50 M 50 50 L 50 10',
    arrows: [{ x: 90, y: 50, dir: 'right' }, { x: 50, y: 10, dir: 'up' }],
  }];
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke="#3A6BD6" strokeWidth={6}/>
      {/* Swipe-arc indicator at the junction */}
      <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox="-10 -10 120 120" width={width} height={height}>
        <path d="M 75 50 A 25 25 0 0 0 50 25"
          fill="none" stroke="#3A6BD6" strokeWidth="1.5"
          strokeDasharray="3 3" opacity="0.65"/>
      </svg>
    </div>
  );
}

// ─── Portal piece — glowing ring at one endpoint ──────────────
function PiecePortal({ paths, width = 120, height = 120, color = '#B854E0' }) {
  return (
    <div style={{ position: 'relative' }}>
      <MazePiece paths={paths} width={width} height={height} stroke={color} strokeWidth={6}/>
      <svg style={{ position: 'absolute', inset: 0, pointerEvents: 'none' }}
        viewBox="-10 -10 120 120" width={width} height={height}>
        {paths.map((p, i) =>
          (p.arrows ?? []).slice(0, 1).map((a, j) => (
            <g key={`${i}-${j}`} transform={`translate(${a.x} ${a.y})`}>
              <circle r="11" fill="none" stroke={color} strokeWidth="2" opacity="0.95"/>
              <circle r="7" fill="none" stroke={color} strokeWidth="1.5" opacity="0.55"/>
              <circle r="3.5" fill={color} opacity="0.4"/>
            </g>
          ))
        )}
      </svg>
    </div>
  );
}

// ─── Gem / Goal piece — sparkly objective ─────────────────────
function Gem({ size = 56 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 56 56">
      <defs>
        <linearGradient id="gem-g" x1="0" x2="0" y1="0" y2="1">
          <stop offset="0" stopColor="#7AF0FF"/>
          <stop offset="0.5" stopColor="#5BB6FF"/>
          <stop offset="1" stopColor="#2E5FE0"/>
        </linearGradient>
      </defs>
      <polygon points="28,4 50,22 40,50 16,50 6,22"
        fill="url(#gem-g)" stroke="#1F3FA0" strokeWidth="1.5" strokeLinejoin="round"/>
      <polygon points="28,4 40,22 28,50 16,22"
        fill="rgba(255,255,255,0.18)"/>
      <polygon points="6,22 28,4 50,22 28,18"
        fill="rgba(255,255,255,0.35)"/>
      <circle cx="22" cy="14" r="2" fill="#fff" opacity="0.9"/>
    </svg>
  );
}

Object.assign(window, {
  PieceGold, PieceHeavy, PieceFragile, PieceFrozen, PieceLock, PieceKey,
  PieceBomb, PieceChain, PieceDouble, PiecePortal, Gem,
});
