import type { Preview } from 'storybook';
import '../src/styles/globals.css';

const preview: Preview = {
  parameters: {
    layout: 'centered',
    backgrounds: {
      default: 'dark',
      values: [
        { name: 'dark', value: '#0D0D0D' },
        { name: 'elevated', value: '#1A1A1A' },
        { name: 'subtle', value: '#252525' },
      ],
    },
  },
};

export default preview;
