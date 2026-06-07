import React from 'react';
import { theme } from '../../tokens/colors';
import { shadows } from '../../tokens/shadows';
import { EqualizerIcon } from './EqualizerIcon';
import { ProgressBar } from './ProgressBar';
import type { SermonCardProps } from './types';
import { DEFAULT_ARTWORK } from './types';

/**
 * SermonCardList - row item for vertical sermon lists.
 *
 * Full width. 56px thumbnail, title + speaker, duration badge.
 * Optional equalizer (playing) and progress bar (resume).
 */
export const SermonCardList: React.FC<SermonCardProps> = ({
  title,
  speaker,
  duration,
  artworkColor = DEFAULT_ARTWORK,
  isPlaying = false,
  progress,
}) => {
  const hasProgress = typeof progress === 'number' && progress > 0;

  return (
    <div style={{
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      padding: '12px 16px',
      background: theme.surface.elevated.hex,
      borderRadius: 12,
      boxShadow: shadows.sm.value,
    }}>
      <div style={{
        width: 56,
        height: 56,
        borderRadius: 8,
        background: artworkColor,
        flexShrink: 0,
        position: 'relative',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}>
        {isPlaying && <EqualizerIcon />}
        {hasProgress && <ProgressBar progress={progress!} />}
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontSize: 15,
          fontFamily: '"Maven Pro", sans-serif',
          fontWeight: 600,
          color: theme.text.primary.hex,
          marginBottom: 2,
          overflow: 'hidden',
          whiteSpace: 'nowrap',
          textOverflow: 'ellipsis',
        }}>
          {title}
        </div>
        <div style={{
          fontSize: 13,
          fontFamily: '"DM Sans", sans-serif',
          color: theme.text.body.hex,
        }}>
          {speaker}
        </div>
      </div>

      {duration && (
        <div style={{
          fontSize: 12,
          fontFamily: '"DM Sans", sans-serif',
          color: theme.text.muted.hex,
          flexShrink: 0,
        }}>
          {duration}
        </div>
      )}
    </div>
  );
};
