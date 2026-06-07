import React from 'react';
import { colors } from '../../tokens/colors';

export interface ChipFilterProps {
  label: string;
  active?: boolean;
  onClick?: () => void;
}

export const ChipFilter: React.FC<ChipFilterProps> = ({
  label,
  active = false,
  onClick,
}) => (
  <button
    onClick={onClick}
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '6px 16px',
      borderRadius: '9999px',
      border: active
        ? `1.5px solid ${colors.brand.gold.hex}`
        : '1.5px solid transparent',
      background: active
        ? 'rgba(253,127,32,0.10)'
        : colors.surface.subtle.hex,
      color: active ? colors.brand.gold.hex : colors.text.secondary.hex,
      fontFamily: "'DM Sans', sans-serif",
      fontSize: '13px',
      fontWeight: active ? 600 : 400,
      cursor: 'pointer',
      transition: 'all 0.15s ease',
      whiteSpace: 'nowrap',
    }}
  >
    {label}
  </button>
);

export default ChipFilter;
