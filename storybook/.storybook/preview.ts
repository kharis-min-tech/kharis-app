import type { Preview } from 'storybook';
import '../src/styles/globals.css';

const preview: Preview = {
  parameters: {
    layout: 'centered',
    backgrounds: {
      options: {
        dark: { name: 'dark', value: '#0D0D0D' },
        elevated: { name: 'elevated', value: '#1A1A1A' },
        subtle: { name: 'subtle', value: '#252525' }
      }
    },
  },

  initialGlobals: {
    backgrounds: {
      value: 'dark'
    }
  }
};

export default preview;
