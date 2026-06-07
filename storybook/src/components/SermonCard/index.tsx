import React from 'react';
import { SermonCardGrid } from './SermonCardGrid';
import { SermonCardList } from './SermonCardList';
import type { SermonCardProps } from './types';

export type { SermonCardProps } from './types';
export { SermonCardGrid } from './SermonCardGrid';
export { SermonCardList } from './SermonCardList';
export { EqualizerIcon } from './EqualizerIcon';
export { ProgressBar } from './ProgressBar';

/**
 * SermonCard - convenience wrapper that routes to Grid or List.
 *
 * Prefer importing SermonCardGrid or SermonCardList directly
 * when the variant is known at the call site.
 */
export const SermonCard: React.FC<SermonCardProps & { variant?: 'grid' | 'list' }> = ({
  variant = 'grid',
  ...props
}) => variant === 'grid'
  ? <SermonCardGrid {...props} />
  : <SermonCardList {...props} />;
