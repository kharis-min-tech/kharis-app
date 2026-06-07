import React from 'react';

/**
 * ContentRow — horizontal scrolling section with header + "See All".
 *
 * Pattern: Netflix browse rows + Headspace content suggestions.
 * "See All" link uses #FD7F20 (Kharis orange, matching website CTAs).
 * Section title: Maven Pro 20px 600 weight, #FFFFFF.
 *
 * Ref: Netflix (https://mobbin.com/screens/4af9782e-47db-4330-9c6e-5154b445f7d6)
 *      Headspace (https://mobbin.com/screens/1cba404f-413c-4a8b-be36-d791e9ca4fed)
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
        color: '#FFFFFF',
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
            color: '#FD7F20',
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
      scrollbarWidth: 'none',
    }}>
      {children}
    </div>
  </div>
);
