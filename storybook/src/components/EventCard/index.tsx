import React from 'react';
import { theme as colors } from '../../tokens/colors'
import { shadows } from '../../tokens/shadows';

export interface EventCardProps {
  day: string;
  month: string;
  title: string;
  location: string;
  time: string;
  featured?: boolean;
}

export const EventCard: React.FC<EventCardProps> = ({
  day,
  month,
  title,
  location,
  time,
  featured = false,
}) => (
  <div
    style={{
      display: 'flex',
      alignItems: 'center',
      gap: '16px',
      padding: '16px',
      background: colors.surface.elevated.hex,
      borderRadius: '12px',
      borderLeft: `3px solid ${featured ? colors.brand.gold.hex : 'transparent'}`,
      boxShadow: featured ? shadows.glowGold.value : shadows.sm.value,
    }}
  >
    {/* Date badge */}
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        minWidth: '44px',
        flexShrink: 0,
      }}
    >
      <div
        style={{
          fontSize: '22px',
          fontFamily: "'Maven Pro', sans-serif",
          fontWeight: 700,
          color: colors.brand.purple.hex,
          lineHeight: 1,
        }}
      >
        {day}
      </div>
      <div
        style={{
          fontSize: '11px',
          fontFamily: "'DM Sans', sans-serif",
          fontWeight: 600,
          color: colors.brand.purple.hex,
          textTransform: 'uppercase',
          letterSpacing: '0.08em',
          marginTop: '2px',
        }}
      >
        {month}
      </div>
    </div>

    {/* Info */}
    <div style={{ flex: 1, minWidth: 0 }}>
      <div
        style={{
          fontSize: '15px',
          fontFamily: "'Maven Pro', sans-serif",
          fontWeight: 600,
          color: colors.text.primary.hex,
          marginBottom: '4px',
          overflow: 'hidden',
          whiteSpace: 'nowrap',
          textOverflow: 'ellipsis',
        }}
      >
        {title}
      </div>
      <div
        style={{
          fontSize: '13px',
          fontFamily: "'DM Sans', sans-serif",
          color: colors.text.body.hex,
          display: 'flex',
          gap: '8px',
          alignItems: 'center',
        }}
      >
        <span>{time}</span>
        <span style={{ color: colors.text.muted.hex }}>·</span>
        <span
          style={{
            overflow: 'hidden',
            whiteSpace: 'nowrap',
            textOverflow: 'ellipsis',
          }}
        >
          {location}
        </span>
      </div>
    </div>
  </div>
);

export default EventCard;
