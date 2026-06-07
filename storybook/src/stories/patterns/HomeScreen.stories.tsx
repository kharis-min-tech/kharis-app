import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { HomeHero } from '../../components/HomeHero';
import { QuickActionGrid } from '../../components/QuickActionGrid';
import { ContentRow } from '../../components/ContentRow';
import { SermonCard } from '../../components/SermonCard';
import { EventCard } from '../../components/EventCard';
import { ReadingCard } from '../../components/ReadingCard';
import { PrayerCard } from '../../components/PrayerCard';
import { MiniPlayer } from '../../components/MiniPlayer';
import { TabBar } from '../../components/TabBar';

/**
 * Home Screen — Full composition
 *
 * Colour theme: from kharis.org
 *   - CTAs: #FD7F20 (solid orange, Maven Pro 14px bold uppercase)
 *   - Identity: #6B34FA (purple, logo and accents only)
 *   - Icons: #800654 (magenta, feature icons)
 *   - Headings: #FFFFFF on dark, #32363D on light
 *   - Body: #7A7A7A
 *   - Background: #0D0D0D
 *
 * Layout pattern: Headspace + Calm + MasterClass
 * Ref:
 *   Headspace home: https://mobbin.com/screens/d95b9be8-a5b8-4995-9196-ae15e24a722c
 *   Calm home: https://mobbin.com/screens/5b9b6c86-2309-4409-ae4d-e28940bb694e
 *   MasterClass: https://mobbin.com/screens/3f997cfa-8542-4c40-9290-abe6c67fe0bb
 *   Fabulous: https://mobbin.com/screens/42cf205c-3d6e-4bd9-bfed-7e5beecb7e9a
 */

const PlayIcon = () => (
  <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor">
    <path d="M8 5v14l11-7z" />
  </svg>
);

const HomeScreen = () => (
  <div style={{
    width: 390,
    minHeight: 844,
    backgroundColor: '#0D0D0D',
    borderRadius: 44,
    overflow: 'hidden',
    position: 'relative',
    boxShadow: '0 0 0 3px #333, 0 20px 60px rgba(0,0,0,0.8)',
    fontFamily: '"DM Sans", sans-serif',
  }}>
    {/* Status bar */}
    <div style={{
      display: 'flex',
      justifyContent: 'space-between',
      alignItems: 'center',
      padding: '14px 28px 0',
      fontSize: 15,
      fontWeight: 600,
      color: '#FFFFFF',
      height: 54,
    }}>
      <span>9:41</span>
      <div style={{
        width: 126, height: 34,
        background: '#000', borderRadius: 20,
        position: 'absolute', top: 0, left: '50%',
        transform: 'translateX(-50%)',
      }} />
      <span style={{ fontSize: 12 }}>🔋</span>
    </div>

    {/* Scrollable content */}
    <div style={{
      height: 'calc(100% - 54px - 140px)',
      overflowY: 'auto',
      scrollbarWidth: 'none',
    }}>
      {/* Greeting */}
      <div style={{ padding: '16px 20px 8px' }}>
        <div style={{ fontSize: 14, color: '#7A7A7A' }}>Good evening</div>
        <div style={{
          fontFamily: '"Maven Pro", sans-serif',
          fontSize: 26, fontWeight: 700, color: '#FFFFFF',
        }}>
          Welcome back ✨
        </div>
      </div>

      {/* Hero */}
      <div style={{ padding: '0 20px 20px' }}>
        <HomeHero
          badge="21 Days Fasting"
          isLive={true}
          title="Prayer & Fasting Service"
          subtitle="1st – 21st June 2026 · All Branches"
          ctaLabel="Watch Live"
          ctaIcon={<PlayIcon />}
        />
      </div>

      {/* Today's Reading */}
      <div style={{ padding: '0 20px 20px' }}>
        <ReadingCard label="Today's Reading" verse="Revelation 7" />
      </div>

      {/* Quick Actions */}
      <div style={{ padding: '0 20px 24px' }}>
        <QuickActionGrid
          columns={2}
          actions={[
            { icon: '🎧', label: 'Listen', description: 'Latest sermons' },
            { icon: '📺', label: 'Watch', description: 'Video messages' },
            { icon: '💛', label: 'Give', description: 'Support the church' },
            { icon: '📅', label: 'Events', description: 'Upcoming services' },
          ]}
        />
      </div>

      {/* Latest Sermons */}
      <ContentRow title="Latest Sermons" onSeeAll={() => {}}>
        <SermonCard
          variant="grid"
          title="The Presence of God"
          speaker="David Antwi"
          duration="29:15"
          artworkColor="linear-gradient(135deg, #3a1078, #6b34fa)"
        />
        <SermonCard
          variant="grid"
          title="Have a Pure Heart"
          speaker="David Antwi"
          duration="34:02"
          artworkColor="linear-gradient(135deg, #800654, #b91c8a)"
        />
        <SermonCard
          variant="grid"
          title="Why Fast?"
          speaker="David Antwi"
          duration="41:30"
          artworkColor="linear-gradient(135deg, #1a3a1a, #2d6a2d)"
        />
      </ContentRow>

      {/* Upcoming Events */}
      <div style={{ padding: '0 20px' }}>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          marginBottom: 14,
        }}>
          <h2 style={{
            fontFamily: '"Maven Pro", sans-serif',
            fontSize: 20, fontWeight: 600, color: '#FFFFFF', margin: 0,
          }}>
            Upcoming Events
          </h2>
          <button style={{
            background: 'none', border: 'none',
            fontSize: 13, fontWeight: 500, color: '#FD7F20',
            cursor: 'pointer', padding: 0,
            fontFamily: '"DM Sans", sans-serif',
          }}>
            See All
          </button>
        </div>
        <EventCard
          day="08"
          month="Jun"
          title="Prayer & Fasting Service"
          location="📍 Leigh Academy, Rainham"
          time="7:00 PM"
        />
        <EventCard
          day="14"
          month="Jun"
          title="Sunday Service"
          location="📍 Strood Academy, Rochester"
          time="10:30 AM"
          featured
        />
      </div>

      {/* Daily Prayer */}
      <div style={{ padding: '16px 0' }}>
        <PrayerCard
          text="Pray that like Paul, your faith in God will be unwavering in every season and that God will grant you the endurance to finish well."
          reference="— Acts 24"
        />
      </div>

      {/* Message of the Day */}
      <ContentRow title="Message of the Day" onSeeAll={() => {}}>
        <SermonCard
          variant="grid"
          title="Effective Prayer"
          speaker="David Antwi"
          duration="29:15"
          artworkColor="linear-gradient(135deg, #2a1a4e, #5a3a7e)"
          progress={0.55}
        />
      </ContentRow>

      <div style={{ height: 20 }} />
    </div>

    {/* Mini Player */}
    <div style={{
      position: 'absolute',
      bottom: 82,
      left: 8, right: 8,
    }}>
      <MiniPlayer
        title="The Presence of God"
        artist="David Antwi"
        isPlaying={true}
        progress={0.65}
      />
    </div>

    {/* Tab Bar */}
    <div style={{
      position: 'absolute',
      bottom: 0,
      left: 0, right: 0,
    }}>
      <TabBar
        activeTab={0}
        tabs={[
          { label: 'Home', icon: '🏠' },
          { label: 'Messages', icon: '💬' },
          { label: 'Giving', icon: '💛' },
          { label: 'Calendar', icon: '📅' },
          { label: 'More', icon: '☰' },
        ]}
      />
    </div>
  </div>
);

const meta: Meta = {
  title: 'Patterns/Home Screen',
  component: HomeScreen,
  parameters: {
    layout: 'centered',
    backgrounds: { default: 'dark' },
  },
};
export default meta;

type Story = StoryObj;

export const FullComposition: Story = {};
