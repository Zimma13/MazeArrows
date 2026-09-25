// pieces.jsx — Maze-arrow puzzle pieces. Each piece is a connected labyrinth
// path drawn as an SVG with rounded thick strokes, chevron arrowheads, and
// optional emboss / glow. The whole piece is one tappable object.
//
// Coordinate model: pieces author their paths in a local 100x100 box.
// `paths` is an array of { d, arrows:[{x,y,dir}] }. Each path is a single
// polyline (M / L / l commands). Arrows are drawn as chevrons at the
// specified anchor pointing in `dir` (one of up/down/left/right).

// ─── arrow chevron ──────────────────────────────────────────────
function ArrowHead({ x, y, dir, size = 7, stroke, strokeWidth }) {
  // dir → rotation
  const rot = { right: 0, down: 90, left: 180, up: 270 }[dir] ?? 0;
  return (
    <g transform={`translate(${x} ${y}) rotate(${rot})`}>
      <polyline
        points={`-${size},-${size} 0,0 -${size},${size}`}
        fill="none"
        stroke={stroke}
        strokeWidth={strokeWidth}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </g>
  );
}

// ─── single piece ──────────────────────────────────────────────
// state: 'normal' | 'free' | 'blocked' | 'hint' | 'leaving' | 'ghost'
function MazePiece({
  paths = [],
  size = 100,           // viewBox is sizexsize
  width = 120,
  height = 120,
  stroke = '#1A1B2E',
  strokeWidth = 7,
  state = 'normal',
  glow = false,         // neon halo
  emboss = true,        // inner highlight + soft shadow
  accent,               // optional override for state colors
  style = {},
}) {
  // state palette
  const stateColor = {
    normal: stroke,
    free: stroke,
    blocked: '#EF4458',
    hint: '#FFB020',
    leaving: stroke,
    ghost: stroke,
  }[state];
  const opacity = state === 'ghost' ? 0.18 : 1;
  const finalStroke = accent ?? stateColor;
  const filterId = React.useId();

  return (
    <svg
      viewBox={`-10 -10 ${size + 20} ${size + 20}`}
      width={width}
      height={height}
      style={{ overflow: 'visible', display: 'block', ...style }}
    >
      <defs>
        {/* soft drop shadow for depth */}
        <filter id={`shadow-${filterId}`} x="-20%" y="-20%" width="140%" height="140%">
          <feGaussianBlur in="SourceAlpha" stdDeviation="0.6" />
          <feOffset dx="0" dy="1.2" result="off" />
          <feComponentTransfer><feFuncA type="linear" slope="0.22" /></feComponentTransfer>
          <feMerge>
            <feMergeNode />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        {/* neon glow */}
        <filter id={`glow-${filterId}`} x="-50%" y="-50%" width="200%" height="200%">
          <feGaussianBlur stdDeviation="2.4" result="blur" />
          <feMerge>
            <feMergeNode in="blur" />
            <feMergeNode in="blur" />
            <feMergeNode in="SourceGraphic" />
          </feMerge>
        </filter>
        {/* inner highlight gradient for emboss */}
        <linearGradient id={`hi-${filterId}`} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor="#fff" stopOpacity="0.45" />
          <stop offset="0.5" stopColor="#fff" stopOpacity="0" />
        </linearGradient>
      </defs>

      <g
        opacity={opacity}
        filter={glow ? `url(#glow-${filterId})` : emboss ? `url(#shadow-${filterId})` : undefined}
        style={state === 'blocked' ? { animation: 'shake 0.4s' } : undefined}
      >
        {paths.map((p, i) => (
          <g key={i}>
            {/* base stroke */}
            <path
              d={p.d}
              fill="none"
              stroke={finalStroke}
              strokeWidth={strokeWidth}
              strokeLinecap="round"
              strokeLinejoin="round"
            />
            {/* highlight overlay — sits on top of the stroke top edge */}
            {emboss && !glow && (
              <path
                d={p.d}
                fill="none"
                stroke={`url(#hi-${filterId})`}
                strokeWidth={strokeWidth * 0.55}
                strokeLinecap="round"
                strokeLinejoin="round"
                style={{ mixBlendMode: 'overlay' }}
              />
            )}
            {(p.arrows ?? []).map((a, j) => (
              <ArrowHead
                key={j}
                x={a.x}
                y={a.y}
                dir={a.dir}
                stroke={finalStroke}
                strokeWidth={strokeWidth * 0.95}
                size={strokeWidth * 1.1}
              />
            ))}
          </g>
        ))}
      </g>

      {state === 'free' && (
        <g>
          <circle cx={size / 2} cy={size / 2} r={size * 0.62} fill="none" stroke={finalStroke} strokeWidth="1" opacity="0.18" />
        </g>
      )}
    </svg>
  );
}

// ─── piece library — handcrafted shapes ────────────────────────
// All authored on a 100x100 canvas. The shapes are chosen to look like real
// maze labyrinth fragments rather than simple L's.

const PIECES = {
  // Plain right arrow
  arrowRight: {
    paths: [{ d: 'M 5 50 L 90 50', arrows: [{ x: 90, y: 50, dir: 'right' }] }],
  },
  arrowLeft: {
    paths: [{ d: 'M 95 50 L 10 50', arrows: [{ x: 10, y: 50, dir: 'left' }] }],
  },
  arrowUp: {
    paths: [{ d: 'M 50 95 L 50 10', arrows: [{ x: 50, y: 10, dir: 'up' }] }],
  },
  arrowDown: {
    paths: [{ d: 'M 50 5 L 50 90', arrows: [{ x: 50, y: 90, dir: 'down' }] }],
  },
  // L-shape: right then down
  hookRD: {
    paths: [{
      d: 'M 8 30 L 70 30 L 70 90',
      arrows: [{ x: 70, y: 90, dir: 'down' }],
    }],
  },
  // U turn
  uTurn: {
    paths: [{
      d: 'M 15 90 L 15 20 L 85 20 L 85 90',
      arrows: [{ x: 15, y: 90, dir: 'down' }, { x: 85, y: 90, dir: 'down' }],
    }],
  },
  // S snake
  snake: {
    paths: [{
      d: 'M 8 15 L 60 15 L 60 50 L 25 50 L 25 85 L 92 85',
      arrows: [{ x: 92, y: 85, dir: 'right' }],
    }],
  },
  // Comb — three teeth
  comb: {
    paths: [{
      d: 'M 8 80 L 8 25 L 30 25 L 30 60 M 30 25 L 55 25 L 55 60 M 55 25 L 80 25 L 80 60',
      arrows: [
        { x: 30, y: 60, dir: 'down' },
        { x: 55, y: 60, dir: 'down' },
        { x: 80, y: 60, dir: 'down' },
      ],
    }],
  },
  // Spiral
  spiral: {
    paths: [{
      d: 'M 50 50 L 50 25 L 75 25 L 75 75 L 25 75 L 25 15 L 88 15',
      arrows: [{ x: 88, y: 15, dir: 'right' }],
    }],
  },
  // Plus / cross — 4 arms from center
  cross: {
    paths: [{
      d: 'M 50 15 L 50 85 M 15 50 L 85 50',
      arrows: [
        { x: 50, y: 15, dir: 'up' },
        { x: 50, y: 85, dir: 'down' },
        { x: 15, y: 50, dir: 'left' },
        { x: 85, y: 50, dir: 'right' },
      ],
    }],
  },
  // Stairs going up-right
  stairs: {
    paths: [{
      d: 'M 5 90 L 25 90 L 25 65 L 50 65 L 50 40 L 75 40 L 75 15 L 92 15',
      arrows: [{ x: 92, y: 15, dir: 'right' }],
    }],
  },
  // Long zigzag horizontal
  zigzag: {
    paths: [{
      d: 'M 5 30 L 30 30 L 30 70 L 55 70 L 55 30 L 80 30 L 80 70 L 95 70',
      arrows: [{ x: 95, y: 70, dir: 'right' }],
    }],
  },
  // T-junction
  tJunc: {
    paths: [{
      d: 'M 10 30 L 90 30 M 50 30 L 50 90',
      arrows: [
        { x: 10, y: 30, dir: 'left' },
        { x: 90, y: 30, dir: 'right' },
        { x: 50, y: 90, dir: 'down' },
      ],
    }],
  },
  // Coil / branching maze fragment
  coil: {
    paths: [{
      d: 'M 10 90 L 10 50 L 45 50 L 45 25 L 70 25 L 70 65 L 90 65',
      arrows: [{ x: 90, y: 65, dir: 'right' }],
    }],
  },
};

Object.assign(window, { MazePiece, ArrowHead, PIECES });
