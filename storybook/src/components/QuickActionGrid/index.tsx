import React from 'react';

/**
 * QuickActionGrid — 2×2 or 2×3 grid of action cards on Home.
 *
 * Pattern: Everyday Rewards actions + Headspace daily suggestions.
 * Each card: icon + label + optional description.
 * Tappable. Icon colour: #800654 (magenta, from kharis.org icon-boxes).
 *
 * Ref: Everyday Rewards (https://mobbin.com/screens/923558b3-13a2-4687-b43b-ee2553050e0c)
 *      Headspace (https://mobbin.com/screens/ec5baa02-aace-497d-ac04-bfa0557e1bdd)
 */

export interface QuickAction {
  icon: string;
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
          backgroundColor: '#1A1A1A',
          borderRadius: 12,
          padding: 16,
          cursor: 'pointer',
          transition: 'background-color 0.2s',
        }}
      >
        <div style={{
          fontSize: 28,
          marginBottom: 8,
          color: '#800654',
        }}>
          {action.icon}
        </div>
        <div style={{
          fontFamily: '"Maven Pro", sans-serif',
          fontSize: 15,
          fontWeight: 600,
          color: '#FFFFFF',
          marginBottom: action.description ? 4 : 0,
        }}>
          {action.label}
        </div>
        {action.description && (
          <div style={{
            fontSize: 12,
            color: '#7A7A7A',
            fontFamily: '"DM Sans", sans-serif',
          }}>
            {action.description}
          </div>
        )}
      </div>
    ))}
  </div>
);
