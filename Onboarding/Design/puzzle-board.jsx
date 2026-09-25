// puzzle-board.jsx — Renders a board of pieces with theme-aware background.
// Pieces are positioned in board-relative coords (0..100). The board has a
// soft dotted grid and optional motif behind the pieces.

function DotGrid({ color = 'rgba(0,0,0,0.05)', cell = 18 }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, pointerEvents: 'none',
      backgroundImage: `radial-gradient(${color} 1px, transparent 1px)`,
      backgroundSize: `${cell}px ${cell}px`,
      backgroundPosition: '0 0',
      maskImage: 'radial-gradient(120% 100% at 50% 50%, #000 60%, transparent 100%)',
      WebkitMaskImage: 'radial-gradient(120% 100% at 50% 50%, #000 60%, transparent 100%)',
    }}/>
  );
}

// Layout: pieces is array of { key, type, x, y, w, h, rot?, state?, color? }
//   x/y/w/h in % of board
function PuzzleBoard({
  theme,
  width = 360,
  height = 480,
  pieces = [],
  showMotif = true,
  pieceStrokeWidth = 6,
  radius = 28,
}) {
  return (
    <div style={{
      position: 'relative', width, height, borderRadius: radius,
      background: theme.boardBg,
      overflow: 'hidden',
      boxShadow: theme.pieceGlow
        ? 'inset 0 0 0 1px rgba(255,255,255,0.05), inset 0 1px 0 rgba(255,255,255,0.06), 0 30px 60px -20px rgba(0,0,0,0.5)'
        : 'inset 0 0 0 1px rgba(0,0,0,0.04), inset 0 1px 0 rgba(255,255,255,0.8), 0 24px 48px -24px rgba(0,0,0,0.25), 0 4px 8px -4px rgba(0,0,0,0.08)',
    }}>
      {showMotif && (
        <ThemeMotif kind={theme.motif} color={theme.inkMuted ?? '#000'} opacity={theme.pieceGlow ? 1 : 0.07} />
      )}
      <DotGrid color={theme.boardGrid} />

      {pieces.map((p, i) => {
        const def = PIECES[p.type];
        if (!def) return null;
        const w = (p.w ?? 18) / 100 * width;
        const h = (p.h ?? 18) / 100 * height;
        const left = (p.x ?? 50) / 100 * width - w / 2;
        const top = (p.y ?? 50) / 100 * height - h / 2;
        return (
          <div key={p.key ?? i} style={{
            position: 'absolute', left, top, width: w, height: h,
            transform: `rotate(${p.rot ?? 0}deg)`,
            transformOrigin: 'center',
          }}>
            <MazePiece
              paths={def.paths}
              width={w}
              height={h}
              stroke={p.color ?? theme.pieceStroke}
              strokeWidth={pieceStrokeWidth}
              state={p.state ?? 'normal'}
              glow={theme.pieceGlow}
              emboss={!theme.pieceGlow}
            />
          </div>
        );
      })}
    </div>
  );
}

// ─── Curated puzzle layouts ────────────────────────────────────
// Designed to look like the reference: dense, interlocking maze pieces.
// Sized for ~380x540 board.

const LAYOUTS = {
  // Hero layout for game screen — varied, ~18 pieces
  level20: [
    { type: 'snake',     x: 30,  y: 18,  w: 38, h: 18, rot: 0 },
    { type: 'hookRD',    x: 72,  y: 16,  w: 22, h: 18 },
    { type: 'comb',      x: 22,  y: 38,  w: 30, h: 22 },
    { type: 'arrowDown', x: 50,  y: 38,  w: 8,  h: 22 },
    { type: 'uTurn',     x: 75,  y: 40,  w: 26, h: 24 },
    { type: 'arrowLeft', x: 18,  y: 58,  w: 16, h: 8 },
    { type: 'stairs',    x: 50,  y: 60,  w: 36, h: 22 },
    { type: 'zigzag',    x: 25,  y: 78,  w: 40, h: 16 },
    { type: 'tJunc',     x: 75,  y: 78,  w: 22, h: 18 },
    { type: 'arrowRight',x: 15,  y: 92,  w: 18, h: 6 },
    { type: 'coil',      x: 60,  y: 92,  w: 28, h: 14 },
  ],
  // Simpler layout (level 5)
  level5: [
    { type: 'uTurn',     x: 32,  y: 22,  w: 32, h: 22 },
    { type: 'hookRD',    x: 70,  y: 24,  w: 24, h: 22 },
    { type: 'snake',     x: 40,  y: 50,  w: 42, h: 22 },
    { type: 'arrowRight',x: 80,  y: 60,  w: 18, h: 6 },
    { type: 'stairs',    x: 35,  y: 78,  w: 38, h: 22 },
    { type: 'arrowDown', x: 78,  y: 82,  w: 8,  h: 18 },
  ],
  // Compact layout for win/fail screen modal preview
  preview: [
    { type: 'uTurn',     x: 30,  y: 30,  w: 32, h: 28 },
    { type: 'comb',      x: 72,  y: 34,  w: 28, h: 24 },
    { type: 'snake',     x: 40,  y: 65,  w: 42, h: 24 },
    { type: 'arrowRight',x: 82,  y: 75,  w: 18, h: 6 },
  ],
  // Splash / menu hero — one beautiful piece
  hero: [
    { type: 'spiral', x: 50, y: 50, w: 70, h: 70 },
  ],
};

Object.assign(window, { PuzzleBoard, LAYOUTS, DotGrid });
