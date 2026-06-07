import type { Meta, StoryObj } from '@storybook/react';
import React from 'react';
import { EventCard } from '../../components/EventCard';

const meta: Meta<typeof EventCard> = {
  title: 'Components/EventCard',
  component: EventCard,
  parameters: {
    layout: 'padded',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    day: { control: 'text' },
    month: { control: 'text' },
    title: { control: 'text' },
    location: { control: 'text' },
    time: { control: 'text' },
    featured: { control: 'boolean' },
  },
};

export default meta;
type Story = StoryObj<typeof EventCard>;

export const Default: Story = {
  args: {
    day: '15',
    month: 'Jun',
    title: 'Sunday Morning Service',
    location: 'Main Sanctuary',
    time: '10:00 AM',
    featured: false,
  },
};

export const Featured: Story = {
  args: {
    day: '22',
    month: 'Jun',
    title: 'Annual Conference 2025',
    location: 'Grand Ballroom, Lagos',
    time: '9:00 AM',
    featured: true,
  },
};

export const Regular: Story = {
  args: {
    day: '18',
    month: 'Jun',
    title: 'Wednesday Bible Study',
    location: 'Room 204',
    time: '6:30 PM',
    featured: false,
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '12px',
        background: '#0D0D0D',
        padding: '24px',
        borderRadius: '16px',
        maxWidth: '480px',
      }}
    >
      <EventCard
        day="22"
        month="Jun"
        title="Annual Conference 2025"
        location="Grand Ballroom, Lagos"
        time="9:00 AM"
        featured={true}
      />
      <EventCard
        day="15"
        month="Jun"
        title="Sunday Morning Service"
        location="Main Sanctuary"
        time="10:00 AM"
        featured={false}
      />
      <EventCard
        day="18"
        month="Jun"
        title="Wednesday Bible Study"
        location="Room 204"
        time="6:30 PM"
        featured={false}
      />
      <EventCard
        day="25"
        month="Jun"
        title="Youth Night"
        location="Youth Hall"
        time="7:00 PM"
        featured={false}
      />
    </div>
  ),
};
