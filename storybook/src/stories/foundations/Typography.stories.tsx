import React, { useState } from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { fontFamilies, typeScale, type TypeScaleEntry } from '../../tokens/typography';

const SAMPLE_SHORT = 'The quick brown fox jumps over the lazy dog';
const SAMPLE_LONG = 'Kharis — where grace meets community. Our design language carries the weight of something eternal.';

// ── Type Scale Row ────────────────────────────────────────────────────────────

interface ScaleRowProps {
  entry: TypeScaleEntry;
  selected: boolean;
  onSelect: () => void;
}

function ScaleRow({ entry, selected, onSelect }: ScaleRowProps) {
  const fontStack = entry.font === 'heading' ? "'Maven Pro', sans-serif" : "'DM Sans', sans-serif";

  return (
    <div
      onClick={onSelect}
      style={{
        display: 'grid',
        gridTemplateColumns: '1fr auto',
        alignItems: 'center',
        gap: 24,
        padding: '20px 24px',
        borderRadius: 8,
        cursor: 'pointer',
        background: selected ? '#1A1A1A' : 'transparent',
        border: `1px solid ${selected ? '#6b34fa' : 'transparent'}`,
        transition: 'background 0.15s ease, border-color 0.15s ease',
        marginBottom: 4,
      }}
      onMouseEnter={e => {
        if (!selected) (e.currentTarget as HTMLDivElement).style.background = '#141414';
      }}
      onMouseLeave={e => {
        if (!selected) (e.currentTarget as HTMLDivElement).style.background = 'transparent';
      }}
    >
      {/* Sample text */}
      <span style={{
        fontFamily: fontStack,
        fontSize: entry.size,
        fontWeight: entry.weight,
        lineHeight: entry.lineHeight,
        letterSpacing: entry.letterSpacing,
        color: '#FFFFFF',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        whiteSpace: 'nowrap',
      }}>
        {entry.name}
      </span>

      {/* Compact spec tag */}
      <span style={{
        fontFamily: "'DM Sans', sans-serif",
        fontSize: 11,
        color: '#666666',
        whiteSpace: 'nowrap',
        letterSpacing: '0.03em',
      }}>
        {entry.size}px / {entry.weight} / {entry.lineHeight}lh
      </span>
    </div>
  );
}

// ── Spec Panel ────────────────────────────────────────────────────────────────

function SpecRow({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderBottom: '1px solid #252525' }}>
      <span style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: '#666666' }}>{label}</span>
      <span style={{ fontFamily: 'monospace', fontSize: 12, color: '#A0A0A0' }}>{value}</span>
    </div>
  );
}

interface SpecPanelProps {
  entry: TypeScaleEntry;
}

function SpecPanel({ entry }: SpecPanelProps) {
  const fontName = entry.font === 'heading' ? fontFamilies.heading.name : fontFamilies.body.name;
  const fontStack = entry.font === 'heading' ? "'Maven Pro', sans-serif" : "'DM Sans', sans-serif";

  return (
    <div style={{
      background: '#1A1A1A',
      borderRadius: 12,
      padding: '24px',
      border: '1px solid #252525',
      position: 'sticky',
      top: 24,
    }}>
      <div style={{ marginBottom: 20 }}>
        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 10,
          fontWeight: 700,
          color: '#6b34fa',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: '0 0 6px',
        }}>Selected Style</p>
        <h3 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 20,
          fontWeight: 700,
          color: '#FFFFFF',
          margin: 0,
        }}>{entry.name}</h3>
      </div>

      {/* Live preview */}
      <div style={{
        background: '#252525',
        borderRadius: 8,
        padding: '16px',
        marginBottom: 20,
      }}>
        <p style={{
          fontFamily: fontStack,
          fontSize: entry.size,
          fontWeight: entry.weight,
          lineHeight: entry.lineHeight,
          letterSpacing: entry.letterSpacing,
          color: '#FFFFFF',
          margin: 0,
          wordBreak: 'break-word',
        }}>Aa</p>
      </div>

      <SpecRow label="Font Family" value={fontName} />
      <SpecRow label="Size" value={`${entry.size}px`} />
      <SpecRow label="Weight" value={String(entry.weight)} />
      <SpecRow label="Line Height" value={String(entry.lineHeight)} />
      <SpecRow label="Letter Spacing" value={entry.letterSpacing} />

      <div style={{ marginTop: 20 }}>
        <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 11, color: '#666', margin: '0 0 6px' }}>Usage</p>
        <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 13, color: '#A0A0A0', margin: 0, lineHeight: 1.5 }}>
          {entry.usage}
        </p>
      </div>
    </div>
  );
}

// ── Font Families Section ─────────────────────────────────────────────────────

function FontFamiliesSection() {
  const families = [
    { ...fontFamilies.heading, role: 'Heading', stack: "'Maven Pro', sans-serif" },
    { ...fontFamilies.body, role: 'Body', stack: "'DM Sans', sans-serif" },
  ];

  return (
    <div style={{ marginBottom: 64 }}>
      <h2 style={{
        fontFamily: "'Maven Pro', sans-serif",
        fontSize: 12,
        fontWeight: 700,
        color: '#A0A0A0',
        letterSpacing: '0.1em',
        textTransform: 'uppercase',
        margin: '0 0 20px',
      }}>Font Families</h2>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
        {families.map(f => (
          <div key={f.name} style={{
            background: '#1A1A1A',
            borderRadius: 12,
            padding: 24,
            border: '1px solid #252525',
          }}>
            <div style={{ marginBottom: 16 }}>
              <span style={{
                fontFamily: "'DM Sans', sans-serif",
                fontSize: 11,
                fontWeight: 600,
                color: '#6b34fa',
                letterSpacing: '0.08em',
                textTransform: 'uppercase',
              }}>{f.role}</span>
              <h3 style={{
                fontFamily: "'Maven Pro', sans-serif",
                fontSize: 18,
                fontWeight: 700,
                color: '#FFFFFF',
                margin: '4px 0 2px',
              }}>{f.name}</h3>
              <p style={{ fontFamily: "'DM Sans', sans-serif", fontSize: 12, color: '#666', margin: 0 }}>
                {f.source} · Weights: {f.weights.join(', ')}
              </p>
            </div>

            <div style={{ borderTop: '1px solid #252525', paddingTop: 16 }}>
              {[400, 600, 800].filter(w => f.weights.includes(w)).map(w => (
                <p key={w} style={{
                  fontFamily: f.stack,
                  fontSize: 15,
                  fontWeight: w,
                  color: '#FFFFFF',
                  margin: '0 0 8px',
                  lineHeight: 1.5,
                }}>{SAMPLE_SHORT}</p>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Full View ─────────────────────────────────────────────────────────────────

function TypeScaleView() {
  const [selected, setSelected] = useState<number>(0);
  const activeEntry = typeScale[selected];

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
        }}>Typography</h1>
        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 15,
          color: '#A0A0A0',
          margin: 0,
          maxWidth: 560,
          lineHeight: 1.6,
        }}>Click a style to inspect its specifications.</p>
      </div>

      <FontFamiliesSection />

      {/* Type Scale */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 280px', gap: 32, alignItems: 'start' }}>
        <div>
          <h2 style={{
            fontFamily: "'Maven Pro', sans-serif",
            fontSize: 12,
            fontWeight: 700,
            color: '#A0A0A0',
            letterSpacing: '0.1em',
            textTransform: 'uppercase',
            margin: '0 0 20px',
          }}>Type Scale</h2>

          <div style={{ borderRadius: 12, border: '1px solid #252525', overflow: 'hidden', padding: '8px' }}>
            {typeScale.map((entry, i) => (
              <ScaleRow
                key={entry.name}
                entry={entry}
                selected={selected === i}
                onSelect={() => setSelected(i)}
              />
            ))}
          </div>

          {/* Sample paragraph */}
          <div style={{
            marginTop: 32,
            background: '#1A1A1A',
            borderRadius: 12,
            padding: 24,
            border: '1px solid #252525',
          }}>
            <p style={{
              fontFamily: "'DM Sans', sans-serif",
              fontSize: 11,
              fontWeight: 600,
              color: '#6b34fa',
              letterSpacing: '0.08em',
              textTransform: 'uppercase',
              margin: '0 0 16px',
            }}>Sample Paragraph</p>
            <h2 style={{
              fontFamily: "'Maven Pro', sans-serif",
              fontSize: 22,
              fontWeight: 700,
              color: '#FFFFFF',
              margin: '0 0 8px',
              letterSpacing: '-0.01em',
            }}>{SAMPLE_LONG}</h2>
            <p style={{
              fontFamily: "'DM Sans', sans-serif",
              fontSize: 16,
              fontWeight: 400,
              color: '#A0A0A0',
              margin: 0,
              lineHeight: 1.6,
            }}>
              We believe in the power of gathered community — sharing, worshipping, and growing together.
              Join us every Sunday as we pursue purpose with intention.
            </p>
          </div>
        </div>

        <SpecPanel entry={activeEntry} />
      </div>
    </div>
  );
}

// ── Storybook meta ────────────────────────────────────────────────────────────

const meta = {
  title: 'Foundations/Typography',
  parameters: {
    layout: 'fullscreen',
    docs: { description: { component: 'Kharis type system. Two families, seven scale steps. Click a style to see specs.' } },
  },
} satisfies Meta;

export default meta;
type Story = StoryObj<typeof meta>;

export const TypeScale: Story = {
  name: 'Type Scale',
  render: () => <TypeScaleView />,
};
