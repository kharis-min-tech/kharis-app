import type { Meta, StoryObj } from '@storybook/react';
import React, { useState } from 'react';
import { ChipFilter } from '../../components/ChipFilter';

const meta: Meta<typeof ChipFilter> = {
  title: 'Components/ChipFilter',
  component: ChipFilter,
  parameters: {
    layout: 'centered',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    active: { control: 'boolean' },
    label: { control: 'text' },
    onClick: { action: 'clicked' },
  },
};

export default meta;
type Story = StoryObj<typeof ChipFilter>;

export const Default: Story = {
  args: { label: 'All Sermons', active: false },
};

export const Active: Story = {
  args: { label: 'All Sermons', active: true },
};

export const Inactive: Story = {
  args: { label: 'Sunday Service', active: false },
};

export const Interactive: Story = {
  render: () => {
    const FilterGroup = () => {
      const [active, setActive] = useState(0);
      const labels = ['All', 'Sunday', 'Wednesday', 'Youth', 'Special'];
      return (
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {labels.map((label, i) => (
            <ChipFilter
              key={label}
              label={label}
              active={active === i}
              onClick={() => setActive(i)}
            />
          ))}
        </div>
      );
    };
    return <FilterGroup />;
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
      }}
    >
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
        <ChipFilter label="All" active={true} />
        <ChipFilter label="Sunday" active={false} />
        <ChipFilter label="Wednesday" active={false} />
        <ChipFilter label="Youth" active={false} />
        <ChipFilter label="Special Events" active={false} />
      </div>
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
        <ChipFilter label="All" active={false} />
        <ChipFilter label="Sunday" active={true} />
        <ChipFilter label="Wednesday" active={false} />
      </div>
    </div>
  ),
};
