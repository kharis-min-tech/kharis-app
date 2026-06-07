import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { ContentRow } from '../../components/ContentRow';
import { SermonCard } from '../../components/SermonCard';

const meta: Meta<typeof ContentRow> = {
  title: 'Components/ContentRow',
  component: ContentRow,
  parameters: { layout: 'centered', backgrounds: { default: 'dark' } },
  decorators: [(Story) => <div style={{ width: 390 }}><Story /></div>],
};
export default meta;
type Story = StoryObj<typeof ContentRow>;

export const LatestSermons: Story = {
  args: {
    title: 'Latest Sermons',
    seeAllLabel: 'See All',
    onSeeAll: () => {},
    children: [
      <SermonCard key="1" variant="grid" title="The Presence of God" speaker="David Antwi" duration="29:15" artworkColor="linear-gradient(135deg, #3a1078, #6b34fa)" />,
      <SermonCard key="2" variant="grid" title="Have a Pure Heart" speaker="David Antwi" duration="34:02" artworkColor="linear-gradient(135deg, #800654, #b91c8a)" />,
      <SermonCard key="3" variant="grid" title="Why Fast?" speaker="David Antwi" duration="41:30" artworkColor="linear-gradient(135deg, #1a3a1a, #2d6a2d)" />,
    ],
  },
};

export const ContinueListening: Story = {
  args: {
    title: 'Continue Listening',
    children: [
      <SermonCard key="1" variant="grid" title="The Presence of God" speaker="David Antwi" duration="12:30 left" artworkColor="linear-gradient(135deg, #3a1078, #6b34fa)" progress={0.55} />,
      <SermonCard key="2" variant="grid" title="God Knows How To Protect" speaker="David Antwi" duration="8:45 left" artworkColor="linear-gradient(135deg, #1a2a4e, #2a4a7e)" progress={0.72} />,
    ],
  },
};
