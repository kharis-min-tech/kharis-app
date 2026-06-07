import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { SermonCardList } from '../../components/SermonCard/SermonCardList';

const meta: Meta<typeof SermonCardList> = {
  title: 'Components/SermonCard/List',
  component: SermonCardList,
  parameters: { layout: 'centered', backgrounds: { default: 'dark' } },
  decorators: [(Story) => <div style={{ width: 350 }}><Story /></div>],
};
export default meta;

type Story = StoryObj<typeof SermonCardList>;

export const Default: Story = {
  args: {
    title: 'The Presence of God',
    speaker: 'David Antwi',
    duration: '29:15',
    artworkColor: 'linear-gradient(135deg, #3a1078, #6b34fa)',
  },
};

export const Playing: Story = {
  args: {
    ...Default.args,
    isPlaying: true,
  },
};

export const WithProgress: Story = {
  args: {
    ...Default.args,
    progress: 0.72,
    duration: '8:45 left',
  },
};

export const LongTitle: Story = {
  args: {
    title: 'Righteousness, Self-Control and Judgement, Acts 24',
    speaker: 'David Antwi',
    duration: '45:10',
    artworkColor: 'linear-gradient(135deg, #800654, #b91c8a)',
  },
};
