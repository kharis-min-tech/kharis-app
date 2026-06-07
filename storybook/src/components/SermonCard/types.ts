export interface SermonCardProps {
  title: string;
  speaker: string;
  duration?: string;
  artworkColor?: string;
  isPlaying?: boolean;
  /** 0-1 resume position. Shows progress bar when > 0. */
  progress?: number;
}

export const DEFAULT_ARTWORK = 'linear-gradient(135deg, #6b34fa 0%, #800654 100%)';
