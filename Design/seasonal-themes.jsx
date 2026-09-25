// seasonal-themes.jsx — Extra event / seasonal skins. These extend the base
// theme palette with cosmetic overlays. Each follows the same shape as
// THEMES entries in themes.jsx.

const SEASONAL_THEMES = {
  winter: {
    name: 'Winter Frost',
    season: 'Dec — Feb',
    appBg: 'linear-gradient(180deg, #E8F2FB 0%, #C8DEED 60%, #A8C6DC 100%)',
    boardBg: '#F4FAFE',
    boardGrid: 'rgba(60,90,120,0.06)',
    surface: '#FFFFFF',
    ink: '#1A2A3A',
    inkSoft: '#3E5870',
    inkMuted: '#8AA0B5',
    pieceStroke: '#3A6BA8',
    pieceGlow: false,
    accent: '#4D9BD8',
    accent2: '#A8D5F0',
    danger: '#D44D6A',
    heartFill: '#D44D6A',
    success: '#5FB68A',
    button: {
      primary: 'linear-gradient(180deg, #6FB8E8 0%, #3A82C0 100%)',
      primaryShadow: '0 4px 0 #2A5E90, 0 10px 24px rgba(77,155,216,0.35)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(60,90,120,0.12)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
    decor: 'snow',
  },
  halloween: {
    name: 'Halloween Shadows',
    season: 'Oct 25 — Nov 2',
    appBg: 'linear-gradient(180deg, #2A0F2E 0%, #1A0822 60%, #0E0418 100%)',
    boardBg: 'linear-gradient(180deg, #2C1535, #160820)',
    boardGrid: 'rgba(255,140,40,0.07)',
    surface: 'rgba(255,255,255,0.05)',
    ink: '#FFE5C2',
    inkSoft: '#E0B080',
    inkMuted: '#A07858',
    pieceStroke: '#FF8A3A',
    pieceGlow: true,
    accent: '#FF8A3A',
    accent2: '#A040E0',
    danger: '#E63A56',
    heartFill: '#FF6A4A',
    success: '#7AE07A',
    button: {
      primary: 'linear-gradient(180deg, #FF9E4D 0%, #C25A1F 100%)',
      primaryShadow: '0 4px 0 #823B12, 0 0 24px rgba(255,138,58,0.5)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.08)',
      glassBorder: 'rgba(255,255,255,0.15)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
    decor: 'bats',
  },
  lunar: {
    name: 'Lunar New Year',
    season: 'Jan 22 — Feb 5',
    appBg: 'linear-gradient(180deg, #FCE2D5 0%, #F5BCAB 60%, #E0856A 100%)',
    boardBg: '#FFF7F0',
    boardGrid: 'rgba(160,30,30,0.06)',
    surface: '#FFFFFF',
    ink: '#3A0E10',
    inkSoft: '#7A1F25',
    inkMuted: '#B07A78',
    pieceStroke: '#A01820',
    pieceGlow: false,
    accent: '#D4A52A',
    accent2: '#A01820',
    danger: '#A01820',
    heartFill: '#A01820',
    success: '#A77A2C',
    button: {
      primary: 'linear-gradient(180deg, #E5C238 0%, #B58A1A 100%)',
      primaryShadow: '0 4px 0 #7C5A0A, 0 10px 24px rgba(212,165,42,0.4)',
      primaryText: '#3A1A06',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(160,24,32,0.15)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
    decor: 'lanterns',
  },
  desert: {
    name: 'Desert Gold',
    season: 'Premium pass',
    appBg: 'linear-gradient(180deg, #FFEFC8 0%, #E8B968 60%, #C2873A 100%)',
    boardBg: '#FFF8E4',
    boardGrid: 'rgba(120,80,20,0.06)',
    surface: '#FFFCF0',
    ink: '#3A2A0E',
    inkSoft: '#6A4F1C',
    inkMuted: '#A88E58',
    pieceStroke: '#7A4F18',
    pieceGlow: false,
    accent: '#D49328',
    accent2: '#A86018',
    danger: '#C2453A',
    heartFill: '#C24528',
    success: '#6B8842',
    button: {
      primary: 'linear-gradient(180deg, #E8B05A 0%, '+'#9E6920 100%)',
      primaryShadow: '0 4px 0 #6A4310, 0 10px 24px rgba(212,147,40,0.4)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(122,79,24,0.15)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
    decor: 'sun',
  },
  ocean: {
    name: 'Ocean Glass',
    season: 'Premium pass',
    appBg: 'linear-gradient(180deg, #D2F0F4 0%, #92D0DC 60%, #3F8A9C 100%)',
    boardBg: '#F0FAFC',
    boardGrid: 'rgba(20,80,100,0.06)',
    surface: '#FFFFFF',
    ink: '#0A2A38',
    inkSoft: '#1F4C5C',
    inkMuted: '#75A2AC',
    pieceStroke: '#0F5266',
    pieceGlow: false,
    accent: '#1F95B0',
    accent2: '#7DD8E2',
    danger: '#D4624A',
    heartFill: '#E07060',
    success: '#3FAA9E',
    button: {
      primary: 'linear-gradient(180deg, #3CC0D6 0%, #15788A 100%)',
      primaryShadow: '0 4px 0 #0A4E5C, 0 10px 24px rgba(31,149,176,0.35)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.75)',
      glassBorder: 'rgba(15,82,102,0.12)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
    decor: 'bubbles',
  },
  cyber: {
    name: 'Cyber Maze',
    season: 'Premium pass',
    appBg: 'linear-gradient(180deg, #0A0F2A 0%, #1A0F35 60%, #06081C 100%)',
    boardBg: 'linear-gradient(180deg, #0F1438, #06081C)',
    boardGrid: 'rgba(80,255,200,0.06)',
    surface: 'rgba(255,255,255,0.05)',
    ink: '#E8F0FF',
    inkSoft: '#9EC0E8',
    inkMuted: '#6478A0',
    pieceStroke: '#7AFFE0',
    pieceGlow: true,
    accent: '#7AFFE0',
    accent2: '#FF52A0',
    danger: '#FF4D6D',
    heartFill: '#FF5A8A',
    success: '#7AFFE0',
    button: {
      primary: 'linear-gradient(180deg, #FF52A0 0%, #B81E80 100%)',
      primaryShadow: '0 4px 0 #7A0E50, 0 0 24px rgba(255,82,160,0.5)',
      primaryText: '#fff',
      glass: 'rgba(255,255,255,0.06)',
      glassBorder: 'rgba(122,255,224,0.25)',
    },
    fontDisplay: '"Bricolage Grotesque", "Geist", system-ui',
    fontUI: '"Geist", system-ui',
    motif: null,
    decor: 'grid',
  },
};

// Decorative event overlays — small SVG illustrations for the seasonal mood
function SeasonalDecor({ kind, color }) {
  const common = { position: 'absolute', inset: 0, pointerEvents: 'none' };
  if (kind === 'snow') {
    return (
      <svg style={common} viewBox="0 0 200 400" preserveAspectRatio="xMidYMid slice">
        {Array.from({ length: 24 }).map((_, i) => {
          const x = (i * 71) % 200;
          const y = (i * 113) % 400;
          const r = 1.5 + (i % 3) * 0.8;
          return <circle key={i} cx={x} cy={y} r={r} fill="#fff" opacity={0.7 - (i%3)*0.15}/>;
        })}
      </svg>
    );
  }
  if (kind === 'bats') {
    return (
      <svg style={common} viewBox="0 0 200 400" preserveAspectRatio="xMidYMid slice" opacity="0.35">
        {[[40,50],[160,90],[80,150],[170,230],[30,280]].map(([x,y],i)=>(
          <g key={i} transform={`translate(${x} ${y}) scale(${0.8 + (i%2)*0.4})`} fill="#1A0E22">
            <path d="M0 0 Q -8 -6 -14 -2 Q -10 4 -6 2 L 0 5 L 6 2 Q 10 4 14 -2 Q 8 -6 0 0Z"/>
          </g>
        ))}
      </svg>
    );
  }
  if (kind === 'lanterns') {
    return (
      <svg style={common} viewBox="0 0 200 400" preserveAspectRatio="xMidYMid slice">
        {[[40,30,'#A01820'],[150,50,'#A01820'],[80,90,'#D4A52A']].map(([x,y,c],i)=>(
          <g key={i} transform={`translate(${x} ${y})`} opacity="0.55">
            <line x1="0" y1="-12" x2="0" y2="0" stroke="#7A1015" strokeWidth="1"/>
            <ellipse cx="0" cy="6" rx="9" ry="11" fill={c}/>
            <ellipse cx="0" cy="6" rx="7" ry="9" fill="none" stroke="#D4A52A" strokeWidth="0.6"/>
            <rect x="-4" y="-2" width="8" height="1.5" fill="#D4A52A"/>
            <rect x="-4" y="14" width="8" height="1.5" fill="#D4A52A"/>
          </g>
        ))}
      </svg>
    );
  }
  if (kind === 'sun') {
    return (
      <svg style={common} viewBox="0 0 200 400" preserveAspectRatio="xMidYMid slice" opacity="0.5">
        <circle cx="170" cy="60" r="40" fill="none" stroke="#D49328" strokeWidth="1"/>
        <circle cx="170" cy="60" r="30" fill="#FFEFC8" opacity="0.6"/>
        {Array.from({ length: 12 }).map((_,i)=>{
          const a = i * Math.PI / 6;
          return <line key={i}
            x1={170 + Math.cos(a)*45} y1={60 + Math.sin(a)*45}
            x2={170 + Math.cos(a)*52} y2={60 + Math.sin(a)*52}
            stroke="#D49328" strokeWidth="2" strokeLinecap="round"/>;
        })}
      </svg>
    );
  }
  if (kind === 'bubbles') {
    return (
      <svg style={common} viewBox="0 0 200 400" preserveAspectRatio="xMidYMid slice" opacity="0.5">
        {[[30,300,12],[60,260,8],[80,310,5],[140,280,14],[170,330,7],[110,200,10]].map(([x,y,r],i)=>(
          <g key={i}>
            <circle cx={x} cy={y} r={r} fill="none" stroke="#fff" strokeWidth="1.5"/>
            <circle cx={x-r*0.3} cy={y-r*0.4} r={r*0.3} fill="#fff" opacity="0.6"/>
          </g>
        ))}
      </svg>
    );
  }
  if (kind === 'grid') {
    return (
      <div style={{
        ...common,
        backgroundImage: 'linear-gradient(rgba(122,255,224,0.18) 1px, transparent 1px), linear-gradient(90deg, rgba(122,255,224,0.18) 1px, transparent 1px)',
        backgroundSize: '32px 32px',
        maskImage: 'radial-gradient(120% 80% at 50% 100%, #000, transparent)',
        WebkitMaskImage: 'radial-gradient(120% 80% at 50% 100%, #000, transparent)',
      }}/>
    );
  }
  return null;
}

Object.assign(window, { SEASONAL_THEMES, SeasonalDecor });
