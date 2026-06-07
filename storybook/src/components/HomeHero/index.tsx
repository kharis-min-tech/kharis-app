import React from 'react';

/**
 * HomeHero — full-width hero card at top of Home.
 *
 * Pattern: Headspace daily card + MasterClass featured content.
 * Colour: Kharis orange #FD7F20 CTA on dark/image overlay.
 * Ref: Headspace (https://mobbin.com/screens/d95b9be8-a5b8-4995-9196-ae15e24a722c)
 *      MasterClass (https://mobbin.com/screens/3f997cfa-8542-4c40-9290-abe6c67fe0bb)
 */

export interface HomeHeroProps {
  /** e.g. "LIVE SUNDAY" or "21 DAYS FASTING" */
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
  backgroundGradient = 'linear-gradient(135deg, #3a1a5e 0%, #1a0a2e 50%, #0D0D0D 100%)',
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
        color: '#FD7F20',
        marginBottom: 10,
        alignSelf: 'flex-start',
        textTransform: 'uppercase',
        letterSpacing: 0.5,
      }}>
        {isLive && (
          <span style={{
            width: 7, height: 7, borderRadius: '50%',
            backgroundColor: '#22C55E',
            animation: 'pulse 2s infinite',
          }} />
        )}
        {badge}
      </div>
    )}

    <h2 style={{
      fontFamily: '"Maven Pro", sans-serif',
      fontSize: 24,
      fontWeight: 700,
      color: '#FFFFFF',
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
        backgroundColor: '#FD7F20',
        color: '#FFFFFF',
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
