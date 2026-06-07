import React from 'react';
import { theme } from '../../tokens/colors';

/**
 * QuickActionGrid - 2x2 or 2x3 grid of action cards on Home.
 *
 * Pattern: Everyday Rewards actions + Headspace daily suggestions.
 * Icon colour: magenta (#800654, from kharis.org icon-boxes).
 *
 * Ref: Everyday Rewards (mobbin.com/screens/923558b3)
 *      Headspace (mobbin.com/screens/ec5baa02)
 */

export interface QuickAction {
  icon: React.ReactNode;
  label: string;
  description?: string;
}

export interface QuickActionGridProps {
  actions: QuickAction[];
  columns?: 2 | 3;
}

export const QuickActionGrid = ({
  actions,
  columns = 2,
}: QuickActionGridProps) => (
  <div style={{
    display: 'grid',
    gridTemplateColumns: `repeat(${columns}, 1fr)`,
    gap: 12,
  }}>
    {actions.map((action, i) => (
      <div
        key={i}
        style={{
          backgroundColor: theme.surface.elevated.hex,
          borderRadius: 12,
          padding: 16,
          cursor: 'pointer',
          transition: 'background-color 0.2s ease',
        }}
      >
        <div style={{
          fontSize: 28,
          marginBottom: 8,
          color: theme.brand.magenta.hex,
        }}>
          {action.icon}
        </div>
        <div style={{
          fontFamily: '"Maven Pro", sans-serif',
          fontSize: 15,
          fontWeight: 600,
          color: theme.text.primary.hex,
          marginBottom: action.description ? 4 : 0,
        }}>
          {action.label}
        </div>
        {action.description && (
          <div style={{
            fontSize: 12,
            color: theme.text.body.hex,
            fontFamily: '"DM Sans", sans-serif',
          }}>
            {action.description}
          </div>
        )}
      </div>
    ))}
  </div>
);
