import React, { useState } from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { shadows } from '../../tokens/shadows';
import { gradients } from '../../tokens/gradients';

// ── Shadow Card ───────────────────────────────────────────────────────────────

interface ShadowCardProps {
  name: string;
  value: string;
  description: string;
  isGlow?: boolean;
  glowColor?: string;
}

function ShadowCard({ name, value, description, isGlow = false, glowColor }: ShadowCardProps) {
  const [copied, setCopied] = useState(false);

  const handleCopy = () => {
    navigator.clipboard.writeText(value).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    });
  };

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      gap: 20,
    }}>
      {/* Demo box */}
      <div style={{
        background: '#1A1A1A',
        borderRadius: 12,
        padding: '32px 24px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        minHeight: 140,
        border: '1px solid #252525',
      }}>
        <div style={{
          width: isGlow ? 80 : 120,
          height: isGlow ? 80 : 64,
          background: isGlow
            ? (glowColor === 'purple' ? '#6b34fa' : '#fd7f20')
            : '#252525',
          borderRadius: isGlow ? 9999 : 8,
          boxShadow: value,
          border: isGlow ? 'none' : '1px solid #333',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}>
          {isGlow && (
            <span style={{
              fontFamily: "'Maven Pro', sans-serif",
              fontSize: 20,
              fontWeight: 700,
              color: '#FFFFFF',
            }}>✦</span>
          )}
        </div>
      </div>

      {/* Info */}
      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 8 }}>
          <h3 style={{
            fontFamily: "'Maven Pro', sans-serif",
            fontSize: 15,
            fontWeight: 700,
            color: '#FFFFFF',
            margin: 0,
          }}>{name}</h3>
          <button
            onClick={handleCopy}
            style={{
              background: copied ? '#6b34fa' : '#252525',
              border: 'none',
              borderRadius: 6,
              padding: '4px 10px',
              fontFamily: "'DM Sans', sans-serif",
              fontSize: 11,
              fontWeight: 600,
              color: '#FFFFFF',
              cursor: 'pointer',
              transition: 'background 0.2s ease',
              flexShrink: 0,
            }}
          >
            {copied ? 'Copied!' : 'Copy CSS'}
          </button>
        </div>

        <code style={{
          display: 'block',
          fontFamily: 'monospace',
          fontSize: 11,
          color: '#fd7f20',
          background: '#111',
          padding: '8px 12px',
          borderRadius: 6,
          marginBottom: 10,
          wordBreak: 'break-all',
          lineHeight: 1.6,
        }}>{value}</code>

        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 13,
          color: '#666666',
          margin: 0,
          lineHeight: 1.5,
        }}>{description}</p>
      </div>
    </div>
  );
}

// ── Gradient Strip ────────────────────────────────────────────────────────────

interface GradientStripProps {
  name: string;
  css: string;
  description: string;
}

function GradientStrip({ name, css, description }: GradientStripProps) {
  const [copied, setCopied] = useState(false);

  return (
    <div style={{
      background: '#1A1A1A',
      borderRadius: 12,
      overflow: 'hidden',
      border: '1px solid #252525',
    }}>
      {/* Gradient preview */}
      <div style={{
        height: 80,
        background: css,
      }} />

      {/* Info */}
      <div style={{ padding: '16px 20px 20px' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 8,
        }}>
          <h3 style={{
            fontFamily: "'Maven Pro', sans-serif",
            fontSize: 15,
            fontWeight: 700,
            color: '#FFFFFF',
            margin: 0,
          }}>{name}</h3>
          <button
            onClick={() => {
              navigator.clipboard.writeText(css).then(() => {
                setCopied(true);
                setTimeout(() => setCopied(false), 1500);
              });
            }}
            style={{
              background: copied ? '#6b34fa' : '#252525',
              border: 'none',
              borderRadius: 6,
              padding: '4px 10px',
              fontFamily: "'DM Sans', sans-serif",
              fontSize: 11,
              fontWeight: 600,
              color: '#FFFFFF',
              cursor: 'pointer',
              transition: 'background 0.2s ease',
            }}
          >
            {copied ? 'Copied!' : 'Copy CSS'}
          </button>
        </div>

        <code style={{
          display: 'block',
          fontFamily: 'monospace',
          fontSize: 11,
          color: '#fd7f20',
          background: '#111',
          padding: '8px 12px',
          borderRadius: 6,
          marginBottom: 10,
          wordBreak: 'break-all',
          lineHeight: 1.6,
        }}>{css}</code>

        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 13,
          color: '#666666',
          margin: 0,
          lineHeight: 1.5,
        }}>{description}</p>
      </div>
    </div>
  );
}

// ── Elevation Ladder ──────────────────────────────────────────────────────────

function ElevationLadder() {
  const levels = [
    { label: 'Level 0 — Base', shadow: 'none', bg: '#0D0D0D', description: 'Page canvas, no elevation.' },
    { label: 'Level 1 — Subtle', shadow: shadows.sm.value, bg: '#1A1A1A', description: 'Close-to-surface cards.' },
    { label: 'Level 2 — Raised', shadow: shadows.md.value, bg: '#1A1A1A', description: 'Standard cards, dropdowns.' },
    { label: 'Level 3 — Float', shadow: shadows.lg.value, bg: '#1A1A1A', description: 'Modals, overlays.' },
  ];

  return (
    <div style={{
      background: '#111',
      borderRadius: 12,
      padding: '32px',
      border: '1px solid #1A1A1A',
      display: 'flex',
      flexDirection: 'column',
      gap: 20,
    }}>
      {levels.map((level, i) => (
        <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 24 }}>
          {/* Elevated chip */}
          <div style={{
            width: 140,
            height: 56,
            background: level.bg,
            borderRadius: 8,
            boxShadow: level.shadow,
            border: '1px solid #252525',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}>
            <span style={{
              fontFamily: "'DM Sans', sans-serif",
              fontSize: 12,
              color: '#A0A0A0',
            }}>elevation {i}</span>
          </div>

          {/* Label */}
          <div>
            <div style={{ fontFamily: "'Maven Pro', sans-serif", fontSize: 13, fontWeight: 600, color: '#FFFFFF', marginBottom: 4 }}>
              {level.label}
            </div>
            <div style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: '#666' }}>
              {level.description}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}

// ── Full View ─────────────────────────────────────────────────────────────────

function ShadowsView() {
  return (
    <div style={{
      background: '#0D0D0D',
      minHeight: '100vh',
      padding: '48px 40px',
      boxSizing: 'border-box',
    }}>
      {/* Header */}
      <div style={{ marginBottom: 48 }}>
        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 12,
          fontWeight: 600,
          color: '#6b34fa',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 8px',
        }}>Foundations</p>
        <h1 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 28,
          fontWeight: 700,
          color: '#FFFFFF',
          margin: '0 0 12px',
          letterSpacing: '-0.015em',
        }}>Shadows & Gradients</h1>
        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 15,
          color: '#A0A0A0',
          margin: 0,
          maxWidth: 560,
          lineHeight: 1.6,
        }}>Elevation shadows for depth, brand glows for emphasis, gradients for richness. Click any card to copy the CSS.</p>
      </div>

      {/* Elevation Shadows */}
      <section style={{ marginBottom: 64 }}>
        <h2 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 24px',
        }}>Elevation Shadows</h2>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 24, marginBottom: 32 }}>
          <ShadowCard {...shadows.sm} />
          <ShadowCard {...shadows.md} />
          <ShadowCard {...shadows.lg} />
        </div>

        <ElevationLadder />
      </section>

      {/* Glow Effects */}
      <section style={{ marginBottom: 64 }}>
        <h2 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 24px',
        }}>Brand Glows</h2>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 24 }}>
          <ShadowCard {...shadows.glowPurple} isGlow glowColor="purple" />
          <ShadowCard {...shadows.glowGold} isGlow glowColor="gold" />
        </div>
      </section>

      {/* Gradients */}
      <section>
        <h2 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 24px',
        }}>Gradients</h2>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 20 }}>
          <GradientStrip {...gradients.brandGlow} />
          <GradientStrip {...gradients.goldAccent} />
          <GradientStrip {...gradients.cardShimmer} />
          <GradientStrip {...gradients.heroOverlay} />
        </div>
      </section>
    </div>
  );
}

// ── Storybook meta ────────────────────────────────────────────────────────────

const meta = {
  title: 'Foundations/Shadows',
  parameters: {
    layout: 'fullscreen',
    docs: { description: { component: 'Kharis elevation shadows, brand glows, and gradient palette. Click any card to copy CSS.' } },
  },
} satisfies Meta;

export default meta;
type Story = StoryObj<typeof meta>;

export const ShadowsAndGradients: Story = {
  name: 'Shadows & Gradients',
  render: () => <ShadowsView />,
};
