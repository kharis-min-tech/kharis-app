import type { Meta, StoryObj } from '@storybook/react';
import React from 'react';
import { Button } from '../../components/Button';

const meta: Meta<typeof Button> = {
  title: 'Components/Button',
  component: Button,
  parameters: {
    layout: 'centered',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    variant: {
      control: 'select',
      options: ['primary', 'secondary', 'ghost', 'destructive'],
    },
    size: {
      control: 'select',
      options: ['sm', 'md', 'lg'],
    },
    disabled: { control: 'boolean' },
    onClick: { action: 'clicked' },
  },
};

export default meta;
type Story = StoryObj<typeof Button>;

export const Default: Story = {
  args: {
    variant: 'primary',
    size: 'md',
    children: 'Get Started',
  },
};

export const Primary: Story = {
  args: { variant: 'primary', size: 'md', children: 'Join the Church' },
};

export const Secondary: Story = {
  args: { variant: 'secondary', size: 'md', children: 'Learn More' },
};

export const Ghost: Story = {
  args: { variant: 'ghost', size: 'md', children: 'Cancel' },
};

export const Destructive: Story = {
  args: { variant: 'destructive', size: 'md', children: 'Delete Account' },
};

export const Disabled: Story = {
  args: { variant: 'primary', size: 'md', children: 'Unavailable', disabled: true },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '20px',
        alignItems: 'center',
        background: '#0D0D0D',
        padding: '32px',
        borderRadius: '16px',
      }}
    >
      {(['lg', 'md', 'sm'] as const).map((size) => (
        <div key={size} style={{ display: 'flex', gap: '12px', flexWrap: 'wrap', justifyContent: 'center' }}>
          <Button variant="primary" size={size}>Primary {size.toUpperCase()}</Button>
          <Button variant="secondary" size={size}>Secondary {size.toUpperCase()}</Button>
          <Button variant="ghost" size={size}>Ghost {size.toUpperCase()}</Button>
          <Button variant="destructive" size={size}>Destructive {size.toUpperCase()}</Button>
        </div>
      ))}
      <div style={{ display: 'flex', gap: '12px' }}>
        <Button variant="primary" disabled>Disabled</Button>
        <Button variant="secondary" disabled>Disabled</Button>
      </div>
    </div>
  ),
};
