import React from 'react';
import { theme } from '../../tokens/colors';

const keyframes = `
  @keyframes eq1 { 0%,100%{height:40%} 50%{height:100%} }
  @keyframes eq2 { 0%,100%{height:100%} 50%{height:30%} }
  @keyframes eq3 { 0%,100%{height:60%} 50%{height:90%} }
`;

/** Animated 3-bar equalizer indicating active playback. */
export const EqualizerIcon: React.FC = () => (
  <>
    <style>{keyframes}</style>
    <div style={{
      display: 'flex',
      alignItems: 'flex-end',
      gap: 2,
      height: 16,
    }}>
      {(['eq1', 'eq2', 'eq3'] as const).map((name) => (
        <div
          key={name}
          style={{
            width: 3,
            background: theme.brand.orange.hex,
            borderRadius: 1,
            animation: `${name} 0.8s ease-in-out infinite`,
            height: '60%',
          }}
        />
      ))}
    </div>
  </>
);
