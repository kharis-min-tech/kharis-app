import { Timestamp } from 'firebase-admin/firestore';

export interface SermonDoc {
  id?: string;
  title: string;
  speaker: string;
  description: string;
  audioUrl: string;
  videoId?: string;
  thumbnailUrl?: string;
  duration: number; // seconds
  publishedAt: Timestamp;
  source: 'youtube';
  type: 'audio' | 'video';
  series?: string;
  category?: string;
  playCount: number;
  createdAt: Timestamp;
  updatedAt: Timestamp;
}

export interface EventDoc {
  id?: string;
  title: string;
  description?: string | null;
  /** Venue name, e.g. "Kensington Town Hall". */
  location?: string | null;
  /** Street address of the venue. */
  address?: string | null;
  /** Campus name; null, absent or blank = all-campus. */
  branch?: string | null;
  startTime: Timestamp;
  endTime?: Timestamp | null;
  imageUrl?: string | null;
  isFeatured?: boolean;
  createdAt?: Timestamp;
}

export interface DailyContentDoc {
  id: string; // date string: 'YYYY-MM-DD'
  reading: {
    book: string;
    chapter: string;
    verse?: string;
  };
  prayer: string;
  prayerReference: string;
  createdAt: Timestamp;
}

export interface NewsDoc {
  id?: string;
  title: string;
  body: string;
  type?: string;
  branch?: string | null;
  imageUrl?: string | null;
  publishedAt: Timestamp;
  expiresAt?: Timestamp | null;
  /** `events/{eventId}` this announcement promotes. */
  eventId?: string | null;
  /** Optional call-to-action link (http/https) and its button label. */
  linkUrl?: string | null;
  ctaLabel?: string | null;
}

// YouTube API types
export interface YouTubeSearchItem {
  id: { videoId: string };
  snippet: {
    title: string;
    description: string;
    publishedAt: string;
    thumbnails: {
      high?: { url: string };
      default?: { url: string };
    };
    channelId: string;
  };
}

export interface YouTubeVideoDetails {
  id: string;
  contentDetails: {
    duration: string; // ISO 8601 duration e.g. PT4M13S
  };
}

export interface YouTubeSearchResponse {
  items: YouTubeSearchItem[];
  nextPageToken?: string;
}

export interface YouTubeVideosResponse {
  items: YouTubeVideoDetails[];
}
