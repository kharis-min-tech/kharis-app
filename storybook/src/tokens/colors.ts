export interface ColorToken {
  name: string;
  hex: string;
  description: string;
}

export interface Colors {
  brand: {
    purple: ColorToken;
    gold: ColorToken;
    magenta: ColorToken;
  };
  surface: {
    dark: ColorToken;
    elevated: ColorToken;
    subtle: ColorToken;
  };
  text: {
    primary: ColorToken;
    secondary: ColorToken;
    muted: ColorToken;
  };
  semantic: {
    success: ColorToken;
    error: ColorToken;
    warning: ColorToken;
    info: ColorToken;
  };
}

export const colors: Colors = {
  brand: {
    purple: {
      name: 'Brand Purple',
      hex: '#6b34fa',
      description: 'Primary brand accent. Used for CTAs, highlights, and active interactive states.',
    },
    gold: {
      name: 'Brand Gold',
      hex: '#fd7f20',
      description: 'Secondary accent. Warmth, energy, call-to-action highlights and tier badges.',
    },
    magenta: {
      name: 'Brand Magenta',
      hex: '#800654',
      description: 'Tertiary accent. Depth, richness, and special emphasis in imagery and gradients.',
    },
  },
  surface: {
    dark: {
      name: 'Surface Dark',
      hex: '#0D0D0D',
      description: 'Base background. The deepest layer of the UI; page canvas.',
    },
    elevated: {
      name: 'Surface Elevated',
      hex: '#1A1A1A',
      description: 'Elevated surfaces. Cards, modals, sheet panels, and dropdowns.',
    },
    subtle: {
      name: 'Surface Subtle',
      hex: '#252525',
      description: 'Subtle separation. Dividers, input backgrounds, and hover states.',
    },
  },
  text: {
    primary: {
      name: 'Text Primary',
      hex: '#FFFFFF',
      description: 'Primary text. Headings and high-emphasis body copy.',
    },
    secondary: {
      name: 'Text Secondary',
      hex: '#A0A0A0',
      description: 'Secondary text. Subheadings, captions, and supporting copy.',
    },
    muted: {
      name: 'Text Muted',
      hex: '#666666',
      description: 'Low-emphasis text. Placeholders, disabled states, and metadata.',
    },
  },
  semantic: {
    success: {
      name: 'Success',
      hex: '#22C55E',
      description: 'Positive feedback. Confirmations, completed actions, online indicators.',
    },
    error: {
      name: 'Error',
      hex: '#EF4444',
      description: 'Negative feedback. Errors, destructive actions, critical alerts.',
    },
    warning: {
      name: 'Warning',
      hex: '#F59E0B',
      description: 'Caution feedback. Warnings, pending states, and cautionary notices.',
    },
    info: {
      name: 'Info',
      hex: '#3B82F6',
      description: 'Informational feedback. Tips, neutral notifications, and contextual help.',
    },
  },
};
