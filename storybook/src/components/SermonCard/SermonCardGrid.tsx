import React from 'react';
import { theme } from '../../tokens/colors';
import { shadows } from '../../tokens/shadows';
import { EqualizerIcon } from './EqualizerIcon';
import { ProgressBar } from './ProgressBar';
import type { SermonCardProps } from './types';
import { DEFAULT_ARTWORK } from './types';

/**
 * SermonCardGrid - thumbnail card for horizontal scroll rows.
 *
 * 150px wide. Square artwork with gradient. Title + speaker below.
 * Optional equalizer (playing) and progress bar (resume).
 */
export const SermonCardGrid: React.FC<SermonCardProps> = ({
  title,
  speaker,
  artworkColor = DEFAULT_ARTWORK,
  isPlaying = false,
  progress,
}) => {
  const hasProgress = typeof progress === 'number' && progress > 0;

  return (
    <div style={{
      width: 150,
      background: theme.surface.elevated.hex,
      borderRadius: 12,
      overflow: 'hidden',
      boxShadow: shadows.md.value,
      flexShrink: 0,
    }}>
      <div style={{
        width: 150,
        height: 150,
        background: artworkColor,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}>
        {isPlaying && (
          <div style={{ position: 'absolute', bottom: 8, right: 8 }}>
            <EqualizerIcon />
          </div>
        )}
        {hasProgress && <ProgressBar progress={progress!} />}
      </div>
      <div style={{ padding: 12 }}>
        <div style={{
          fontSize: 14,
          fontFamily: '"Maven Pro", sans-serif',
          fontWeight: 600,
          color: theme.text.primary.hex,
          marginBottom: 4,
          lineHeight: 1.3,
          display: '-webkit-box',
          WebkitLineClamp: 2,
          WebkitBoxOrient: 'vertical',
          overflow: 'hidden',
        }}>
          {title}
        </div>
        <div style={{
          fontSize: 12,
          fontFamily: '"DM Sans", sans-serif',
          color: theme.text.body.hex,
        }}>
          {speaker}
        </div>
      </div>
    </div>
  );
};
