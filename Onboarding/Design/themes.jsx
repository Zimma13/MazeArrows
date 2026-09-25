// themes.jsx — Visual themes for Maze Arrows.
// Each theme defines: bg surfaces, piece stroke, ink, accent, button styles,
// and optional decorative motif (rendered behind the puzzle board).

const THEMES = {
  // ── 1. Aurora Light — premium minimal default ───────────────
  aurora: {
    name: 'Aurora Light',
    appBg: 'radial-gradient(120% 80% at 50% 0%, #FFF7EE 0%, #F5F0E6 60%, #ECE5D6 100%)',
    boardBg: '#FDFBF6',
    boardGrid: 'rgba(26, 27, 46, 0.05)',
    surface: '#FFFFFF',
    ink: '#1A1B2E',
    inkSoft: '#3E3F5C',
    inkMuted: '#8B8CA8',
    pieceStroke: '#1F2042',
    pieceGlow: false,
    accent: '#5B5BD6',
    accent2: '#FF8F65',
    danger: '#EF4458',
    heartFill: '#FF5A6E',
    success: '#3FB680',
    button: {
      primary: 'linear-gradient(180deg, #6B6BE0 0%, #4A4ABF 100%)',
      primaryShadow: '0 4px 0 #2E2EA0, 0 10px 24px rgba(75,75,200,0.32)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.7)',
      glassBorder: 'rgba(26,27,46,0.08)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
  },

  // ── 2. Midnight Neon — dark glowing maze ────────────────────
  neon: {
    name: 'Midnight Neon',
    appBg: 'radial-gradient(120% 90% at 50% 0%, #1B1340 0%, #0D0A24 60%, #07061A 100%)',
    boardBg: 'linear-gradient(180deg, #15123A 0%, #0B0926 100%)',
    boardGrid: 'rgba(180, 130, 255, 0.06)',
    surface: 'rgba(255,255,255,0.06)',
    ink: '#F2F0FF',
    inkSoft: '#C5C0E8',
    inkMuted: '#7A75A0',
    pieceStroke: '#5AF0FF',
    pieceGlow: true,
    accent: '#FF52E4',
    accent2: '#5AF0FF',
    danger: '#FF4D6D',
    heartFill: '#FF4D8A',
    success: '#4CFFB0',
    button: {
      primary: 'linear-gradient(180deg, #FF52E4 0%, #B82FCC 100%)',
      primaryShadow: '0 4px 0 #7A1B95, 0 0 32px rgba(255,82,228,0.5)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.08)',
      glassBorder: 'rgba(255,255,255,0.15)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: 'gridGlow',
  },

  // ── 3. Petal Pastel — soft candy ────────────────────────────
  petal: {
    name: 'Petal Pastel',
    appBg: 'linear-gradient(180deg, #FDE9F0 0%, #FFE9DD 50%, #E7E2FB 100%)',
    boardBg: '#FFFBFA',
    boardGrid: 'rgba(120, 90, 160, 0.06)',
    surface: '#FFFFFF',
    ink: '#4B3A66',
    inkSoft: '#7B6BA8',
    inkMuted: '#B0A4CC',
    pieceStroke: '#7B6BA8',
    pieceGlow: false,
    accent: '#FF8FB1',
    accent2: '#7ECFB8',
    danger: '#F97A8E',
    heartFill: '#FF8FB1',
    success: '#7ECFB8',
    button: {
      primary: 'linear-gradient(180deg, #FFAFC5 0%, #FF7FA0 100%)',
      primaryShadow: '0 4px 0 #E1638A, 0 10px 24px rgba(255,143,177,0.4)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.7)',
      glassBorder: 'rgba(123,107,168,0.12)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: 'petals',
  },

  // ── 4a. Sakura (Japan) ──────────────────────────────────────
  sakura: {
    name: 'Sakura',
    locale: 'JP',
    appBg: 'linear-gradient(180deg, #F9EEEC 0%, #F1D9D7 60%, #E5C0BE 100%)',
    boardBg: '#FAF5F1',
    boardGrid: 'rgba(0,0,0,0.04)',
    surface: '#FFFFFF',
    ink: '#1A1310',
    inkSoft: '#5A453E',
    inkMuted: '#A08B82',
    pieceStroke: '#1A1310',
    pieceGlow: false,
    accent: '#BC4749',
    accent2: '#D4A45C',
    danger: '#BC4749',
    heartFill: '#BC4749',
    success: '#5C8A6B',
    button: {
      primary: 'linear-gradient(180deg, #C8595B 0%, #A53C3E 100%)',
      primaryShadow: '0 4px 0 #7C2C2E, 0 10px 24px rgba(188,71,73,0.28)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(26,19,16,0.1)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: 'seigaiha',
  },

  // ── 4b. Atlas (Morocco) — zellige inspired ──────────────────
  atlas: {
    name: 'Atlas',
    locale: 'MA',
    appBg: 'linear-gradient(180deg, #F4E4CC 0%, #E8C9A0 60%, #D4A877 100%)',
    boardBg: '#FCF6EC',
    boardGrid: 'rgba(20,60,80,0.05)',
    surface: '#FFFFFF',
    ink: '#0F3D4A',
    inkSoft: '#2B5F70',
    inkMuted: '#7C9AA3',
    pieceStroke: '#0F3D4A',
    pieceGlow: false,
    accent: '#C6502E',
    accent2: '#D4A45C',
    danger: '#C6502E',
    heartFill: '#C6502E',
    success: '#3B7F75',
    button: {
      primary: 'linear-gradient(180deg, #D45F3E 0%, #A93D1F 100%)',
      primaryShadow: '0 4px 0 '+'#7A2D17, 0 10px 24px rgba(198,80,46,0.3)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(15,61,74,0.12)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: 'zellige',
  },

  // ── 4c. Nordic — minimal Scandinavian ───────────────────────
  nordic: {
    name: 'Nordic',
    locale: 'SE',
    appBg: 'linear-gradient(180deg, #ECEDE8 0%, #DDDFD7 60%, #C9CCC0 100%)',
    boardBg: '#F6F6F1',
    boardGrid: 'rgba(40,55,40,0.05)',
    surface: '#FFFFFF',
    ink: '#1F2A1E',
    inkSoft: '#3F4E3D',
    inkMuted: '#8A9588',
    pieceStroke: '#1F2A1E',
    pieceGlow: false,
    accent: '#B86A3B',
    accent2: '#6B7F4A',
    danger: '#C2553A',
    heartFill: '#C2553A',
    success: '#6B7F4A',
    button: {
      primary: 'linear-gradient(180deg, #324230 0%, '+'#1F2A1E 100%)',
      primaryShadow: '0 4px 0 #0F140E, 0 10px 24px rgba(31,42,30,0.3)',
      primaryText: '#F6F6F1',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(31,42,30,0.1)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: 'birch',
  },
};

// ─── decorative motifs rendered behind the puzzle board ────────
function ThemeMotif({ kind, color, opacity = 0.06 }) {
  if (!kind) return null;
  const common = {
    position: 'absolute',
    inset: 0,
    pointerEvents: 'none',
    opacity,
  };
  if (kind === 'gridGlow') {
    return (
      <div style={{
        ...common, opacity: 1,
        background: `
          radial-gradient(circle at 20% 30%, rgba(90,240,255,0.12) 0%, transparent 35%),
          radial-gradient(circle at 80% 70%, rgba(255,82,228,0.10) 0%, transparent 35%)
        `,
      }} />
    );
  }
  if (kind === 'petals') {
    return (
      <svg style={common} viewBox="0 0 200 300" preserveAspectRatio="xMidYMid slice">
        {[[30,40,18],[170,80,12],[60,200,15],[180,240,20],[40,260,10]].map(([x,y,r],i)=>(
          <g key={i} transform={`translate(${x} ${y}) rotate(${i*72})`}>
            {[0,1,2,3,4].map(j=>(
              <ellipse key={j} cx="0" cy={-r*0.6} rx={r*0.4} ry={r*0.7}
                fill={color} transform={`rotate(${j*72})`}/>
            ))}
          </g>
        ))}
      </svg>
    );
  }
  if (kind === 'seigaiha') {
    return (
      <svg style={common} viewBox="0 0 200 200" preserveAspectRatio="xMidYMid slice">
        <defs>
          <pattern id="wave" x="0" y="0" width="40" height="20" patternUnits="userSpaceOnUse">
            {[0,8,16].map(r=>(
              <circle key={r} cx="20" cy="20" r={r+4} fill="none" stroke={color} strokeWidth="1"/>
            ))}
            {[0,8,16].map(r=>(
              <circle key={'b'+r} cx="0" cy="20" r={r+4} fill="none" stroke={color} strokeWidth="1"/>
            ))}
            {[0,8,16].map(r=>(
              <circle key={'c'+r} cx="40" cy="20" r={r+4} fill="none" stroke={color} strokeWidth="1"/>
            ))}
          </pattern>
        </defs>
        <rect width="200" height="200" fill="url(#wave)"/>
      </svg>
    );
  }
  if (kind === 'zellige') {
    return (
      <svg style={common} viewBox="0 0 200 200" preserveAspectRatio="xMidYMid slice">
        <defs>
          <pattern id="zel" x="0" y="0" width="40" height="40" patternUnits="userSpaceOnUse">
            <polygon points="20,0 40,20 20,40 0,20" fill="none" stroke={color} strokeWidth="1"/>
            <polygon points="20,8 32,20 20,32 8,20" fill="none" stroke={color} strokeWidth="1"/>
            <line x1="0" y1="20" x2="8" y2="20" stroke={color} strokeWidth="1"/>
            <line x1="32" y1="20" x2="40" y2="20" stroke={color} strokeWidth="1"/>
            <line x1="20" y1="0" x2="20" y2="8" stroke={color} strokeWidth="1"/>
            <line x1="20" y1="32" x2="20" y2="40" stroke={color} strokeWidth="1"/>
          </pattern>
        </defs>
        <rect width="200" height="200" fill="url(#zel)"/>
      </svg>
    );
  }
  if (kind === 'birch') {
    return (
      <svg style={common} viewBox="0 0 200 300" preserveAspectRatio="xMidYMid slice">
        {[20,55,90,125,160].map((x,i)=>(
          <g key={i}>
            <rect x={x} y="0" width="14" height="300" fill={color} opacity="0.5"/>
            {[40,100,180,240].map(y=>(
              <rect key={y} x={x-1} y={y+i*8} width="16" height="6" fill={color}/>
            ))}
          </g>
        ))}
      </svg>
    );
  }
  return null;
}

Object.assign(window, { THEMES, ThemeMotif });
