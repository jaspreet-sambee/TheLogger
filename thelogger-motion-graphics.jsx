import { useState, useEffect, useRef } from "react";

// ============================================================
// TheLogger Motion Graphics – UGC Marketing Video (9:16 vertical)
// Auto-plays through 4 scenes. Screen-record at 1080x1920.
// ============================================================

const SCENE_DURATION = 4500; // ms per scene
const TOTAL_SCENES = 5; // intro + 3 content + outro

// -- Color palette (matches app) --
const C = {
  bg: "#0a0a1a",
  card: "#1a1a2e",
  cardBorder: "#2a2a3e",
  accent: "#ef4444",
  accentLight: "#f87171",
  accentGlow: "rgba(239,68,68,0.3)",
  gold: "#eab308",
  goldGlow: "rgba(234,179,8,0.4)",
  text: "#ffffff",
  textMuted: "#94a3b8",
  green: "#22c55e",
};

// -- Reusable animated wrapper --
function FadeSlide({ show, delay = 0, from = "bottom", duration = 600, children, style = {} }) {
  const [visible, setVisible] = useState(false);
  useEffect(() => {
    if (show) {
      const t = setTimeout(() => setVisible(true), delay);
      return () => clearTimeout(t);
    }
    setVisible(false);
  }, [show, delay]);

  const transforms = {
    bottom: "translateY(40px)",
    top: "translateY(-40px)",
    left: "translateX(-60px)",
    right: "translateX(60px)",
    scale: "scale(0.8)",
    none: "none",
  };

  return (
    <div
      style={{
        opacity: visible ? 1 : 0,
        transform: visible ? "none" : transforms[from],
        transition: `opacity ${duration}ms ease, transform ${duration}ms ease`,
        ...style,
      }}
    >
      {children}
    </div>
  );
}

// -- Confetti particles --
function Confetti({ active }) {
  const particles = Array.from({ length: 30 }, (_, i) => ({
    id: i,
    left: Math.random() * 100,
    delay: Math.random() * 2,
    duration: 2 + Math.random() * 2,
    size: 4 + Math.random() * 6,
    color: [C.accent, C.gold, C.green, "#8b5cf6", "#f59e0b"][i % 5],
    rotation: Math.random() * 360,
  }));

  if (!active) return null;

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", pointerEvents: "none", zIndex: 50 }}>
      {particles.map((p) => (
        <div
          key={p.id}
          style={{
            position: "absolute",
            left: `${p.left}%`,
            top: "-10%",
            width: p.size,
            height: p.size * 1.4,
            backgroundColor: p.color,
            borderRadius: 2,
            transform: `rotate(${p.rotation}deg)`,
            animation: `confettiFall ${p.duration}s ease-in ${p.delay}s infinite`,
          }}
        />
      ))}
      <style>{`
        @keyframes confettiFall {
          0% { transform: translateY(0) rotate(0deg); opacity: 1; }
          100% { transform: translateY(1920px) rotate(720deg); opacity: 0; }
        }
      `}</style>
    </div>
  );
}

// -- Floating particles background --
function FloatingParticles() {
  const dots = Array.from({ length: 20 }, (_, i) => ({
    id: i,
    x: Math.random() * 100,
    y: Math.random() * 100,
    size: 2 + Math.random() * 3,
    duration: 8 + Math.random() * 12,
    delay: Math.random() * 5,
  }));

  return (
    <div style={{ position: "absolute", inset: 0, overflow: "hidden", pointerEvents: "none" }}>
      {dots.map((d) => (
        <div
          key={d.id}
          style={{
            position: "absolute",
            left: `${d.x}%`,
            top: `${d.y}%`,
            width: d.size,
            height: d.size,
            borderRadius: "50%",
            backgroundColor: C.accentGlow,
            animation: `floatDot ${d.duration}s ease-in-out ${d.delay}s infinite alternate`,
          }}
        />
      ))}
      <style>{`
        @keyframes floatDot {
          0% { transform: translate(0, 0); opacity: 0.3; }
          50% { opacity: 0.7; }
          100% { transform: translate(${20 - Math.random() * 40}px, ${-30 - Math.random() * 30}px); opacity: 0.2; }
        }
      `}</style>
    </div>
  );
}

// -- App Icon component --
function AppIcon({ size = 80 }) {
  return (
    <div
      style={{
        width: size,
        height: size,
        borderRadius: size * 0.22,
        background: "linear-gradient(135deg, #1a1a2e, #0a0a1a)",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        border: `2px solid ${C.accent}`,
        boxShadow: `0 0 30px ${C.accentGlow}`,
        flexShrink: 0,
      }}
    >
      <svg width={size * 0.6} height={size * 0.6} viewBox="0 0 60 60" fill="none">
        {/* Dumbbell */}
        <rect x="8" y="22" width="8" height="16" rx="2" fill={C.accent} />
        <rect x="44" y="22" width="8" height="16" rx="2" fill={C.accent} />
        <rect x="14" y="27" width="32" height="6" rx="2" fill={C.accent} />
        {/* Checkmark */}
        <path d="M22 32 L28 38 L42 22" stroke={C.accentLight} strokeWidth="3.5" strokeLinecap="round" strokeLinejoin="round" fill="none" />
      </svg>
    </div>
  );
}

// -- Phone mockup wrapper --
function PhoneMockup({ children, style = {} }) {
  return (
    <div
      style={{
        width: 260,
        height: 520,
        borderRadius: 32,
        border: `2px solid ${C.cardBorder}`,
        background: C.bg,
        overflow: "hidden",
        boxShadow: `0 20px 60px rgba(0,0,0,0.6), 0 0 40px ${C.accentGlow}`,
        position: "relative",
        flexShrink: 0,
        ...style,
      }}
    >
      {/* Notch */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: "50%",
          transform: "translateX(-50%)",
          width: 100,
          height: 24,
          background: "#000",
          borderRadius: "0 0 16px 16px",
          zIndex: 10,
        }}
      />
      <div style={{ padding: "32px 14px 14px", height: "100%", boxSizing: "border-box", overflow: "hidden" }}>
        {children}
      </div>
    </div>
  );
}

// -- Workout set row --
function SetRow({ num, reps, weight, checked, isNew, delay = 0, show }) {
  const [vis, setVis] = useState(false);
  useEffect(() => {
    if (show) {
      const t = setTimeout(() => setVis(true), delay);
      return () => clearTimeout(t);
    }
    setVis(false);
  }, [show, delay]);

  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        padding: "8px 10px",
        background: C.card,
        borderRadius: 10,
        marginBottom: 6,
        border: `1px solid ${isNew ? C.gold : C.cardBorder}`,
        opacity: vis ? 1 : 0,
        transform: vis ? "translateX(0)" : "translateX(30px)",
        transition: "all 500ms ease",
        boxShadow: isNew ? `0 0 15px ${C.goldGlow}` : "none",
      }}
    >
      <div
        style={{
          width: 22,
          height: 22,
          borderRadius: "50%",
          background: checked ? C.accent : "transparent",
          border: `2px solid ${checked ? C.accent : C.textMuted}`,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          marginRight: 8,
          fontSize: 11,
          color: checked ? "#fff" : C.textMuted,
          fontWeight: 700,
        }}
      >
        {num}
      </div>
      <span style={{ fontSize: 13, color: C.text, flex: 1 }}>
        <span style={{ fontWeight: 600 }}>{reps}</span>
        <span style={{ color: C.textMuted, margin: "0 4px" }}>×</span>
      </span>
      <span style={{ fontSize: 14, fontWeight: 700, color: C.text }}>
        {weight} <span style={{ fontSize: 11, color: C.textMuted }}>lbs</span>
      </span>
    </div>
  );
}

// -- Timer bar --
function TimerBar({ active, progress }) {
  return (
    <div
      style={{
        display: "flex",
        alignItems: "center",
        gap: 8,
        padding: "6px 10px",
        background: C.card,
        borderRadius: 10,
        border: `1px solid ${C.cardBorder}`,
        opacity: active ? 1 : 0,
        transition: "opacity 400ms",
      }}
    >
      <span style={{ fontSize: 13, fontWeight: 700, color: C.accent, fontVariantNumeric: "tabular-nums" }}>
        1:{String(Math.floor(30 * (1 - progress))).padStart(2, "0")}
      </span>
      <div style={{ flex: 1, height: 4, background: "#2a2a3e", borderRadius: 2, overflow: "hidden" }}>
        <div
          style={{
            width: `${progress * 100}%`,
            height: "100%",
            background: `linear-gradient(90deg, ${C.accent}, ${C.accentLight})`,
            borderRadius: 2,
            transition: "width 300ms linear",
          }}
        />
      </div>
      <span style={{ fontSize: 11, color: C.textMuted }}>Skip</span>
    </div>
  );
}

// -- PR Badge --
function PRBadge({ show }) {
  return (
    <FadeSlide show={show} from="scale" delay={200}>
      <div
        style={{
          background: "rgba(20,20,30,0.95)",
          border: `2px solid ${C.gold}`,
          borderRadius: 16,
          padding: "16px 28px",
          textAlign: "center",
          boxShadow: `0 0 40px ${C.goldGlow}`,
        }}
      >
        <div style={{ fontSize: 36, marginBottom: 4 }}>🏆</div>
        <div style={{ fontSize: 18, fontWeight: 800, color: C.text, letterSpacing: 1 }}>NEW PR!</div>
        <div style={{ fontSize: 12, color: C.gold, marginTop: 2 }}>Personal Record</div>
      </div>
    </FadeSlide>
  );
}

// -- Progress Chart --
function MiniChart({ show }) {
  const points = [20, 35, 30, 45, 42, 55, 50, 65, 60, 75, 80];
  const w = 220;
  const h = 80;
  const maxVal = 85;

  const pathD = points
    .map((v, i) => {
      const x = (i / (points.length - 1)) * w;
      const y = h - (v / maxVal) * h;
      return `${i === 0 ? "M" : "L"} ${x} ${y}`;
    })
    .join(" ");

  return (
    <FadeSlide show={show} delay={300} from="bottom">
      <div style={{ background: C.card, borderRadius: 12, padding: "10px 12px", border: `1px solid ${C.cardBorder}` }}>
        <div style={{ fontSize: 11, color: C.textMuted, marginBottom: 6 }}>Weight Over Time</div>
        <svg width={w} height={h} style={{ overflow: "visible" }}>
          <defs>
            <linearGradient id="chartFill" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={C.accent} stopOpacity="0.3" />
              <stop offset="100%" stopColor={C.accent} stopOpacity="0" />
            </linearGradient>
          </defs>
          <path d={pathD + ` L ${w} ${h} L 0 ${h} Z`} fill="url(#chartFill)" />
          <path
            d={pathD}
            stroke={C.accent}
            strokeWidth="2"
            fill="none"
            strokeDasharray={show ? "none" : "500"}
            strokeDashoffset={show ? 0 : 500}
            style={{ transition: "stroke-dashoffset 2s ease" }}
          />
          {/* End dot */}
          <circle cx={w} cy={h - (80 / maxVal) * h} r="4" fill={C.accent}>
            <animate attributeName="r" values="4;6;4" dur="1.5s" repeatCount="indefinite" />
          </circle>
        </svg>
      </div>
    </FadeSlide>
  );
}

// -- Stat card --
function StatCard({ label, value, icon, show, delay = 0 }) {
  return (
    <FadeSlide show={show} delay={delay} from="bottom">
      <div
        style={{
          background: C.card,
          borderRadius: 12,
          padding: "10px 14px",
          border: `1px solid ${C.cardBorder}`,
          textAlign: "center",
          minWidth: 80,
        }}
      >
        <div style={{ fontSize: 18, marginBottom: 2 }}>{icon}</div>
        <div style={{ fontSize: 22, fontWeight: 800, color: C.text }}>{value}</div>
        <div style={{ fontSize: 10, color: C.textMuted, marginTop: 2 }}>{label}</div>
      </div>
    </FadeSlide>
  );
}

// ============================================================
// MAIN COMPONENT
// ============================================================
export default function TheLoggerMotionGraphics() {
  const [scene, setScene] = useState(0);
  const [timer, setTimer] = useState(0);
  const [timerProgress, setTimerProgress] = useState(0);
  const [setsChecked, setSetsChecked] = useState(0);

  // Scene auto-advance
  useEffect(() => {
    const interval = setInterval(() => {
      setScene((s) => (s + 1) % TOTAL_SCENES);
    }, SCENE_DURATION);
    return () => clearInterval(interval);
  }, []);

  // Timer animation for scene 2
  useEffect(() => {
    if (scene === 2) {
      setTimerProgress(0);
      const interval = setInterval(() => {
        setTimerProgress((p) => Math.min(p + 0.04, 1));
      }, 150);
      return () => clearInterval(interval);
    }
  }, [scene]);

  // Sets checking animation for scene 1
  useEffect(() => {
    if (scene === 1) {
      setSetsChecked(0);
      const timers = [
        setTimeout(() => setSetsChecked(1), 800),
        setTimeout(() => setSetsChecked(2), 1600),
        setTimeout(() => setSetsChecked(3), 2400),
        setTimeout(() => setSetsChecked(4), 3200),
      ];
      return () => timers.forEach(clearTimeout);
    }
  }, [scene]);

  return (
    <div
      style={{
        width: 390,
        height: 844,
        background: C.bg,
        position: "relative",
        overflow: "hidden",
        fontFamily: '-apple-system, BlinkMacSystemFont, "SF Pro Display", system-ui, sans-serif',
        margin: "0 auto",
      }}
    >
      <FloatingParticles />

      {/* ======================== SCENE 0: INTRO ======================== */}
      {scene === 0 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            padding: "40px 30px",
            zIndex: 10,
          }}
        >
          {/* Gradient glow behind character area */}
          <div
            style={{
              position: "absolute",
              top: "15%",
              left: "50%",
              transform: "translateX(-50%)",
              width: 300,
              height: 300,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${C.accentGlow} 0%, transparent 70%)`,
              filter: "blur(40px)",
            }}
          />

          <FadeSlide show={scene === 0} delay={0} from="scale">
            <div
              style={{
                width: 200,
                height: 340,
                borderRadius: 20,
                background: `linear-gradient(180deg, #1a1a2e 0%, ${C.bg} 100%)`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                border: `1px solid ${C.cardBorder}`,
                marginBottom: 30,
                overflow: "hidden",
                position: "relative",
              }}
            >
              {/* Stylized character silhouette */}
              <svg width="140" height="280" viewBox="0 0 140 280">
                {/* Head */}
                <circle cx="70" cy="45" r="22" fill="#2a2a3e" />
                {/* Body */}
                <rect x="48" y="67" width="44" height="55" rx="8" fill="#1f1f2f" />
                {/* Arms */}
                <rect x="25" y="72" width="23" height="12" rx="6" fill="#1f1f2f" />
                <rect x="92" y="72" width="23" height="12" rx="6" fill="#1f1f2f" />
                {/* Shorts */}
                <rect x="48" y="118" width="20" height="35" rx="4" fill="#161626" />
                <rect x="72" y="118" width="20" height="35" rx="4" fill="#161626" />
                {/* Legs */}
                <rect x="50" y="150" width="16" height="55" rx="6" fill="#2a2a3e" />
                <rect x="74" y="150" width="16" height="55" rx="6" fill="#2a2a3e" />
                {/* Shoes */}
                <ellipse cx="58" cy="210" rx="14" ry="8" fill="#111" />
                <ellipse cx="82" cy="210" rx="14" ry="8" fill="#111" />
                {/* Dumbbell in hands */}
                <rect x="10" y="76" width="18" height="5" rx="2" fill={C.accent} opacity="0.8" />
                <rect x="112" y="76" width="18" height="5" rx="2" fill={C.accent} opacity="0.8" />
              </svg>
            </div>
          </FadeSlide>

          <FadeSlide show={scene === 0} delay={400} from="bottom">
            <h1
              style={{
                fontSize: 38,
                fontWeight: 800,
                color: C.text,
                textAlign: "center",
                margin: 0,
                letterSpacing: -0.5,
                lineHeight: 1.1,
              }}
            >
              Track Every{" "}
              <span
                style={{
                  background: `linear-gradient(135deg, ${C.accent}, ${C.accentLight})`,
                  WebkitBackgroundClip: "text",
                  WebkitTextFillColor: "transparent",
                }}
              >
                Rep.
              </span>
            </h1>
          </FadeSlide>

          <FadeSlide show={scene === 0} delay={800} from="bottom">
            <p style={{ color: C.textMuted, fontSize: 16, textAlign: "center", marginTop: 12 }}>
              The simplest way to log your workouts
            </p>
          </FadeSlide>

          {/* Animated down arrow */}
          <FadeSlide show={scene === 0} delay={1500} from="bottom">
            <div style={{ marginTop: 40, animation: "bounce 2s ease infinite" }}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none">
                <path d="M12 4v16m0 0l-6-6m6 6l6-6" stroke={C.accent} strokeWidth="2" strokeLinecap="round" />
              </svg>
            </div>
          </FadeSlide>

          <style>{`@keyframes bounce { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(10px); } }`}</style>
        </div>
      )}

      {/* ======================== SCENE 1: WORKOUT LOGGING ======================== */}
      {scene === 1 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            padding: "50px 20px 30px",
            zIndex: 10,
          }}
        >
          <FadeSlide show={scene === 1} delay={0} from="top">
            <p style={{ fontSize: 13, color: C.accent, fontWeight: 700, letterSpacing: 2, textTransform: "uppercase", margin: "0 0 8px" }}>
              LIGHTNING FAST
            </p>
          </FadeSlide>

          <FadeSlide show={scene === 1} delay={200} from="bottom">
            <h2 style={{ fontSize: 26, fontWeight: 800, color: C.text, textAlign: "center", margin: "0 0 24px" }}>
              Log Sets in Seconds
            </h2>
          </FadeSlide>

          <FadeSlide show={scene === 1} delay={400} from="bottom">
            <PhoneMockup>
              {/* Exercise title */}
              <div style={{ textAlign: "center", marginBottom: 10 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>Barbell Squat</div>
                <div style={{ fontSize: 10, color: C.textMuted }}>Leg Day</div>
              </div>

              {/* Sets */}
              <SetRow num={1} reps={8} weight={185} checked={setsChecked >= 1} show={scene === 1} delay={700} />
              <SetRow num={2} reps={8} weight={205} checked={setsChecked >= 2} show={scene === 1} delay={900} />
              <SetRow num={3} reps={8} weight={225} checked={setsChecked >= 3} show={scene === 1} delay={1100} />
              <SetRow num={4} reps={6} weight={245} checked={setsChecked >= 4} isNew={setsChecked >= 4} show={scene === 1} delay={1300} />

              {/* Timer */}
              <div style={{ marginTop: 8 }}>
                <TimerBar active={setsChecked >= 1 && setsChecked < 4} progress={timerProgress} />
              </div>

              {/* Quick input bar */}
              <div
                style={{
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  gap: 6,
                  marginTop: 10,
                  padding: "6px",
                  background: C.card,
                  borderRadius: 10,
                  border: `1px solid ${C.cardBorder}`,
                }}
              >
                <div style={{ width: 22, height: 22, borderRadius: "50%", background: C.accent, display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <span style={{ fontSize: 10, color: "#fff" }}>−</span>
                </div>
                <span style={{ fontSize: 14, fontWeight: 700, color: C.accent, fontVariantNumeric: "tabular-nums", width: 24, textAlign: "center" }}>8</span>
                <div style={{ width: 22, height: 22, borderRadius: "50%", background: C.accent, display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <span style={{ fontSize: 10, color: "#fff" }}>+</span>
                </div>
                <div style={{ width: 1, height: 16, background: C.cardBorder, margin: "0 4px" }} />
                <div style={{ width: 22, height: 22, borderRadius: "50%", background: C.accent, display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <span style={{ fontSize: 10, color: "#fff" }}>−</span>
                </div>
                <span style={{ fontSize: 14, fontWeight: 700, color: C.text, fontVariantNumeric: "tabular-nums", width: 32, textAlign: "center" }}>245</span>
                <div style={{ width: 22, height: 22, borderRadius: "50%", background: C.accent, display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <span style={{ fontSize: 10, color: "#fff" }}>+</span>
                </div>
                <div style={{ width: 1, height: 16, background: C.cardBorder, margin: "0 4px" }} />
                <div
                  style={{
                    width: 26,
                    height: 26,
                    borderRadius: "50%",
                    background: C.green,
                    display: "flex",
                    alignItems: "center",
                    justifyContent: "center",
                    boxShadow: `0 0 10px rgba(34,197,94,0.4)`,
                  }}
                >
                  <span style={{ fontSize: 14, color: "#fff" }}>✓</span>
                </div>
              </div>
            </PhoneMockup>
          </FadeSlide>
        </div>
      )}

      {/* ======================== SCENE 2: PR + TIMER ======================== */}
      {scene === 2 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            padding: "50px 20px 30px",
            zIndex: 10,
          }}
        >
          <Confetti active={scene === 2} />

          <FadeSlide show={scene === 2} delay={0} from="top">
            <p style={{ fontSize: 13, color: C.gold, fontWeight: 700, letterSpacing: 2, textTransform: "uppercase", margin: "0 0 8px" }}>
              CELEBRATE WINS
            </p>
          </FadeSlide>

          <FadeSlide show={scene === 2} delay={200} from="bottom">
            <h2 style={{ fontSize: 26, fontWeight: 800, color: C.text, textAlign: "center", margin: "0 0 20px" }}>
              Hit New PRs
            </h2>
          </FadeSlide>

          <FadeSlide show={scene === 2} delay={400} from="bottom">
            <PhoneMockup>
              <div style={{ textAlign: "center", marginBottom: 8 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>Face Pull</div>
              </div>

              <SetRow num={1} reps={15} weight={80} checked={true} show={scene === 2} delay={500} />
              <SetRow num={2} reps={15} weight={80} checked={true} show={scene === 2} delay={600} />
              <SetRow num={3} reps={15} weight={80} checked={true} show={scene === 2} delay={700} />
              <SetRow num={4} reps={15} weight={80} checked={true} show={scene === 2} delay={800} />
              <SetRow num={5} reps={15} weight={95} checked={true} isNew={true} show={scene === 2} delay={900} />

              {/* PR overlay */}
              <div
                style={{
                  position: "absolute",
                  inset: 0,
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  background: "rgba(0,0,0,0.6)",
                  borderRadius: 30,
                  zIndex: 20,
                }}
              >
                <PRBadge show={scene === 2} />
              </div>
            </PhoneMockup>
          </FadeSlide>

          <FadeSlide show={scene === 2} delay={1500} from="bottom">
            <div style={{ marginTop: 20, display: "flex", gap: 10 }}>
              <StatCard label="Day Streak" value="29" icon="🔥" show={scene === 2} delay={1700} />
              <StatCard label="This Week" value="4" icon="📊" show={scene === 2} delay={1900} />
              <StatCard label="Total PRs" value="12" icon="🏆" show={scene === 2} delay={2100} />
            </div>
          </FadeSlide>
        </div>
      )}

      {/* ======================== SCENE 3: PROGRESS ======================== */}
      {scene === 3 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            padding: "50px 20px 30px",
            zIndex: 10,
          }}
        >
          <FadeSlide show={scene === 3} delay={0} from="top">
            <p style={{ fontSize: 13, color: C.green, fontWeight: 700, letterSpacing: 2, textTransform: "uppercase", margin: "0 0 8px" }}>
              SEE RESULTS
            </p>
          </FadeSlide>

          <FadeSlide show={scene === 3} delay={200} from="bottom">
            <h2 style={{ fontSize: 26, fontWeight: 800, color: C.text, textAlign: "center", margin: "0 0 24px" }}>
              Track Your Progress
            </h2>
          </FadeSlide>

          <FadeSlide show={scene === 3} delay={400} from="bottom">
            <PhoneMockup>
              <div style={{ textAlign: "center", marginBottom: 12 }}>
                <div style={{ fontSize: 14, fontWeight: 700, color: C.text }}>Face Pull</div>
                <div style={{ fontSize: 10, color: C.textMuted }}>Progress Overview</div>
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6, marginBottom: 10 }}>
                <FadeSlide show={scene === 3} delay={700} from="left">
                  <div style={{ background: C.card, borderRadius: 10, padding: "8px 10px", border: `1px solid ${C.cardBorder}` }}>
                    <div style={{ fontSize: 9, color: C.accent }}>● Max Weight</div>
                    <div style={{ fontSize: 22, fontWeight: 800, color: C.text }}>95 <span style={{ fontSize: 11, color: C.textMuted }}>lbs</span></div>
                  </div>
                </FadeSlide>
                <FadeSlide show={scene === 3} delay={800} from="right">
                  <div style={{ background: C.card, borderRadius: 10, padding: "8px 10px", border: `1px solid ${C.cardBorder}` }}>
                    <div style={{ fontSize: 9, color: C.textMuted }}>Est. 1RM</div>
                    <div style={{ fontSize: 22, fontWeight: 800, color: C.text }}>142 <span style={{ fontSize: 11, color: C.textMuted }}>lbs</span></div>
                  </div>
                </FadeSlide>
              </div>

              <MiniChart show={scene === 3} />

              <FadeSlide show={scene === 3} delay={1200} from="bottom">
                <div style={{ marginTop: 10, background: C.card, borderRadius: 10, padding: "8px 10px", border: `1px solid ${C.cardBorder}` }}>
                  <div style={{ fontSize: 10, color: C.textMuted, marginBottom: 4 }}>Recent Sessions</div>
                  {["Today — 5×15 @ 95 lbs", "3 days ago — 4×12 @ 80 lbs", "1 week ago — 4×10 @ 70 lbs"].map((s, i) => (
                    <div key={i} style={{ fontSize: 11, color: C.text, padding: "3px 0", borderBottom: i < 2 ? `1px solid ${C.cardBorder}` : "none" }}>
                      {s}
                    </div>
                  ))}
                </div>
              </FadeSlide>
            </PhoneMockup>
          </FadeSlide>
        </div>
      )}

      {/* ======================== SCENE 4: OUTRO / CTA ======================== */}
      {scene === 4 && (
        <div
          style={{
            position: "absolute",
            inset: 0,
            display: "flex",
            flexDirection: "column",
            alignItems: "center",
            justifyContent: "center",
            padding: "40px 30px",
            zIndex: 10,
          }}
        >
          {/* Glow */}
          <div
            style={{
              position: "absolute",
              top: "35%",
              left: "50%",
              transform: "translate(-50%, -50%)",
              width: 250,
              height: 250,
              borderRadius: "50%",
              background: `radial-gradient(circle, ${C.accentGlow} 0%, transparent 70%)`,
              filter: "blur(50px)",
              animation: "pulse 3s ease infinite",
            }}
          />

          <FadeSlide show={scene === 4} delay={0} from="scale">
            <AppIcon size={100} />
          </FadeSlide>

          <FadeSlide show={scene === 4} delay={400} from="bottom">
            <h1 style={{ fontSize: 36, fontWeight: 800, margin: "24px 0 0", letterSpacing: -0.5 }}>
              <span style={{ color: C.textMuted }}>THE</span>
              <span style={{ color: C.accent }}>LOGGER</span>
            </h1>
          </FadeSlide>

          <FadeSlide show={scene === 4} delay={800} from="bottom">
            <p style={{ color: C.textMuted, fontSize: 16, margin: "8px 0 0", letterSpacing: 3, textTransform: "uppercase" }}>
              Simple · Fast · Private
            </p>
          </FadeSlide>

          <FadeSlide show={scene === 4} delay={1400} from="bottom">
            <div
              style={{
                marginTop: 40,
                padding: "14px 40px",
                background: `linear-gradient(135deg, ${C.accent}, ${C.accentLight})`,
                borderRadius: 14,
                fontSize: 16,
                fontWeight: 700,
                color: "#fff",
                boxShadow: `0 8px 30px ${C.accentGlow}`,
                letterSpacing: 0.5,
              }}
            >
              Download Free
            </div>
          </FadeSlide>

          <FadeSlide show={scene === 4} delay={1800} from="bottom">
            <div style={{ display: "flex", alignItems: "center", gap: 6, marginTop: 16 }}>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83" fill="#999" />
                <path d="M15.5 1c.12 1.22-.34 2.44-1.15 3.31-.81.88-2.12 1.56-3.42 1.47-.14-1.18.43-2.42 1.2-3.2C12.91 1.77 14.28 1.1 15.5 1" fill="#999" />
              </svg>
              <span style={{ fontSize: 12, color: C.textMuted }}>Available on the App Store</span>
            </div>
          </FadeSlide>

          <style>{`@keyframes pulse { 0%, 100% { opacity: 0.6; } 50% { opacity: 1; } }`}</style>
        </div>
      )}

      {/* ======================== SCENE INDICATOR ======================== */}
      <div
        style={{
          position: "absolute",
          bottom: 20,
          left: "50%",
          transform: "translateX(-50%)",
          display: "flex",
          gap: 6,
          zIndex: 100,
        }}
      >
        {Array.from({ length: TOTAL_SCENES }, (_, i) => (
          <div
            key={i}
            style={{
              width: scene === i ? 20 : 6,
              height: 6,
              borderRadius: 3,
              background: scene === i ? C.accent : C.cardBorder,
              transition: "all 300ms ease",
            }}
          />
        ))}
      </div>
    </div>
  );
}