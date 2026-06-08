import React, { useState } from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { theme, type ColorToken } from '../../tokens/colors';

/** Convert theme group entries to ColorToken array for SwatchGroup. */
function themeToTokens(
  group: Record<string, { hex: string; rgb: string }>,
  descriptions?: Record<string, string>,
  skip?: string[],
): ColorToken[] {
  return Object.entries(group)
    .filter(([key]) => !skip?.includes(key))
    .map(([key, val]) => ({
      name: key.replace(/([A-Z])/g, ' $1').replace(/^./, s => s.toUpperCase()),
      hex: val.hex,
      rgb: val.rgb,
      description: descriptions?.[key] ?? '',
    }));
}

// ── WCAG helpers ────────────────────────────────────────────────────────────

function hexToRgb(hex: string): [number, number, number] {
  const h = hex.replace('#', '');
  const n = parseInt(h, 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

function srgbLinear(c: number): number {
  const s = c / 255;
  return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
}

function relativeLuminance(hex: string): number {
  const [r, g, b] = hexToRgb(hex).map(srgbLinear);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

function contrastRatio(hex1: string, hex2: string): number {
  const l1 = relativeLuminance(hex1);
  const l2 = relativeLuminance(hex2);
  const lighter = Math.max(l1, l2);
  const darker = Math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

function wcagLabel(ratio: number): { label: string; color: string } {
  if (ratio >= 7) return { label: 'AAA', color: '#22C55E' };
  if (ratio >= 4.5) return { label: 'AA', color: '#86efac' };
  if (ratio >= 3) return { label: 'AA Large', color: '#F59E0B' };
  return { label: 'Fail', color: '#EF4444' };
}

// ── Swatch Component ─────────────────────────────────────────────────────────

interface SwatchProps {
  token: ColorToken;
  showContrast?: boolean;
}

function Swatch({ token, showContrast = false }: SwatchProps) {
  const [copied, setCopied] = useState(false);

  const handleClick = () => {
    navigator.clipboard.writeText(token.hex).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    });
  };

  const ratio = contrastRatio('#FFFFFF', token.hex);
  const { label, color: wcagColor } = wcagLabel(ratio);

  return (
    <div
      onClick={handleClick}
      style={{
        cursor: 'pointer',
        borderRadius: 8,
        overflow: 'hidden',
        background: '#1A1A1A',
        border: '1px solid #252525',
        transition: 'transform 0.15s ease, box-shadow 0.15s ease',
        userSelect: 'none',
      }}
      onMouseEnter={e => {
        (e.currentTarget as HTMLDivElement).style.transform = 'translateY(-2px)';
        (e.currentTarget as HTMLDivElement).style.boxShadow = '0 8px 24px rgba(0,0,0,0.5)';
      }}
      onMouseLeave={e => {
        (e.currentTarget as HTMLDivElement).style.transform = 'translateY(0)';
        (e.currentTarget as HTMLDivElement).style.boxShadow = 'none';
      }}
    >
      {/* Color rectangle */}
      <div
        style={{
          height: 80,
          background: token.hex,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {copied && (
          <span style={{
            fontSize: 12,
            fontFamily: "'DM Sans', sans-serif",
            fontWeight: 600,
            color: '#fff',
            background: 'rgba(0,0,0,0.7)',
            padding: '4px 10px',
            borderRadius: 9999,
          }}>Copied!</span>
        )}
      </div>

      {/* Token info */}
      <div style={{ padding: '12px 14px 14px' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 4,
        }}>
          <span style={{
            fontFamily: "'Maven Pro', sans-serif",
            fontWeight: 600,
            fontSize: 13,
            color: '#FFFFFF',
          }}>{token.name}</span>

          {showContrast && (
            <span style={{
              fontSize: 10,
              fontFamily: "'DM Sans', sans-serif",
              fontWeight: 700,
              color: wcagColor,
              background: 'rgba(255,255,255,0.06)',
              padding: '2px 6px',
              borderRadius: 4,
              letterSpacing: '0.04em',
            }}>{label} {ratio.toFixed(1)}:1</span>
          )}
        </div>

        <div style={{
          fontFamily: 'monospace',
          fontSize: 12,
          color: '#A0A0A0',
          marginBottom: 6,
          letterSpacing: '0.04em',
        }}>{token.hex.toUpperCase()}</div>

        <div style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 12,
          color: '#666666',
          lineHeight: 1.4,
        }}>{token.description}</div>
      </div>
    </div>
  );
}

// ── Group Section ────────────────────────────────────────────────────────────

interface GroupProps {
  title: string;
  tokens: ColorToken[];
  showContrast?: boolean;
}

function SwatchGroup({ title, tokens, showContrast }: GroupProps) {
  return (
    <div style={{ marginBottom: 48 }}>
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 12,
        marginBottom: 20,
      }}>
        <h2 style={{
          fontFamily: "'Maven Pro', sans-serif",
          fontSize: 12,
          fontWeight: 700,
          color: '#A0A0A0',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
          margin: 0,
        }}>{title}</h2>
        <div style={{ flex: 1, height: 1, background: '#252525' }} />
        {showContrast && (
          <span style={{
            fontSize: 11,
            fontFamily: "'DM Sans', sans-serif",
            color: '#666666',
          }}>WCAG vs #FFFFFF</span>
        )}
      </div>
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
        gap: 12,
      }}>
        {tokens.map(token => (
          <Swatch key={token.hex} token={token} showContrast={showContrast} />
        ))}
      </div>
    </div>
  );
}

// ── Story render ─────────────────────────────────────────────────────────────

function ColorPaletteView() {
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
        }}>Color Palette</h1>
        <p style={{
          fontFamily: "'DM Sans', sans-serif",
          fontSize: 15,
          color: '#A0A0A0',
          margin: 0,
          maxWidth: 560,
          lineHeight: 1.6,
        }}>
          Click any swatch to copy its hex value. WCAG contrast ratios are shown against white (#FFFFFF) on surface colors.
        </p>
      </div>

      <SwatchGroup
        title="Brand"
        tokens={themeToTokens(theme.brand, {
          orange: 'Primary CTA. Every button on kharis.org.',
          purple: 'Identity. Logo, social icons. Not for buttons.',
          magenta: 'Feature icons (50px icon-boxes).',
        }, ['gold'])}
      />
      <SwatchGroup
        title="Surface"
        tokens={themeToTokens(theme.surface)}
        showContrast
      />
      <SwatchGroup
        title="Text"
        tokens={themeToTokens(theme.text)}
        showContrast
      />
      <SwatchGroup
        title="Semantic"
        tokens={themeToTokens(theme.semantic)}
      />
    </div>
  );
}

// ── Storybook meta ────────────────────────────────────────────────────────────

const meta = {
  title: 'Foundations/Colors',
  parameters: {
    layout: 'fullscreen',
    docs: { description: { component: 'Full Kharis color palette with WCAG contrast ratios. Click any swatch to copy its hex.' } },
  },
} satisfies Meta;

export default meta;
type Story = StoryObj<typeof meta>;

export const Palette: Story = {
  name: 'Color Palette',
  render: () => <ColorPaletteView />,
};
