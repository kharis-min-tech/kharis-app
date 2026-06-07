import type { Meta, StoryObj } from '@storybook/react';
import React from 'react';
import { SermonCard } from '../../components/SermonCard';

const PURPLE_GRADIENT = 'linear-gradient(135deg, #6b34fa 0%, #800654 100%)';
const GOLD_GRADIENT = 'linear-gradient(135deg, #fd7f20 0%, #f5c842 100%)';
const MAGENTA_GRADIENT = 'linear-gradient(135deg, #800654 0%, #6b34fa 100%)';

const meta: Meta<typeof SermonCard> = {
  title: 'Components/SermonCard',
  component: SermonCard,
  parameters: {
    layout: 'centered',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    variant: {
      control: 'select',
      options: ['grid', 'list'],
    },
    isPlaying: { control: 'boolean' },
    progress: { control: { type: 'range', min: 0, max: 1, step: 0.01 } },
    title: { control: 'text' },
    speaker: { control: 'text' },
    duration: { control: 'text' },
    artworkColor: { control: 'text' },
  },
};

export default meta;
type Story = StoryObj<typeof SermonCard>;

export const Default: Story = {
  args: {
    variant: 'grid',
    title: 'The Power of Faith',
    speaker: 'Pastor James Okafor',
    artworkColor: PURPLE_GRADIENT,
    isPlaying: false,
  },
};

export const GridPlaying: Story = {
  args: {
    variant: 'grid',
    title: 'Walking in His Light',
    speaker: 'Kharis Worship',
    artworkColor: GOLD_GRADIENT,
    isPlaying: true,
    progress: 0.4,
  },
};

export const GridWithProgress: Story = {
  args: {
    variant: 'grid',
    title: 'Grace Sufficient',
    speaker: 'Rev. Adaeze Nwosu',
    artworkColor: MAGENTA_GRADIENT,
    isPlaying: false,
    progress: 0.65,
  },
};

export const ListDefault: Story = {
  args: {
    variant: 'list',
    title: 'The Power of Faith',
    speaker: 'Pastor James Okafor',
    duration: '42:15',
    artworkColor: PURPLE_GRADIENT,
    isPlaying: false,
  },
};

export const ListPlaying: Story = {
  args: {
    variant: 'list',
    title: 'Walking in His Light',
    speaker: 'Kharis Worship',
    duration: '38:00',
    artworkColor: GOLD_GRADIENT,
    isPlaying: true,
    progress: 0.3,
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '32px',
        background: '#0D0D0D',
        padding: '32px',
        borderRadius: '16px',
      }}
    >
      {/* Grid row */}
      <div>
        <div style={{ fontSize: '11px', color: '#666', fontFamily: 'DM Sans', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
          Grid variant
        </div>
        <div style={{ display: 'flex', gap: '12px', flexWrap: 'wrap' }}>
          <SermonCard
            variant="grid"
            title="The Power of Faith"
            speaker="Pastor James"
            artworkColor={PURPLE_GRADIENT}
          />
          <SermonCard
            variant="grid"
            title="Walking in His Light"
            speaker="Kharis Worship"
            artworkColor={GOLD_GRADIENT}
            isPlaying
            progress={0.4}
          />
          <SermonCard
            variant="grid"
            title="Grace Sufficient"
            speaker="Rev. Adaeze Nwosu"
            artworkColor={MAGENTA_GRADIENT}
            progress={0.65}
          />
        </div>
      </div>

      {/* List column */}
      <div>
        <div style={{ fontSize: '11px', color: '#666', fontFamily: 'DM Sans', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.08em' }}>
          List variant
        </div>
        <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxWidth: '440px' }}>
          <SermonCard
            variant="list"
            title="The Power of Faith"
            speaker="Pastor James Okafor"
            duration="42:15"
            artworkColor={PURPLE_GRADIENT}
          />
          <SermonCard
            variant="list"
            title="Walking in His Light"
            speaker="Kharis Worship"
            duration="38:00"
            artworkColor={GOLD_GRADIENT}
            isPlaying
            progress={0.3}
          />
          <SermonCard
            variant="list"
            title="Grace Sufficient for Every Season"
            speaker="Rev. Adaeze Nwosu"
            duration="55:42"
            artworkColor={MAGENTA_GRADIENT}
            progress={0.7}
          />
        </div>
      </div>
    </div>
  ),
};
