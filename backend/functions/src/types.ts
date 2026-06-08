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
  source: 'soundcloud' | 'youtube';
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
  description: string;
  location: string;
  branch: string;
  startTime: Timestamp;
  endTime?: Timestamp;
  imageUrl?: string;
  isFeatured: boolean;
  createdAt: Timestamp;
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
  imageUrl?: string;
  publishedAt: Timestamp;
  expiresAt?: Timestamp;
}

// RSS feed types
export interface RssItem {
  title: string;
  description?: string;
  enclosure?: {
    '@_url': string;
    '@_length'?: string;
    '@_type'?: string;
  };
  pubDate?: string;
  'itunes:duration'?: string;
  'itunes:image'?: {
    '@_href': string;
  };
  link?: string;
  guid?: string | { '#text': string; '@_isPermaLink'?: string };
}

export interface RssFeed {
  rss: {
    channel: {
      title: string;
      item: RssItem | RssItem[];
    };
  };
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
