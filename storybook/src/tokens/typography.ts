export interface FontFamily {
  name: string;
  stack: string;
  weights: number[];
  source: string;
}

export interface TypeScaleEntry {
  name: string;
  size: number;
  weight: number;
  lineHeight: number;
  letterSpacing: string;
  font: 'heading' | 'body';
  usage: string;
}

export interface Typography {
  fontFamilies: {
    heading: FontFamily;
    body: FontFamily;
  };
  typeScale: TypeScaleEntry[];
}

export const fontFamilies: Typography['fontFamilies'] = {
  heading: {
    name: 'Maven Pro',
    stack: "'Maven Pro', sans-serif",
    weights: [400, 500, 600, 700, 800],
    source: 'Google Fonts',
  },
  body: {
    name: 'DM Sans',
    stack: "'DM Sans', sans-serif",
    weights: [400, 500, 600, 700],
    source: 'Google Fonts',
  },
};

export const typeScale: TypeScaleEntry[] = [
  {
    name: 'Display',
    size: 32,
    weight: 800,
    lineHeight: 1.2,
    letterSpacing: '-0.02em',
    font: 'heading',
    usage: 'Hero headlines, splash screens, section openers.',
  },
  {
    name: 'H1',
    size: 28,
    weight: 700,
    lineHeight: 1.25,
    letterSpacing: '-0.015em',
    font: 'heading',
    usage: 'Page-level headings, primary titles.',
  },
  {
    name: 'H2',
    size: 22,
    weight: 700,
    lineHeight: 1.3,
    letterSpacing: '-0.01em',
    font: 'heading',
    usage: 'Section headings, card titles, modal headers.',
  },
  {
    name: 'H3',
    size: 18,
    weight: 600,
    lineHeight: 1.35,
    letterSpacing: '-0.005em',
    font: 'heading',
    usage: 'Sub-section headings, list group labels.',
  },
  {
    name: 'Body',
    size: 16,
    weight: 400,
    lineHeight: 1.6,
    letterSpacing: '0em',
    font: 'body',
    usage: 'Default body copy, descriptions, paragraphs.',
  },
  {
    name: 'Caption',
    size: 14,
    weight: 400,
    lineHeight: 1.5,
    letterSpacing: '0.01em',
    font: 'body',
    usage: 'Supporting text, metadata, image captions.',
  },
  {
    name: 'Overline',
    size: 12,
    weight: 600,
    lineHeight: 1.4,
    letterSpacing: '0.08em',
    font: 'body',
    usage: 'Labels above headings, category tags, table headers.',
  },
];
