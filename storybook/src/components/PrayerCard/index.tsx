import React from 'react';
import { theme as colors } from '../../tokens/colors'
import { shadows } from '../../tokens/shadows';

export interface PrayerCardProps {
  text: string;
  reference?: string;
}

export const PrayerCard: React.FC<PrayerCardProps> = ({ text, reference }) => (
  <div
    style={{
      padding: '2px',
      borderRadius: '14px',
      background: 'linear-gradient(135deg, #6b34fa 0%, #800654 100%)',
      boxShadow: shadows.glowPurple.value,
    }}
  >
    <div
      style={{
        background: 'rgba(107,52,250,0.15)',
        borderRadius: '12px',
        padding: '24px',
      }}
    >
      <div
        style={{
          fontSize: '16px',
          fontFamily: "'DM Sans', sans-serif",
          fontStyle: 'italic',
          fontWeight: 400,
          color: colors.text.primary.hex,
          lineHeight: 1.75,
          marginBottom: reference ? '16px' : 0,
        }}
      >
        "{text}"
      </div>
      {reference && (
        <div
          style={{
            fontSize: '13px',
            fontFamily: "'DM Sans', sans-serif",
            fontWeight: 500,
            color: colors.brand.purple.hex,
          }}
        >
          {reference}
        </div>
      )}
    </div>
  </div>
);

export default PrayerCard;
