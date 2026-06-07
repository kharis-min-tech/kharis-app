import type { Meta, StoryObj } from '@storybook/react';
import React, { useState } from 'react';
import { TabBar } from '../../components/TabBar';

const HOME_ICON = `<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><path d="M10 2.5L2 9h2v8.5h4.5v-5h3v5H16V9h2L10 2.5z"/></svg>`;
const SERMON_ICON = `<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><rect x="3" y="4" width="10" height="1.5" rx="0.75"/><rect x="3" y="7.5" width="8" height="1.5" rx="0.75"/><rect x="3" y="11" width="6" height="1.5" rx="0.75"/><circle cx="15" cy="13" r="3.5" stroke="currentColor" stroke-width="1.5" fill="none"/><path d="M17.5 15.5l2 2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`;
const EVENTS_ICON = `<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><rect x="3" y="5" width="14" height="12" rx="2" stroke="currentColor" stroke-width="1.5" fill="none"/><path d="M7 3v3M13 3v3M3 9h14" stroke="currentColor" stroke-width="1.5" stroke-linecap="round"/></svg>`;
const GIVE_ICON = `<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><path d="M10 17s-7-4.5-7-9a5 5 0 0110 0c0 4.5-3 9-3 9z" stroke="currentColor" stroke-width="1.5" fill="none"/><circle cx="10" cy="8" r="2" fill="currentColor"/></svg>`;
const MORE_ICON = `<svg width="20" height="20" viewBox="0 0 20 20" fill="currentColor"><circle cx="5" cy="10" r="1.5"/><circle cx="10" cy="10" r="1.5"/><circle cx="15" cy="10" r="1.5"/></svg>`;

const TABS = [
  { label: 'Home', icon: HOME_ICON },
  { label: 'Sermons', icon: SERMON_ICON },
  { label: 'Events', icon: EVENTS_ICON },
  { label: 'Give', icon: GIVE_ICON },
  { label: 'More', icon: MORE_ICON },
];

const meta: Meta<typeof TabBar> = {
  title: 'Components/TabBar',
  component: TabBar,
  parameters: {
    layout: 'padded',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    activeTab: {
      control: { type: 'range', min: 0, max: 4, step: 1 },
    },
  },
};

export default meta;
type Story = StoryObj<typeof TabBar>;

export const Default: Story = {
  args: {
    activeTab: 0,
    tabs: TABS,
  },
};

export const SermonsActive: Story = {
  args: {
    activeTab: 1,
    tabs: TABS,
  },
};

export const EventsActive: Story = {
  args: {
    activeTab: 2,
    tabs: TABS,
  },
};

export const Interactive: Story = {
  render: () => {
    const InteractiveTabBar = () => {
      const [active, setActive] = useState(0);
      return (
        <div style={{ maxWidth: '400px', width: '100%' }}>
          <TabBar tabs={TABS} activeTab={active} onTabChange={setActive} />
        </div>
      );
    };
    return <InteractiveTabBar />;
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '24px',
        background: '#0D0D0D',
        padding: '24px',
        borderRadius: '16px',
        maxWidth: '400px',
      }}
    >
      {[0, 1, 2, 3, 4].map((i) => (
        <div key={i}>
          <div style={{ fontSize: '11px', color: '#666', fontFamily: 'DM Sans', marginBottom: '6px' }}>
            Active: {TABS[i].label}
          </div>
          <TabBar tabs={TABS} activeTab={i} />
        </div>
      ))}
    </div>
  ),
};
