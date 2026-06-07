import { addons } from 'storybook/manager-api';
import { create } from 'storybook/theming';

const kharisTheme = create({
  base: 'dark',
  brandTitle: 'Kharis Design System',
  brandUrl: 'https://kharis.org',
  brandTarget: '_blank',

  colorPrimary: '#6b34fa',
  colorSecondary: '#fd7f20',

  appBg: '#0D0D0D',
  appContentBg: '#1A1A1A',
  appBorderColor: '#252525',
  appBorderRadius: 8,

  textColor: '#FFFFFF',
  textInverseColor: '#0D0D0D',
  textMutedColor: '#A0A0A0',

  barTextColor: '#A0A0A0',
  barSelectedColor: '#fd7f20',
  barBg: '#1A1A1A',

  inputBg: '#252525',
  inputBorder: '#252525',
  inputTextColor: '#FFFFFF',
  inputBorderRadius: 8,
});

addons.setConfig({
  theme: kharisTheme,
});
