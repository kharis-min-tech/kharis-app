import React from 'react';
import { theme } from '../../tokens/colors';

/**
 * ContentRow - horizontal scrolling section with header + "See All".
 *
 * Pattern: Netflix browse rows + Headspace content suggestions.
 * "See All" in orange (kharis.org CTA colour).
 * Title: Maven Pro 20px 600.
 *
 * Ref: Netflix (mobbin.com/screens/4af9782e)
 *      Headspace (mobbin.com/screens/1cba404f)
 */

export interface ContentRowProps {
  title: string;
  seeAllLabel?: string;
  onSeeAll?: () => void;
  children: React.ReactNode;
}

export const ContentRow = ({
  title,
  seeAllLabel = 'See All',
  onSeeAll,
  children,
}: ContentRowProps) => (
  <div style={{ marginBottom: 28 }}>
    <div style={{
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      marginBottom: 14,
      padding: '0 20px',
    }}>
      <h2 style={{
        fontFamily: '"Maven Pro", sans-serif',
        fontSize: 20,
        fontWeight: 600,
        color: theme.text.primary.hex,
        margin: 0,
        letterSpacing: -0.5,
      }}>
        {title}
      </h2>
      {onSeeAll && (
        <button
          onClick={onSeeAll}
          style={{
            background: 'none',
            border: 'none',
            fontFamily: '"DM Sans", sans-serif',
            fontSize: 13,
            fontWeight: 500,
            color: theme.brand.orange.hex,
            cursor: 'pointer',
            padding: 0,
          }}
        >
          {seeAllLabel}
        </button>
      )}
    </div>
    <div style={{
      display: 'flex',
      gap: 12,
      overflowX: 'auto',
      paddingLeft: 20,
      paddingRight: 20,
    }}>
      {children}
    </div>
  </div>
);
