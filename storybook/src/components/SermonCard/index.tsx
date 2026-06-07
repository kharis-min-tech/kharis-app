import React from 'react';
import { theme as colors } from '../../tokens/colors'
import { shadows } from '../../tokens/shadows';

export interface SermonCardProps {
  variant?: 'grid' | 'list';
  title: string;
  speaker: string;
  duration?: string;
  artworkColor?: string;
  isPlaying?: boolean;
  progress?: number; // 0–1
}

const EqualizerIcon: React.FC = () => (
  <>
    <style>{`
      @keyframes eq1 { 0%,100%{height:40%} 50%{height:100%} }
      @keyframes eq2 { 0%,100%{height:100%} 50%{height:30%} }
      @keyframes eq3 { 0%,100%{height:60%} 50%{height:90%} }
    `}</style>
    <div
      style={{
        display: 'flex',
        alignItems: 'flex-end',
        gap: '2px',
        height: '16px',
      }}
    >
      {(['eq1', 'eq2', 'eq3'] as const).map((name) => (
        <div
          key={name}
          style={{
            width: '3px',
            background: colors.brand.gold.hex,
            borderRadius: '1px',
            animation: `${name} 0.8s ease-in-out infinite`,
            height: '60%',
          }}
        />
      ))}
    </div>
  </>
);

const DEFAULT_ARTWORK = 'linear-gradient(135deg, #6b34fa 0%, #800654 100%)';

export const SermonCard: React.FC<SermonCardProps> = ({
  variant = 'grid',
  title,
  speaker,
  duration,
  artworkColor = DEFAULT_ARTWORK,
  isPlaying = false,
  progress,
}) => {
  const hasProgress = typeof progress === 'number' && progress > 0;

  if (variant === 'grid') {
    return (
      <div
        style={{
          width: '150px',
          background: colors.surface.elevated.hex,
          borderRadius: '12px',
          overflow: 'hidden',
          boxShadow: shadows.md.value,
        }}
      >
        <div
          style={{
            width: '150px',
            height: '150px',
            background: artworkColor,
            position: 'relative',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          {isPlaying && (
            <div style={{ position: 'absolute', bottom: '8px', right: '8px' }}>
              <EqualizerIcon />
            </div>
          )}
          {hasProgress && (
            <div
              style={{
                position: 'absolute',
                bottom: 0,
                left: 0,
                right: 0,
                height: '3px',
                background: colors.surface.subtle.hex,
              }}
            >
              <div
                style={{
                  height: '100%',
                  width: `${progress! * 100}%`,
                  background: colors.brand.gold.hex,
                }}
              />
            </div>
          )}
        </div>
        <div style={{ padding: '12px' }}>
          <div
            style={{
              fontSize: '14px',
              fontFamily: "'Maven Pro', sans-serif",
              fontWeight: 600,
              color: colors.text.primary.hex,
              marginBottom: '4px',
              lineHeight: 1.3,
              display: '-webkit-box',
              WebkitLineClamp: 2,
              WebkitBoxOrient: 'vertical',
              overflow: 'hidden',
            }}
          >
            {title}
          </div>
          <div
            style={{
              fontSize: '12px',
              fontFamily: "'DM Sans', sans-serif",
              color: colors.text.body.hex,
            }}
          >
            {speaker}
          </div>
        </div>
      </div>
    );
  }

  // list variant
  return (
    <div
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        padding: '12px 16px',
        background: colors.surface.elevated.hex,
        borderRadius: '12px',
        boxShadow: shadows.sm.value,
      }}
    >
      <div
        style={{
          width: '56px',
          height: '56px',
          borderRadius: '8px',
          background: artworkColor,
          flexShrink: 0,
          position: 'relative',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {isPlaying && <EqualizerIcon />}
        {hasProgress && (
          <div
            style={{
              position: 'absolute',
              bottom: 0,
              left: 0,
              right: 0,
              height: '3px',
              background: colors.surface.subtle.hex,
              borderRadius: '0 0 8px 8px',
            }}
          >
            <div
              style={{
                height: '100%',
                width: `${progress! * 100}%`,
                background: colors.brand.gold.hex,
                borderRadius: '0 0 0 8px',
              }}
            />
          </div>
        )}
      </div>

      <div style={{ flex: 1, minWidth: 0 }}>
        <div
          style={{
            fontSize: '15px',
            fontFamily: "'Maven Pro', sans-serif",
            fontWeight: 600,
            color: colors.text.primary.hex,
            marginBottom: '2px',
            overflow: 'hidden',
            whiteSpace: 'nowrap',
            textOverflow: 'ellipsis',
          }}
        >
          {title}
        </div>
        <div
          style={{
            fontSize: '13px',
            fontFamily: "'DM Sans', sans-serif",
            color: colors.text.body.hex,
          }}
        >
          {speaker}
        </div>
      </div>

      {duration && (
        <div
          style={{
            fontSize: '12px',
            fontFamily: "'DM Sans', sans-serif",
            color: colors.text.muted.hex,
            flexShrink: 0,
          }}
        >
          {duration}
        </div>
      )}
    </div>
  );
};

export default SermonCard;
