import type { Meta, StoryObj } from '@storybook/react';
import React, { useState } from 'react';
import { SettingsItem } from '../../components/SettingsItem';

const meta: Meta<typeof SettingsItem> = {
  title: 'Components/SettingsItem',
  component: SettingsItem,
  parameters: {
    layout: 'padded',
    backgrounds: { default: 'dark' },
  },
  argTypes: {
    icon: { control: 'text' },
    label: { control: 'text' },
    value: { control: 'text' },
    hasToggle: { control: 'boolean' },
    toggleOn: { control: 'boolean' },
    hasArrow: { control: 'boolean' },
    onToggle: { action: 'toggled' },
  },
};

export default meta;
type Story = StoryObj<typeof SettingsItem>;

export const Default: Story = {
  args: {
    icon: '👤',
    label: 'Account',
    hasArrow: true,
  },
};

export const WithValue: Story = {
  args: {
    icon: '🌍',
    label: 'Language',
    value: 'English',
    hasArrow: true,
  },
};

export const WithToggleOn: Story = {
  args: {
    icon: '🔔',
    label: 'Push Notifications',
    hasToggle: true,
    toggleOn: true,
  },
};

export const WithToggleOff: Story = {
  args: {
    icon: '📧',
    label: 'Email Updates',
    hasToggle: true,
    toggleOn: false,
  },
};

export const StaticValue: Story = {
  args: {
    icon: '📱',
    label: 'App Version',
    value: '2.4.1',
    hasArrow: false,
    hasToggle: false,
  },
};

export const Interactive: Story = {
  render: () => {
    const InteractiveItem = () => {
      const [on, setOn] = useState(false);
      return (
        <div style={{ maxWidth: '400px', width: '100%' }}>
          <SettingsItem
            icon="🔔"
            label="Push Notifications"
            hasToggle
            toggleOn={on}
            onToggle={() => setOn((v) => !v)}
          />
        </div>
      );
    };
    return <InteractiveItem />;
  },
};

export const Showcase: Story = {
  render: () => (
    <div
      style={{
        background: '#1A1A1A',
        borderRadius: '16px',
        overflow: 'hidden',
        maxWidth: '400px',
        width: '100%',
      }}
    >
      <div style={{ borderBottom: '1px solid #252525' }}>
        <SettingsItem icon="👤" label="Profile" hasArrow />
      </div>
      <div style={{ borderBottom: '1px solid #252525' }}>
        <SettingsItem icon="🌍" label="Language" value="English" hasArrow />
      </div>
      <div style={{ borderBottom: '1px solid #252525' }}>
        <SettingsItem icon="🔔" label="Push Notifications" hasToggle toggleOn={true} />
      </div>
      <div style={{ borderBottom: '1px solid #252525' }}>
        <SettingsItem icon="📧" label="Email Updates" hasToggle toggleOn={false} />
      </div>
      <div style={{ borderBottom: '1px solid #252525' }}>
        <SettingsItem icon="🎨" label="Theme" value="Dark" hasArrow />
      </div>
      <div>
        <SettingsItem icon="📱" label="App Version" value="2.4.1" />
      </div>
    </div>
  ),
};
