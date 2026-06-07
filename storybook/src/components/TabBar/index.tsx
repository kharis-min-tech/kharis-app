import React from 'react';
import { theme as colors } from '../../tokens/colors'

export interface Tab {
  label: string;
  /** Raw SVG markup string for the icon */
  icon: string;
}

export interface TabBarProps {
  activeTab?: number;
  tabs: Tab[];
  onTabChange?: (index: number) => void;
}

export const TabBar: React.FC<TabBarProps> = ({
  activeTab = 0,
  tabs,
  onTabChange,
}) => (
  <div
    style={{
      display: 'flex',
      alignItems: 'stretch',
      background: colors.surface.elevated.hex,
      borderTop: `1px solid ${colors.surface.subtle.hex}`,
    }}
  >
    {tabs.map((tab, i) => {
      const isActive = i === activeTab;
      return (
        <button
          key={i}
          onClick={() => onTabChange?.(i)}
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '4px',
            padding: '10px 4px',
            background: 'none',
            border: 'none',
            cursor: 'pointer',
            color: isActive ? colors.brand.gold.hex : colors.text.muted.hex,
            transition: 'color 0.15s ease',
          }}
        >
          <span
            style={{ fontSize: '20px', lineHeight: 1, display: 'block' }}
            dangerouslySetInnerHTML={{ __html: tab.icon }}
          />
          <span
            style={{
              fontSize: '10px',
              fontFamily: "'DM Sans', sans-serif",
              fontWeight: isActive ? 600 : 400,
              letterSpacing: '0.04em',
              textTransform: 'uppercase',
            }}
          >
            {tab.label}
          </span>
        </button>
      );
    })}
  </div>
);

export default TabBar;
