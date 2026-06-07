export interface GradientToken {
  name: string;
  css: string;
  description: string;
}

export interface Gradients {
  brandGlow: GradientToken;
  cardShimmer: GradientToken;
  goldAccent: GradientToken;
  heroOverlay: GradientToken;
}

export const gradients: Gradients = {
  brandGlow: {
    name: 'Brand Glow',
    css: 'linear-gradient(135deg, #6b34fa 0%, #800654 60%, #0D0D0D 100%)',
    description: 'Purple-to-magenta-to-dark sweep. Hero backgrounds, section openers, feature banners.',
  },
  cardShimmer: {
    name: 'Card Shimmer',
    css: 'linear-gradient(135deg, #1A1A1A 0%, #252525 50%, #1A1A1A 100%)',
    description: 'Subtle surface shimmer. Card hover states, skeleton loaders, elevated panels.',
  },
  goldAccent: {
    name: 'Gold Accent',
    css: 'linear-gradient(90deg, #fd7f20 0%, #f5c842 100%)',
    description: 'Warm gold sweep. Premium badges, event tier labels, giving highlights.',
  },
  heroOverlay: {
    name: 'Hero Overlay',
    css: 'linear-gradient(180deg, rgba(13,13,13,0) 0%, rgba(13,13,13,0.6) 50%, rgba(13,13,13,0.95) 100%)',
    description: 'Dark vignette overlay. Applied over hero photography to ensure legible text.',
  },
};
