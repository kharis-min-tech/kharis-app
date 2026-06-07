import React from 'react';
import { theme } from '../../tokens/colors';

/** Thin orange progress bar over a subtle track. */
export const ProgressBar: React.FC<{ progress: number }> = ({ progress }) => (
  <div style={{
    position: 'absolute',
    bottom: 0,
    left: 0,
    right: 0,
    height: 3,
    background: theme.surface.subtle.hex,
  }}>
    <div style={{
      height: '100%',
      width: `${progress * 100}%`,
      background: theme.brand.orange.hex,
    }} />
  </div>
);
