import type { Meta, StoryObj } from '@storybook/react';
import React from 'react';
import { PrayerCard } from '../../components/PrayerCard';

const meta: Meta<typeof PrayerCard> = {
  title: 'Components/PrayerCard',
  component: PrayerCard,
  parameters: {
    layout: 'padded',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    text: { control: 'text' },
    reference: { control: 'text' },
  },
};

export default meta;
type Story = StoryObj<typeof PrayerCard>;

export const Default: Story = {
  args: {
    text: 'Lord, grant us wisdom and peace as we gather in Your name today.',
    reference: 'James 1:5',
  },
};

export const WithReference: Story = {
  args: {
    text: 'Do not be anxious about anything, but in every situation, by prayer and petition, present your requests to God.',
    reference: 'Philippians 4:6',
  },
};

export const WithoutReference: Story = {
  args: {
    text: 'Father, thank You for another day of life, breath, and purpose. Guide our steps and let Your will be done in our lives.',
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '20px',
        background: '#0D0D0D',
        padding: '24px',
        borderRadius: '16px',
        maxWidth: '480px',
      }}
    >
      <PrayerCard
        text="Lord, grant us wisdom and peace as we gather in Your name today."
        reference="James 1:5"
      />
      <PrayerCard
        text="Father, thank You for another day of life, breath, and purpose. Guide our steps."
      />
      <PrayerCard
        text="Do not be anxious about anything, but in every situation, by prayer and petition, present your requests to God."
        reference="Philippians 4:6"
      />
    </div>
  ),
};
