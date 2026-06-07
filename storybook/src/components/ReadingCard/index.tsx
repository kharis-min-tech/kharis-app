import React from 'react';
import { colors } from '../../tokens/colors';
import { shadows } from '../../tokens/shadows';

export interface ReadingCardProps {
  label: string;
  verse: string;
}

export const ReadingCard: React.FC<ReadingCardProps> = ({ label, verse }) => (
  <div
    style={{
      background: colors.surface.elevated.hex,
      borderLeft: `3px solid ${colors.brand.gold.hex}`,
      borderRadius: '0 12px 12px 0',
      padding: '20px 24px',
      boxShadow: shadows.md.value,
    }}
  >
    <div
      style={{
        fontSize: '12px',
        fontFamily: "'DM Sans', sans-serif",
        fontWeight: 600,
        color: colors.brand.gold.hex,
        textTransform: 'uppercase',
        letterSpacing: '0.10em',
        marginBottom: '12px',
      }}
    >
      {label}
    </div>
    <div
      style={{
        fontSize: '18px',
        fontFamily: "'Maven Pro', sans-serif",
        fontWeight: 500,
        color: colors.text.primary.hex,
        lineHeight: 1.55,
      }}
    >
      {verse}
    </div>
  </div>
);

export default ReadingCard;
