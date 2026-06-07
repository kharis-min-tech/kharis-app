import type { Meta, StoryObj } from '@storybook/react';
import React from 'react';
import { MiniPlayer } from '../../components/MiniPlayer';

const meta: Meta<typeof MiniPlayer> = {
  title: 'Components/MiniPlayer',
  component: MiniPlayer,
  parameters: {
    layout: 'padded',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    title: { control: 'text' },
    artist: { control: 'text' },
    isPlaying: { control: 'boolean' },
    progress: { control: { type: 'range', min: 0, max: 1, step: 0.01 } },
  },
};

export default meta;
type Story = StoryObj<typeof MiniPlayer>;

export const Default: Story = {
  args: {
    title: 'The Power of Faith',
    artist: 'Pastor James Okafor',
    isPlaying: false,
    progress: 0,
  },
};

export const Playing: Story = {
  args: {
    title: 'Walking in His Light',
    artist: 'Kharis Worship',
    isPlaying: true,
    progress: 0.45,
  },
};

export const Paused: Story = {
  args: {
    title: 'Grace Sufficient',
    artist: 'Rev. Adaeze Nwosu',
    isPlaying: false,
    progress: 0.72,
  },
};

export const AtStart: Story = {
  args: {
    title: 'New Every Morning',
    artist: 'Pastor Samuel Adeyemi',
    isPlaying: true,
    progress: 0.05,
  },
};

export const NearEnd: Story = {
  args: {
    title: 'The Promises of God',
    artist: 'Kharis Worship',
    isPlaying: true,
    progress: 0.92,
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '2px',
        background: '#0D0D0D',
        padding: '24px',
        borderRadius: '16px',
        maxWidth: '400px',
      }}
    >
      <MiniPlayer
        title="Walking in His Light"
        artist="Kharis Worship"
        isPlaying={true}
        progress={0.45}
      />
      <div style={{ height: '16px' }} />
      <MiniPlayer
        title="Grace Sufficient"
        artist="Rev. Adaeze Nwosu"
        isPlaying={false}
        progress={0.72}
      />
      <div style={{ height: '16px' }} />
      <MiniPlayer
        title="New Every Morning"
        artist="Pastor Samuel Adeyemi"
        isPlaying={false}
        progress={0}
      />
    </div>
  ),
};
