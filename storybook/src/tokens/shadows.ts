export interface ShadowToken {
  name: string;
  value: string;
  description: string;
}

export interface Shadows {
  sm: ShadowToken;
  md: ShadowToken;
  lg: ShadowToken;
  glowPurple: ShadowToken;
  glowGold: ShadowToken;
}

export const shadows: Shadows = {
  sm: {
    name: 'Shadow SM',
    value: '0 1px 2px rgba(0,0,0,0.3)',
    description: 'Subtle lift. Inline elements, close-to-surface cards, input focus rings.',
  },
  md: {
    name: 'Shadow MD',
    value: '0 4px 12px rgba(0,0,0,0.4)',
    description: 'Standard elevation. Cards, dropdowns, popovers, tooltips.',
  },
  lg: {
    name: 'Shadow LG',
    value: '0 8px 24px rgba(0,0,0,0.5)',
    description: 'Prominent elevation. Modals, overlays, floating action elements.',
  },
  glowPurple: {
    name: 'Glow Purple',
    value: '0 0 20px rgba(107,52,250,0.3)',
    description: 'Brand purple ambient glow. Active CTAs, focused primary inputs, selected states.',
  },
  glowGold: {
    name: 'Glow Gold',
    value: '0 0 20px rgba(253,127,32,0.3)',
    description: 'Brand gold ambient glow. Featured items, premium tier indicators, highlights.',
  },
};
