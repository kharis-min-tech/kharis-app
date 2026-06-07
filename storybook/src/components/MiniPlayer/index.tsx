import React from 'react';
import { colors } from '../../tokens/colors';
import { gradients } from '../../tokens/gradients';

export interface MiniPlayerProps {
  title: string;
  artist: string;
  isPlaying?: boolean;
  progress?: number; // 0–1
}

const PlayIcon: React.FC = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <polygon points="6,4 16,10 6,16" fill={colors.brand.gold.hex} />
  </svg>
);

const PauseIcon: React.FC = () => (
  <svg width="20" height="20" viewBox="0 0 20 20" fill="none">
    <rect x="5" y="4" width="3.5" height="12" rx="1" fill={colors.brand.gold.hex} />
    <rect x="11.5" y="4" width="3.5" height="12" rx="1" fill={colors.brand.gold.hex} />
  </svg>
);

export const MiniPlayer: React.FC<MiniPlayerProps> = ({
  title,
  artist,
  isPlaying = false,
  progress = 0,
}) => (
  <div style={{ position: 'relative' }}>
    {/* Gold progress line at top */}
    <div
      style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        height: '2px',
        background: colors.surface.subtle.hex,
        zIndex: 1,
      }}
    >
      <div
        style={{
          height: '100%',
          width: `${Math.min(1, Math.max(0, progress)) * 100}%`,
          background: gradients.goldAccent.css,
          transition: 'width 0.2s ease',
        }}
      />
    </div>

    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        padding: '0 16px',
        height: '56px',
        background: colors.surface.elevated.hex,
      }}
    >
      {/* Thumbnail */}
      <div
        style={{
          width: '36px',
          height: '36px',
          borderRadius: '8px',
          background: gradients.brandGlow.css,
          flexShrink: 0,
        }}
      />

      {/* Info */}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontSize: '14px',
            fontFamily: "'Maven Pro', sans-serif",
            fontWeight: 600,
            color: colors.text.primary.hex,
            overflow: 'hidden',
            whiteSpace: 'nowrap',
            textOverflow: 'ellipsis',
          }}
        >
          {title}
        </div>
        <div
          style={{
            fontSize: '12px',
            fontFamily: "'DM Sans', sans-serif",
            color: colors.text.secondary.hex,
          }}
        >
          {artist}
        </div>
      </div>

      {/* Play / Pause button */}
      <button
        style={{
          background: 'none',
          border: 'none',
          cursor: 'pointer',
          padding: '4px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          flexShrink: 0,
        }}
      >
        {isPlaying ? <PauseIcon /> : <PlayIcon />}
      </button>
    </div>
  </div>
);

export default MiniPlayer;
