import type { Meta, StoryObj } from '@storybook/react';
import React from 'react';
import { ReadingCard } from '../../components/ReadingCard';

const meta: Meta<typeof ReadingCard> = {
  title: 'Components/ReadingCard',
  component: ReadingCard,
  parameters: {
    layout: 'padded',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    label: { control: 'text' },
    verse: { control: 'text' },
  },
};

export default meta;
type Story = StoryObj<typeof ReadingCard>;

export const Default: Story = {
  args: {
    label: "Today's Verse",
    verse:
      'For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life.',
  },
};

export const DailyReading: Story = {
  args: {
    label: 'Daily Reading',
    verse:
      'The Lord is my shepherd; I shall not want. He makes me lie down in green pastures.',
  },
};

export const MemoryVerse: Story = {
  args: {
    label: 'Memory Verse',
    verse: 'I can do all things through Christ who strengthens me. — Philippians 4:13',
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '16px',
        background: '#0D0D0D',
        padding: '24px',
        borderRadius: '16px',
        maxWidth: '480px',
      }}
    >
      <ReadingCard
        label="Today's Verse"
        verse="For God so loved the world, that he gave his only Son, that whoever believes in him should not perish but have eternal life. — John 3:16"
      />
      <ReadingCard
        label="Memory Verse"
        verse="I can do all things through Christ who strengthens me. — Philippians 4:13"
      />
      <ReadingCard
        label="Weekly Reading"
        verse="The Lord is my shepherd; I shall not want."
      />
    </div>
  ),
};
