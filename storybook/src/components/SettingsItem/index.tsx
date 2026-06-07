import React from 'react';
import { colors } from '../../tokens/colors';

export interface SettingsItemProps {
  icon: string; // emoji or character
  label: string;
  value?: string;
  hasToggle?: boolean;
  toggleOn?: boolean;
  hasArrow?: boolean;
  onToggle?: () => void;
}

const Toggle: React.FC<{ on: boolean }> = ({ on }) => (
  <div
    style={{
      width: '44px',
      height: '26px',
      borderRadius: '13px',
      background: on ? colors.brand.purple.hex : colors.surface.subtle.hex,
      position: 'relative',
      flexShrink: 0,
      transition: 'background 0.2s ease',
    }}
  >
    <div
      style={{
        position: 'absolute',
        top: '3px',
        left: on ? '21px' : '3px',
        width: '20px',
        height: '20px',
        borderRadius: '50%',
        background: colors.text.primary.hex,
        boxShadow: '0 1px 3px rgba(0,0,0,0.4)',
        transition: 'left 0.2s ease',
      }}
    />
  </div>
);

const ChevronRight: React.FC = () => (
  <svg width="16" height="16" viewBox="0 0 16 16" fill="none">
    <path
      d="M6 4l4 4-4 4"
      stroke={colors.text.muted.hex}
      strokeWidth="1.5"
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </svg>
);

export const SettingsItem: React.FC<SettingsItemProps> = ({
  icon,
  label,
  value,
  hasToggle = false,
  toggleOn = false,
  hasArrow = false,
  onToggle,
}) => (
  <div
    onClick={onToggle}
    style={{
      display: 'flex',
      alignItems: 'center',
      gap: '12px',
      padding: '14px 16px',
      background: colors.surface.elevated.hex,
      cursor: hasArrow || hasToggle ? 'pointer' : 'default',
    }}
  >
    <span
      style={{
        fontSize: '20px',
        lineHeight: 1,
        width: '28px',
        textAlign: 'center',
        flexShrink: 0,
      }}
    >
      {icon}
    </span>

    <span
      style={{
        flex: 1,
        fontSize: '16px',
        fontFamily: "'DM Sans', sans-serif",
        fontWeight: 400,
        color: colors.text.primary.hex,
      }}
    >
      {label}
    </span>

    {value && (
      <span
        style={{
          fontSize: '14px',
          fontFamily: "'DM Sans', sans-serif",
          color: colors.text.secondary.hex,
          marginRight: hasArrow ? '4px' : 0,
        }}
      >
        {value}
      </span>
    )}

    {hasToggle && <Toggle on={toggleOn} />}
    {hasArrow && !hasToggle && <ChevronRight />}
  </div>
);

export default SettingsItem;
