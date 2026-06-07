/**
 * Kharis Design System — Colour Tokens
 *
 * SOURCED DIRECTLY from kharis.org computed styles.
 * Every hex value here was extracted from the live website.
 * Do not alter without re-verifying against the website.
 */

export interface ColorToken {
  name: string;
  hex: string;
  rgb: string;
  description: string;
}

export interface ColorGroup {
  group: string;
  colors: ColorToken[];
}

export const colors: ColorGroup[] = [
  {
    group: 'Brand',
    colors: [
      {
        name: 'Kharis Orange',
        hex: '#FD7F20',
        rgb: 'rgb(253, 127, 32)',
        description: 'Primary CTA colour. Every button on kharis.org uses this. Fasting Booklet, Watch More Messages, Listen to Messages, Donate Now, Share Your Testimony, Find a Branch — all #FD7F20.',
      },
      {
        name: 'Kharis Purple',
        hex: '#6B34FA',
        rgb: 'rgb(107, 52, 250)',
        description: 'Brand identity colour. Used on the dove logo, social media icon text, and nav logo. Not used for buttons — reserved for identity and accents.',
      },
      {
        name: 'Kharis Magenta',
        hex: '#800654',
        rgb: 'rgb(128, 6, 84)',
        description: 'Feature card icon colour. All icon-box icons (About Us, Locations, Young Adults, Become a Believer, Get Involved) use this at 50px.',
      },
    ],
  },
  {
    group: 'Buttons',
    colors: [
      {
        name: 'Button Background',
        hex: '#FD7F20',
        rgb: 'rgb(253, 127, 32)',
        description: 'Solid orange. All buttons. Font: Maven Pro, 14px, 700 weight, uppercase. Padding: 18px 40px. Border-radius: 12px. No shadow.',
      },
      {
        name: 'Button Text',
        hex: '#FFFFFF',
        rgb: 'rgb(255, 255, 255)',
        description: 'White text on all orange buttons.',
      },
      {
        name: 'Social Icon Background',
        hex: '#FD7F20',
        rgb: 'rgb(253, 127, 32)',
        description: 'Social media circles (YouTube, Facebook, Twitter, Instagram) in footer — orange background, 50% border-radius (circle).',
      },
      {
        name: 'Social Icon Foreground',
        hex: '#6B34FA',
        rgb: 'rgb(107, 52, 250)',
        description: 'Social media icon colour — purple on orange background.',
      },
    ],
  },
  {
    group: 'Text',
    colors: [
      {
        name: 'Heading Dark',
        hex: '#32363D',
        rgb: 'rgb(50, 54, 61)',
        description: 'Section headings on light background: Latest Messages, Build God a House, Testimonies, Kharis Near You. Also icon-box titles (About Us, Locations, etc).',
      },
      {
        name: 'Heading Hero',
        hex: '#FFFFFF',
        rgb: 'rgb(255, 255, 255)',
        description: 'Hero section headings on image overlay: WELCOME TO KHARIS, tagline.',
      },
      {
        name: 'Body Near-Black',
        hex: '#000002',
        rgb: 'rgb(0, 0, 2)',
        description: 'Nav links, some sub-headings. Near-black. Used for menu items in DM Sans 12px bold uppercase.',
      },
      {
        name: 'Body Grey',
        hex: '#7A7A7A',
        rgb: 'rgb(122, 122, 122)',
        description: 'Body text, sub-nav items, descriptions. The most common text colour on the site.',
      },
      {
        name: 'Body Muted',
        hex: '#999999',
        rgb: 'rgb(153, 153, 153)',
        description: 'Secondary muted text.',
      },
      {
        name: 'Body Dark Alt',
        hex: '#5F626A',
        rgb: 'rgb(95, 98, 106)',
        description: 'Alternative body text shade.',
      },
    ],
  },
  {
    group: 'Surface',
    colors: [
      {
        name: 'Page Background',
        hex: '#FFFFFF',
        rgb: 'rgb(255, 255, 255)',
        description: 'Main page background.',
      },
      {
        name: 'Section Alt',
        hex: '#F9FAFE',
        rgb: 'rgb(249, 250, 254)',
        description: 'Alternate section background (light blue-grey tint).',
      },
      {
        name: 'Card Background',
        hex: '#FDFDFD',
        rgb: 'rgb(253, 253, 253)',
        description: 'Feature cards with 15px border-radius and box-shadow: rgba(0,0,0,0.18) 0 0 30px.',
      },
      {
        name: 'Card Shadow',
        hex: 'rgba(0,0,0,0.18)',
        rgb: 'rgba(0, 0, 0, 0.18)',
        description: 'Card box-shadow: 0px 0px 30px 0px rgba(0,0,0,0.18).',
      },
      {
        name: 'Overlay',
        hex: 'rgba(0,0,0,0.6)',
        rgb: 'rgba(0, 0, 0, 0.6)',
        description: 'Dark overlay on hero/banner sections.',
      },
      {
        name: 'Dark Accent',
        hex: '#141B38',
        rgb: 'rgb(20, 27, 56)',
        description: 'Deep navy. Used sparingly for dark sections.',
      },
      {
        name: 'Dark Charcoal',
        hex: '#202124',
        rgb: 'rgb(32, 33, 36)',
        description: 'Near-black for dark UI elements.',
      },
    ],
  },
];

/** Flat lookup by name */
export const colorMap: Record<string, string> = {};
colors.forEach(g => g.colors.forEach(c => { colorMap[c.name] = c.hex; }));

/**
 * BUTTON SPEC (from kharis.org — all 6 CTA buttons are identical):
 *
 *   background: #FD7F20 (solid, no gradient)
 *   color: #FFFFFF
 *   font-family: "Maven Pro", sans-serif
 *   font-size: 14px
 *   font-weight: 700
 *   text-transform: uppercase
 *   padding: 18px 40px
 *   border-radius: 12px
 *   border: none
 *   box-shadow: none
 *   letter-spacing: normal
 *
 * There is NO secondary/ghost/outline button on the website.
 * All buttons are the same style.
 */
