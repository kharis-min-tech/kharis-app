import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { HomeHero } from '../../components/HomeHero';

const meta: Meta<typeof HomeHero> = {
  title: 'Components/HomeHero',
  component: HomeHero,
  parameters: { layout: 'centered', backgrounds: { default: 'dark' } },
  decorators: [(Story) => <div style={{ width: 350 }}><Story /></div>],
};
export default meta;
type Story = StoryObj<typeof HomeHero>;

const PlayIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M8 5v14l11-7z" /></svg>
);

export const LiveService: Story = {
  args: {
    badge: 'Live Sunday',
    isLive: true,
    title: 'Sunday Service',
    subtitle: 'Strood Academy · 10:30 AM',
    ctaLabel: 'Watch Live',
    ctaIcon: <PlayIcon />,
  },
};

export const FastingAnnouncement: Story = {
  args: {
    badge: '21 Days Fasting',
    isLive: false,
    title: '21 Days Prayer & Fasting',
    subtitle: '1st – 21st June 2026 · All Branches',
    ctaLabel: 'Fasting Booklet',
    backgroundGradient: 'linear-gradient(135deg, #4a1a0a, #8a3a1a 50%, #0D0D0D 100%)',
  },
};

export const SpecialEvent: Story = {
  args: {
    badge: 'Special Event',
    title: 'Kharis Phase 2 Conference',
    subtitle: 'Save the date · September 2026',
    ctaLabel: 'Learn More',
    backgroundGradient: 'linear-gradient(135deg, #0a2a4e, #1a4a7e 50%, #0D0D0D 100%)',
  },
};
