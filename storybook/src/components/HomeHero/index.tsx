import React from 'react';
import { theme } from '../../tokens/colors';

/**
 * HomeHero - full-width hero card at top of Home.
 *
 * Pattern: Headspace daily card + MasterClass featured content.
 * CTA: solid orange from kharis.org button spec.
 *
 * Ref: Headspace (mobbin.com/screens/d95b9be8)
 *      MasterClass (mobbin.com/screens/3f997cfa)
 */

export interface HomeHeroProps {
  badge?: string;
  isLive?: boolean;
  title: string;
  subtitle: string;
  ctaLabel: string;
  ctaIcon?: React.ReactNode;
  onCtaClick?: () => void;
  backgroundGradient?: string;
}

export const HomeHero = ({
  badge,
  isLive = false,
  title,
  subtitle,
  ctaLabel,
  ctaIcon,
  onCtaClick,
  backgroundGradient = `linear-gradient(135deg, #3a1a5e 0%, #1a0a2e 50%, ${theme.surface.dark.hex} 100%)`,
}: HomeHeroProps) => (
  <div style={{
    position: 'relative',
    borderRadius: 16,
    overflow: 'hidden',
    background: backgroundGradient,
    padding: '32px 20px 24px',
    minHeight: 200,
    display: 'flex',
    flexDirection: 'column',
    justifyContent: 'flex-end',
  }}>
    {badge && (
      <div style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 6,
        backgroundColor: 'rgba(255,255,255,0.12)',
        backdropFilter: 'blur(10px)',
        padding: '5px 12px',
        borderRadius: 50,
        fontSize: 11,
        fontWeight: 600,
        color: theme.brand.orange.hex,
        marginBottom: 10,
        alignSelf: 'flex-start',
        textTransform: 'uppercase',
        letterSpacing: 0.5,
      }}>
        {isLive && (
          <span style={{
            width: 7,
            height: 7,
            borderRadius: '50%',
            backgroundColor: theme.semantic.success.hex,
          }} />
        )}
        {badge}
      </div>
    )}

    <h2 style={{
      fontFamily: '"Maven Pro", sans-serif',
      fontSize: 24,
      fontWeight: 700,
      color: theme.text.primary.hex,
      lineHeight: 1.2,
      margin: '0 0 4px',
      letterSpacing: -0.5,
    }}>
      {title}
    </h2>

    <p style={{
      fontSize: 14,
      color: 'rgba(255,255,255,0.7)',
      margin: '0 0 16px',
      fontFamily: '"DM Sans", sans-serif',
    }}>
      {subtitle}
    </p>

    <button
      onClick={onCtaClick}
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 8,
        backgroundColor: theme.brand.orange.hex,
        color: theme.text.primary.hex,
        fontFamily: '"Maven Pro", sans-serif',
        fontSize: 14,
        fontWeight: 700,
        textTransform: 'uppercase',
        padding: '14px 28px',
        borderRadius: 12,
        border: 'none',
        cursor: 'pointer',
        alignSelf: 'flex-start',
      }}
    >
      {ctaIcon}
      {ctaLabel}
    </button>
  </div>
);
