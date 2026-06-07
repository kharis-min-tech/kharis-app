import React from 'react';

/**
 * Button — matches kharis.org exactly.
 *
 * Website evidence (all 6 CTAs identical):
 *   bg: #FD7F20 (solid, NOT gradient)
 *   color: #FFFFFF
 *   font: Maven Pro, 14px, 700, uppercase
 *   padding: 18px 40px
 *   border-radius: 12px
 *   border: none
 *   shadow: none
 *
 * Secondary variant derived from social icons:
 *   bg: transparent, border: 1px solid #FD7F20, color: #FD7F20
 *
 * Ghost derived from nav links:
 *   bg: transparent, color: #7A7A7A
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
    textTransform: 'uppercase' as const,
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
      backgroundColor: '#FD7F20',
      color: '#FFFFFF',
    },
    secondary: {
      ...base,
      backgroundColor: 'transparent',
      border: '1px solid #FD7F20',
      color: '#FD7F20',
    },
    ghost: {
      ...base,
      backgroundColor: 'transparent',
      color: '#7A7A7A',
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
