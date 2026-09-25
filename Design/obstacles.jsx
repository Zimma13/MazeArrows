// obstacles.jsx — Board obstacles: walls, gates, portals, ice tiles, springs.
// Each renders as a small board element at a given position. They sit
// underneath / between pieces in the board grid.

function Wall({ width = 60, height = 18 }) {
  return (
    <div style={{
      width, height, borderRadius: 4,
      background: 'linear-gradient(180deg, #5A4A3A, #2A2018)',
      border: '1px solid #1A1410',
      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.15), 0 2px 3px rgba(0,0,0,0.18)',
      position: 'relative',
    }}>
      {/* brick pattern */}
      <div style={{
        position: 'absolute', inset: 2,
        backgroundImage: 'repeating-linear-gradient(0deg, transparent 0 5px, rgba(0,0,0,0.25) 5px 6px), repeating-linear-gradient(90deg, transparent 0 14px, rgba(0,0,0,0.25) 14px 15px)',
        borderRadius: 2,
      }}/>
    </div>
  );
}

function Gate({ size = 44, color = '#B854E0' }) {
  return (
    <div style={{
      width: size, height: size * 0.5, borderRadius: 6,
      background: `linear-gradient(180deg, ${color}, ${color}cc)`,
      border: `2px solid ${color}`,
      position: 'relative',
      boxShadow: `0 0 12px ${color}55, inset 0 1px 0 rgba(255,255,255,0.4)`,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <svg width={size*0.5} height={size*0.3} viewBox="0 0 20 12">
        <path d="M2 6h12M11 3l3 3-3 3" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
      </svg>
    </div>
  );
}

function Portal({ size = 48, color = '#B854E0' }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: '50%', position: 'relative',
    }}>
      <div style={{
        position: 'absolute', inset: 0, borderRadius: '50%',
        background: `conic-gradient(from 0deg, ${color}, transparent 40%, ${color}, transparent 80%, ${color})`,
        boxShadow: `0 0 16px ${color}66`,
      }}/>
      <div style={{
        position: 'absolute', inset: 6, borderRadius: '50%',
        background: `radial-gradient(circle, ${color}cc, ${color}33)`,
      }}/>
      <div style={{
        position: 'absolute', inset: 14, borderRadius: '50%',
        background: '#0A0826',
        boxShadow: `inset 0 0 8px ${color}aa`,
      }}/>
    </div>
  );
}

function IceTile({ size = 60 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 8,
      background: 'linear-gradient(135deg, #DCEEFF, #A8D0F0)',
      border: '1px solid #88B6D8',
      position: 'relative', overflow: 'hidden',
      boxShadow: 'inset 0 2px 0 rgba(255,255,255,0.65), 0 1px 2px rgba(0,0,0,0.06)',
    }}>
      <svg style={{ position: 'absolute', inset: 0 }} viewBox="0 0 60 60" opacity="0.55">
        {[[15,15],[42,20],[20,45],[44,46]].map(([x,y],i)=>(
          <g key={i} transform={`translate(${x} ${y})`} stroke="#fff" strokeWidth="1.2" strokeLinecap="round">
            <line x1="-4" y1="0" x2="4" y2="0"/>
            <line x1="0" y1="-4" x2="0" y2="4"/>
            <line x1="-3" y1="-3" x2="3" y2="3"/>
            <line x1="-3" y1="3" x2="3" y2="-3"/>
          </g>
        ))}
      </svg>
    </div>
  );
}

function Spring({ size = 44 }) {
  return (
    <div style={{
      width: size, height: size * 0.7, position: 'relative',
      display: 'flex', alignItems: 'flex-end', justifyContent: 'center',
    }}>
      <svg width={size} height={size*0.7} viewBox="0 0 44 30">
        {/* base */}
        <rect x="6" y="24" width="32" height="5" rx="1.5" fill="#3A2D24"/>
        {/* coils */}
        <path d="M10 22 Q 22 18 34 22 Q 22 14 10 18 Q 22 10 34 14 Q 22 6 10 10 Q 22 2 34 6"
          stroke="#A8A8A8" strokeWidth="2.4" fill="none" strokeLinecap="round"/>
        {/* top plate */}
        <rect x="8" y="2" width="28" height="3" rx="1" fill="#E4E4E4" stroke="#888" strokeWidth="0.5"/>
      </svg>
    </div>
  );
}

function DestructibleBlock({ size = 50 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: 8,
      background: 'linear-gradient(180deg, #C9A875 0%, #8C6D44 100%)',
      border: '1px solid #5A4220',
      position: 'relative', overflow: 'hidden',
      boxShadow: 'inset 0 1px 0 rgba(255,255,255,0.25), 0 2px 4px rgba(0,0,0,0.12)',
    }}>
      <svg style={{ position: 'absolute', inset: 4 }} viewBox="0 0 42 42">
        <line x1="0" y1="14" x2="42" y2="14" stroke="rgba(0,0,0,0.25)" strokeWidth="1"/>
        <line x1="0" y1="28" x2="42" y2="28" stroke="rgba(0,0,0,0.25)" strokeWidth="1"/>
        <line x1="14" y1="0" x2="14" y2="14" stroke="rgba(0,0,0,0.25)" strokeWidth="1"/>
        <line x1="28" y1="14" x2="28" y2="28" stroke="rgba(0,0,0,0.25)" strokeWidth="1"/>
        <line x1="14" y1="28" x2="14" y2="42" stroke="rgba(0,0,0,0.25)" strokeWidth="1"/>
      </svg>
    </div>
  );
}

Object.assign(window, { Wall, Gate, Portal, IceTile, Spring, DestructibleBlock });
