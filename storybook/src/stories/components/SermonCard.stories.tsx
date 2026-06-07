import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { SermonCardGrid } from '../../components/SermonCard/SermonCardGrid';
import { SermonCardList } from '../../components/SermonCard/SermonCardList';
import { EqualizerIcon } from '../../components/SermonCard/EqualizerIcon';
import { ProgressBar } from '../../components/SermonCard/ProgressBar';

// --- Grid variant ---

const gridMeta: Meta<typeof SermonCardGrid> = {
  title: 'Components/SermonCard/Grid',
  component: SermonCardGrid,
  parameters: { layout: 'centered', backgrounds: { default: 'dark' } },
};
export default gridMeta;

type GridStory = StoryObj<typeof SermonCardGrid>;

export const Default: GridStory = {
  args: {
    title: 'The Presence of God',
    speaker: 'David Antwi',
    duration: '29:15',
    artworkColor: 'linear-gradient(135deg, #3a1078, #6b34fa)',
  },
};

export const Playing: GridStory = {
  args: {
    ...Default.args,
    isPlaying: true,
  },
};

export const WithProgress: GridStory = {
  args: {
    ...Default.args,
    progress: 0.55,
    duration: '12:30 left',
  },
};
