import React from 'react';
import type { Meta, StoryObj } from '@storybook/react';

const DesignPhilosophy = () => (
  <div style={{
    maxWidth: 800,
    color: '#FFFFFF',
    fontFamily: 'DM Sans, sans-serif',
    padding: 40,
  }}>
    <h1 style={{ fontFamily: 'Maven Pro', fontSize: 32, marginBottom: 8 }}>
      Design Philosophy
    </h1>
    <p style={{ color: '#A0A0A0', fontSize: 16, lineHeight: 1.6, marginBottom: 40 }}>
      The old Kharis app is the anti-pattern. Every design decision in this system
      exists because the old app got it wrong. We studied 108 screens across 40+ premium
      apps on Mobbin to define what "right" looks like.
    </p>

    <h2 style={{ fontFamily: 'Maven Pro', fontSize: 22, color: '#fd7f20', marginBottom: 24 }}>
      What We're Fixing
    </h2>

    <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginBottom: 48 }}>
      {[
        {
          old: 'White backgrounds mixed with dark headers — jarring split',
          new: 'Full dark mode (#0D0D0D) — consistent, premium, immersive',
          ref: 'Spotify, Netflix, Waking Up',
        },
        {
          old: 'YouTube embeds with red play button — feels external and cheap',
          new: 'Native video player with custom controls — no third-party watermarks',
          ref: 'Netflix player, HBO Max, Prime Video',
        },
        {
          old: 'Bank details displayed in plaintext on Giving screen',
          new: 'WebView to Kharis giving site with amount pre-selection and branded loading',
          ref: 'Vivid, Revolut, Monzo amount selectors',
        },
        {
          old: '"Calender" typo in the tab bar — visible on every screen',
          new: 'Correct spelling + gold active state + filled/outlined icon states',
          ref: 'Insight Timer, Spotify tab bars',
        },
        {
          old: 'Flat card list with no hierarchy — everything looks the same weight',
          new: 'Hero banner → horizontal scroll sections → event cards → prayer cards',
          ref: 'Netflix browse, Paramount+ home, MasterClass',
        },
        {
          old: 'No mini player — audio context lost when navigating',
          new: 'Persistent 56px mini player above tab bar with gold progress line',
          ref: 'Spotify mini player (4 variants studied)',
        },
        {
          old: 'Off-brand teal colour on Giving — matches nothing',
          new: 'Consistent palette: purple (#6b34fa) + gold (#fd7f20) everywhere',
          ref: 'Extracted from kharis.org brand identity',
        },
        {
          old: 'Sermon thumbnails with text baked into images — cluttered, unreadable',
          new: 'Clean sermon cards: thumbnail + app-rendered title + speaker + duration',
          ref: 'Spotify podcast episodes, SoundCloud tracks',
        },
        {
          old: 'Static dove logo — no personality',
          new: 'Animated dove with purple glow radial gradient on splash',
          ref: 'Any Distance, Medium, Wise splash screens',
        },
        {
          old: 'Calendar as a flat list of identical cards — no grouping, no imagery',
          new: 'Branch-filtered events with "This Week" / "Coming Up" groups and service times bar',
          ref: 'Luma events, Clubhouse upcoming',
        },
      ].map((item, i) => (
        <div key={i} style={{
          background: '#1A1A1A',
          borderRadius: 12,
          padding: 20,
          display: 'grid',
          gridTemplateColumns: '1fr 1fr',
          gap: 20,
        }}>
          <div>
            <div style={{
              fontSize: 11,
              fontWeight: 600,
              color: '#EF4444',
              textTransform: 'uppercase',
              letterSpacing: 1,
              marginBottom: 6,
            }}>
              ✗ Old App
            </div>
            <div style={{ fontSize: 14, color: '#A0A0A0', lineHeight: 1.5 }}>
              {item.old}
            </div>
          </div>
          <div>
            <div style={{
              fontSize: 11,
              fontWeight: 600,
              color: '#22C55E',
              textTransform: 'uppercase',
              letterSpacing: 1,
              marginBottom: 6,
            }}>
              ✓ New Design
            </div>
            <div style={{ fontSize: 14, color: '#FFFFFF', lineHeight: 1.5 }}>
              {item.new}
            </div>
            <div style={{
              fontSize: 11,
              color: '#fd7f20',
              marginTop: 4,
            }}>
              Ref: {item.ref}
            </div>
          </div>
        </div>
      ))}
    </div>

    <h2 style={{ fontFamily: 'Maven Pro', fontSize: 22, color: '#6b34fa', marginBottom: 24 }}>
      Mobbin Reference Map
    </h2>
    <p style={{ color: '#A0A0A0', fontSize: 14, lineHeight: 1.6, marginBottom: 16 }}>
      Every screen in this app has a corresponding set of real-world references.
      No screen is designed from imagination — it's derived from studying what
      premium apps do well. Full reference map: <code style={{ color: '#fd7f20' }}>MOBBIN-REFERENCES.md</code>
    </p>

    <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 12 }}>
      {[
        { screen: 'Splash', apps: 'Any Distance, Medium, Wise', count: 6 },
        { screen: 'Role Selection', apps: 'Fiverr, Canva, Remind', count: 6 },
        { screen: 'Branch Picker', apps: 'lululemon, Subway, Best Buy', count: 6 },
        { screen: 'Home Dashboard', apps: 'Fabric, Believe, Netflix', count: 9 },
        { screen: 'Sermon Library', apps: 'Spotify, IDAGIO, SoundCloud', count: 8 },
        { screen: 'Full Player', apps: 'Spotify, Waking Up', count: 5 },
        { screen: 'Mini Player', apps: 'Spotify (4 variants)', count: 4 },
        { screen: 'Video Player', apps: 'HBO Max, Netflix, Prime', count: 6 },
        { screen: 'Calendar', apps: 'Luma, Clubhouse', count: 5 },
        { screen: 'Giving', apps: 'Vivid, Revolut, Monzo', count: 6 },
        { screen: 'Settings', apps: 'Calm, Orbit, Fitness', count: 5 },
        { screen: 'Notifications', apps: 'Linear, Notion, Reddit', count: 4 },
        { screen: 'Daily Reading', apps: 'Deepstash, Calm, Moonly', count: 5 },
        { screen: 'Notes Editor', apps: 'Apple Notes, Freeform', count: 4 },
        { screen: 'Discipleship', apps: 'Fabulous, Noom, Ahead', count: 5 },
        { screen: 'Live Stream', apps: 'HQ Trivia, Binance', count: 5 },
      ].map((item, i) => (
        <div key={i} style={{
          background: '#252525',
          borderRadius: 8,
          padding: 12,
        }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: '#FFFFFF' }}>
            {item.screen}
          </div>
          <div style={{ fontSize: 12, color: '#A0A0A0', marginTop: 2 }}>
            {item.apps}
          </div>
          <div style={{ fontSize: 11, color: '#666666', marginTop: 2 }}>
            {item.count} references studied
          </div>
        </div>
      ))}
    </div>

    <div style={{
      marginTop: 48,
      padding: 20,
      background: 'rgba(107, 52, 250, 0.1)',
      border: '1px solid rgba(107, 52, 250, 0.2)',
      borderRadius: 12,
    }}>
      <h3 style={{ fontFamily: 'Maven Pro', fontSize: 18, marginBottom: 8 }}>
        The Rule
      </h3>
      <p style={{ color: '#A0A0A0', fontSize: 15, lineHeight: 1.6, margin: 0 }}>
        If you can't point to a Mobbin reference for a design decision, the decision
        hasn't been validated. Every component, layout, and interaction pattern must
        trace back to a studied example from a shipped, premium app.
      </p>
    </div>
  </div>
);

const meta: Meta = {
  title: 'Patterns/Design Philosophy',
  component: DesignPhilosophy,
  parameters: {
    layout: 'fullscreen',
    backgrounds: { default: 'dark' },
  },
};
export default meta;

type Story = StoryObj;

export const OldVsNew: Story = {};
