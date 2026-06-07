export interface SpacingToken {
  name: string;
  value: number;
  rem: string;
  usage: string;
}

export interface RadiiToken {
  name: string;
  value: number;
  css: string;
  usage: string;
}

export const spacingScale: SpacingToken[] = [
  { name: 'space-1', value: 4,  rem: '0.25rem', usage: 'Micro gap. Icon padding, tight inline spacing.' },
  { name: 'space-2', value: 8,  rem: '0.5rem',  usage: 'XSmall. Badge padding, compact list gaps.' },
  { name: 'space-3', value: 12, rem: '0.75rem', usage: 'Small. Input padding, tight component gaps.' },
  { name: 'space-4', value: 16, rem: '1rem',    usage: 'Base unit. Default padding, standard gutters.' },
  { name: 'space-5', value: 20, rem: '1.25rem', usage: 'Medium-small. Button padding, card internal spacing.' },
  { name: 'space-6', value: 24, rem: '1.5rem',  usage: 'Medium. Section inner padding, card padding.' },
  { name: 'space-8', value: 32, rem: '2rem',    usage: 'Large. Component group gaps, modal padding.' },
  { name: 'space-10',value: 40, rem: '2.5rem',  usage: 'XLarge. Major section spacing, hero padding.' },
  { name: 'space-12',value: 48, rem: '3rem',    usage: '2XLarge. Section separators, hero inner spacing.' },
  { name: 'space-16',value: 64, rem: '4rem',    usage: '3XLarge. Large section margins, page-level spacing.' },
  { name: 'space-20',value: 80, rem: '5rem',    usage: '4XLarge. Hero sections, full-page top padding.' },
];

export const radiiScale: RadiiToken[] = [
  { name: 'radius-sm',   value: 4,    css: '4px',     usage: 'Subtle rounding. Tags, small chips, input corners.' },
  { name: 'radius-md',   value: 8,    css: '8px',     usage: 'Default. Buttons, cards, dropdowns.' },
  { name: 'radius-lg',   value: 12,   css: '12px',    usage: 'Generous rounding. Modals, larger cards.' },
  { name: 'radius-xl',   value: 16,   css: '16px',    usage: 'Large. Sheet panels, featured cards.' },
  { name: 'radius-2xl',  value: 24,   css: '24px',    usage: 'XLarge. Hero banners, bottom sheets.' },
  { name: 'radius-pill', value: 9999, css: '9999px',  usage: 'Full pill. Badges, status chips, toggle tracks.' },
];
