import React, { useState } from 'react';
import { colors } from '../../tokens/colors';
import { gradients } from '../../tokens/gradients';
import { shadows } from '../../tokens/shadows';

export interface ButtonProps {
  variant?: 'primary' | 'secondary' | 'ghost' | 'destructive';
  size?: 'sm' | 'md' | 'lg';
  disabled?: boolean;
  children: React.ReactNode;
  onClick?: () => void;
}

const SIZE_STYLES: Record<NonNullable<ButtonProps['size']>, React.CSSProperties> = {
  sm: { padding: '8px 16px', fontSize: '13px' },
  md: { padding: '12px 24px', fontSize: '15px' },
  lg: { padding: '16px 32px', fontSize: '17px' },
};

export const Button: React.FC<ButtonProps> = ({
  variant = 'primary',
  size = 'md',
  disabled = false,
  children,
  onClick,
}) => {
  const [hovered, setHovered] = useState(false);

  const base: React.CSSProperties = {
    borderRadius: '9999px',
    border: 'none',
    cursor: disabled ? 'not-allowed' : 'pointer',
    fontFamily: "'DM Sans', sans-serif",
    fontWeight: 600,
    letterSpacing: '0.01em',
    transition: 'opacity 0.15s ease, box-shadow 0.15s ease',
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    opacity: disabled ? 0.5 : hovered ? 0.85 : 1,
    ...SIZE_STYLES[size],
  };

  const variants: Record<NonNullable<ButtonProps['variant']>, React.CSSProperties> = {
    primary: {
      background: gradients.goldAccent.css,
      color: '#000000',
      boxShadow: hovered ? shadows.glowGold.value : 'none',
    },
    secondary: {
      background: 'transparent',
      color: colors.brand.purple.hex,
      border: `1.5px solid ${colors.brand.purple.hex}`,
      boxShadow: hovered ? shadows.glowPurple.value : 'none',
    },
    ghost: {
      background: 'transparent',
      color: colors.text.primary.hex,
      border: '1.5px solid transparent',
    },
    destructive: {
      background: colors.semantic.error.hex,
      color: colors.text.primary.hex,
    },
  };

  return (
    <button
      style={{ ...base, ...variants[variant] }}
      disabled={disabled}
      onClick={onClick}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
    >
      {children}
    </button>
  );
};

export default Button;
