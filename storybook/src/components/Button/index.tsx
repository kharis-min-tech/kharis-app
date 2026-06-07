import React from 'react';
import { theme } from '../../tokens/colors';

/**
 * Button
 *
 * Sourced from kharis.org. All 6 CTAs on the website are identical:
 * solid orange, Maven Pro 14px bold uppercase, 12px radius, 18px 40px pad.
 *
 * Secondary and ghost derived from the same family.
 * No gradients. No shadows. No glows.
 */

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

const sizes = {
  sm: { padding: '12px 24px', fontSize: 12 },
  md: { padding: '18px 40px', fontSize: 14 },
  lg: { padding: '20px 48px', fontSize: 16 },
};

export const Button = ({
  variant = 'primary',
  size = 'md',
  disabled = false,
  children,
  onClick,
}: ButtonProps) => {
  const s = sizes[size];

  const base: React.CSSProperties = {
    fontFamily: '"Maven Pro", sans-serif',
    fontSize: s.fontSize,
    fontWeight: 700,
    textTransform: 'uppercase',
    letterSpacing: 'normal',
    padding: s.padding,
    borderRadius: 12,
    border: 'none',
    cursor: disabled ? 'not-allowed' : 'pointer',
    opacity: disabled ? 0.5 : 1,
    transition: 'opacity 0.2s ease',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 8,
    textDecoration: 'none',
  };

  const variants: Record<string, React.CSSProperties> = {
    primary: {
      ...base,
      backgroundColor: theme.brand.orange.hex,
      color: theme.text.primary.hex,
    },
    secondary: {
      ...base,
      backgroundColor: 'transparent',
      border: `1px solid ${theme.brand.orange.hex}`,
      color: theme.brand.orange.hex,
    },
    ghost: {
      ...base,
      backgroundColor: 'transparent',
      color: theme.text.body.hex,
    },
  };

  return (
    <button
      style={variants[variant]}
      disabled={disabled}
      onClick={onClick}
    >
      {children}
    </button>
  );
};
