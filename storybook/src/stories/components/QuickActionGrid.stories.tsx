import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { QuickActionGrid } from '../../components/QuickActionGrid';

const meta: Meta<typeof QuickActionGrid> = {
  title: 'Components/QuickActionGrid',
  component: QuickActionGrid,
  parameters: { layout: 'centered', backgrounds: { default: 'dark' } },
  decorators: [(Story) => <div style={{ width: 350 }}><Story /></div>],
};
export default meta;
type Story = StoryObj<typeof QuickActionGrid>;

export const HomeActions: Story = {
  args: {
    columns: 2,
    actions: [
      { icon: '🎧', label: 'Listen', description: 'Latest sermons' },
      { icon: '📺', label: 'Watch', description: 'Video messages' },
      { icon: '💛', label: 'Give', description: 'Support the church' },
      { icon: '📅', label: 'Events', description: 'Upcoming services' },
    ],
  },
};

export const ThreeColumn: Story = {
  args: {
    columns: 3,
    actions: [
      { icon: '🎧', label: 'Listen' },
      { icon: '📺', label: 'Watch' },
      { icon: '💛', label: 'Give' },
      { icon: '📅', label: 'Events' },
      { icon: '📖', label: 'Bible' },
      { icon: '🙏', label: 'Prayer' },
    ],
  },
};
