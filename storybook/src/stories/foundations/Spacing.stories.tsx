import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { spacingScale, radiiScale } from '../../tokens/spacing';

// ── Spacing Bar ───────────────────────────────────────────────────────────────

function SpacingBar({ token }: { token: typeof spacingScale[number] }) {
  return (
    <div style={{
      display: 'grid',
      gridTemplateColumns: '100px 1fr 60px 240px',
      alignItems: 'center',
      gap: 16,
      padding: '10px 0',
      borderBottom: '1px solid #1A1A1A',
    }}>
      {/* Name */}
      <span style={{
        fontFamily: 'monospace',
        fontSize: 12,
        color: '#A0A0A0',
      }}>{token.name}</span>

      {/* Bar */}
      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
        <div style={{
          height: 8,
          width: token.value,
          background: 'linear-gradient(90deg, #6b34fa, #800654)',
          borderRadius: 9999,
          flexShrink: 0,
        }} />
      </div>

      {/* Value */}
      <span style={{
        fontFamily: 'monospace',
        fontSize: 12,
        color: '#fd7f20',
        textAlign: 'right',
      }}>{token.value}px</span>

      {/* Usage */}
      <span style={{
        fontFamily: "'DM Sans', sans-serif",
        fontSize: 12,
        color: '#666666',
        lineHeight: 1.4,
      }}>{token.usage}</span>
    </div>
  );
}

// ── Radii Card ────────────────────────────────────────────────────────────────

function RadiusCard({ token }: { token: typeof radiiScale[number] }) {
  const displayRadius = Math.min(token.value, 24); // cap visual to 24 for pill

  return (
    <div style={{
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 16,
    }}>
      {/* Shape demo */}
      <div style={{
        width: 80,
        height: 80,
        background: 'linear-gradient(135deg, #6b34fa 0%, #800654 100%)',
        borderRadius: token.value >= 9999 ? 9999 : displayRadius,
        boxShadow: '0 4px 12px rgba(107,52,250,0.25)',
      }} />

      {/* Info */}
      <div style={{ textAlign: 'center' }}>
        <div style={{
          fontFamily: 'monospace',
          fontSize: 11,
          color: '#fd7f20',
          marginBottom: 2,
        }}>{token.css}</div>
        <div style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 600,
          color: '#FFFFFF',
          marginBottom: 4,
        }}>{token.name}</div>
        <div style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 11,
          color: '#666666',
          maxWidth: 100,
          lineHeight: 1.4,
          textAlign: 'center',
        }}>{token.usage}</div>
      </div>
    </div>
  );
}

// ── Grid Guide ────────────────────────────────────────────────────────────────

function GridGuide() {
  const gutterTokens = [16, 24, 32];
  const columns = 12;

  return (
    <div>
      <h3 style={{
        fontFamily: "'Maven Pro', sans-serif",
        fontSize: 12,
        fontWeight: 700,
        color: '#A0A0A0',
        letterSpacing: '0.1em',
        textTransform: 'uppercase',
        margin: '0 0 20px',
      }}>Layout Grid</h3>

      {gutterTokens.map(gutter => (
        <div key={gutter} style={{ marginBottom: 24 }}>
          <div style={{
            fontFamily: "'DM Sans', sans-serif",
            fontSize: 12,
            color: '#666666',
            marginBottom: 8,
          }}>
            {columns}-column grid · {gutter}px gutter
          </div>
          <div style={{
            display: 'grid',
            gridTemplateColumns: `repeat(${columns}, 1fr)`,
            gap: gutter,
            height: 40,
          }}>
            {Array.from({ length: columns }).map((_, i) => (
              <div key={i} style={{
                background: i % 2 === 0 ? 'rgba(107,52,250,0.2)' : 'rgba(107,52,250,0.1)',
                borderRadius: 4,
                border: '1px solid rgba(107,52,250,0.3)',
              }} />
            ))}
          </div>
        </div>
      ))}

      {/* Common layout widths */}
      <div style={{ marginTop: 32 }}>
        <h4 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 16px',
        }}>Content Widths</h4>
        {[
          { name: 'Narrow', width: 480, usage: 'Auth forms, modals, focused flows' },
          { name: 'Text', width: 640, usage: 'Body copy, articles, blog posts' },
          { name: 'Default', width: 768, usage: 'Default content container' },
          { name: 'Wide', width: 1024, usage: 'Full-width sections, tables' },
          { name: 'Full', width: '100%', usage: 'Edge-to-edge, hero sections' },
        ].map(({ name, width, usage }) => (
          <div key={name} style={{
            display: 'flex',
            alignItems: 'center',
            gap: 16,
            marginBottom: 12,
          }}>
            <span style={{ fontFamily: "'Maven Pro', sans-serif", fontSize: 13, fontWeight: 600, color: '#FFFFFF', width: 64 }}>{name}</span>
            <div style={{ flex: 1, position: 'relative', height: 24, background: '#1A1A1A', borderRadius: 4, overflow: 'hidden' }}>
              <div style={{
                position: 'absolute',
                left: 0,
                top: 0,
                bottom: 0,
                width: typeof width === 'string' ? '100%' : `${Math.min(100, (width as number) / 1024 * 100)}%`,
                background: 'linear-gradient(90deg, rgba(107,52,250,0.4), rgba(107,52,250,0.15))',
                borderRight: '2px solid #6b34fa',
              }} />
            </div>
            <span style={{ fontFamily: 'monospace', fontSize: 11, color: '#fd7f20', width: 50, textAlign: 'right' }}>
              {typeof width === 'string' ? width : `${width}px`}
            </span>
            <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: '#666', width: 220 }}>{usage}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Full View ─────────────────────────────────────────────────────────────────

function SpacingView() {
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
        }}>Spacing & Layout</h1>
        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 15,
          color: '#A0A0A0',
          margin: 0,
          maxWidth: 560,
          lineHeight: 1.6,
        }}>4px base unit. All spacing values are multiples of this grid.</p>
      </div>

      {/* Spacing Scale */}
      <section style={{ marginBottom: 64 }}>
        <h2 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 24px',
        }}>Spacing Scale</h2>

        {/* Column headers */}
        <div style={{
          display: 'grid',
          gridTemplateColumns: '100px 1fr 60px 240px',
          gap: 16,
          padding: '0 0 8px',
          borderBottom: '1px solid #252525',
          marginBottom: 4,
        }}>
          {['Token', 'Visual', 'Value', 'Usage'].map(h => (
            <span key={h} style={{
              fontFamily: "'DM Sans', sans-serif",
              fontSize: 10,
              fontWeight: 700,
              color: '#666',
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              textAlign: h === 'Value' ? 'right' : 'left',
            }}>{h}</span>
          ))}
        </div>

        {spacingScale.map(token => <SpacingBar key={token.name} token={token} />)}
      </section>

      {/* Border Radius Scale */}
      <section style={{ marginBottom: 64 }}>
        <h2 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 24px',
        }}>Border Radius</h2>

        <div style={{
          display: 'flex',
          flexWrap: 'wrap',
          gap: 40,
          background: '#111111',
          borderRadius: 12,
          padding: '32px 40px',
          border: '1px solid #1A1A1A',
        }}>
          {radiiScale.map(token => <RadiusCard key={token.name} token={token} />)}
        </div>
      </section>

      {/* Grid Guide */}
      <section>
        <GridGuide />
      </section>
    </div>
  );
}

// ── Storybook meta ────────────────────────────────────────────────────────────

const meta = {
  title: 'Foundations/Spacing',
  parameters: {
    layout: 'fullscreen',
    docs: { description: { component: 'Kharis spacing system — 4px base grid, 11-step scale, border radii, and layout widths.' } },
  },
} satisfies Meta;

export default meta;
type Story = StoryObj<typeof meta>;

export const Scale: Story = {
  name: 'Spacing & Radii',
  render: () => <SpacingView />,
};
