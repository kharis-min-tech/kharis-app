import { test } from 'node:test';
import assert from 'node:assert/strict';
import { Timestamp } from 'firebase-admin/firestore';
import {
  campusesFor,
  changedFields,
  monthRequestBody,
  parseCalendarConfig,
  parseEventonResponse,
  webEventDocId,
} from '../src/sync-website-events';

// Shapes copied from kharis.org (EventON Lite 2.5.9), trimmed.
const PAGE = `<script>var evo_general_params = {"ajaxurl":"https://kharis.org/wp-admin/admin-ajax.php","evo_ajax_url":"/?evo-ajax=%%endpoint%%","rurl":"https://kharis.org/wp-json/","n":"9dfdf3c8a8","nonce":"01a4117a2f"};</script>
<div class='evo_cal_data' data-sc='{&quot;calendar_type&quot;:&quot;default&quot;,&quot;event_type&quot;:&quot;all&quot;,&quot;fixed_month&quot;:&quot;10&quot;}'></div>`;

const block = (id: number, ri: number, name: string, address: string, image: string) =>
  `<div id="event_${id}_${ri}" class="eventon_list_event" data-event_id="${id}" data-ri="${ri}r">` +
  `<span class='event_location_attrs' data-location_address="${address}" data-location_type="address" data-location_name="${name}"></span>` +
  `<span class='ev_ftImg' style='background-image:url();'></span>` +
  `<div class='evocard_box' style='background-image:url(${image})'></div></div>`;

const RESPONSE = {
  status: 'GOOD',
  html:
    block(21670, 0, 'Kensington Town Hall', 'Hornton Street, London W8 7NX', 'https://kharis.org/a.jpeg') +
    block(21583, 0, 'Queen Anne&#8217;s School', '', ''),
  json: [
    {
      event_id: 21670,
      ri: '0',
      event_title: 'Sunday Service',
      // True UTC: 09:00Z = 10:00 BST. (`evcal_srow` would be 10:00Z, wrong.)
      unix_start: '1785661200',
      unix_end: '1785711000',
    },
    { event_id: 21583, ri: 0, event_title: 'Midweek &amp; Prayer', unix_start: 1786644000, unix_end: 0 },
    { event_id: 'x', event_title: 'Broken', unix_start: 'nope' },
  ],
};

test('reads the nonce and calendar shortcode from the K-Events page', () => {
  const config = parseCalendarConfig(PAGE);
  assert.equal(config?.nonce, '9dfdf3c8a8');
  assert.equal(config?.shortcode.calendar_type, 'default');
  assert.equal(parseCalendarConfig('<html></html>'), null);
});

test('month request asks for the London month range', () => {
  const config = parseCalendarConfig(PAGE);
  assert.ok(config);
  const body = monthRequestBody(config, 2026, 12);
  assert.equal(body.get('nonce'), '9dfdf3c8a8');
  assert.equal(body.get('shortcode[fixed_month]'), '12');
  assert.equal(body.get('shortcode[fixed_year]'), '2026');
  assert.equal(body.get('shortcode[focus_start_date_range]'), String(Date.UTC(2026, 11, 1) / 1000));
  assert.equal(body.get('shortcode[focus_end_date_range]'), String(Date.UTC(2027, 0, 1) / 1000 - 1));
});

test('parses times from unix_start/unix_end and venue and image from the block', () => {
  const [sunday, midweek, ...rest] = parseEventonResponse(RESPONSE);
  assert.equal(rest.length, 0, 'malformed rows are dropped');
  assert.equal(new Date(sunday.startMs).toISOString(), '2026-08-02T09:00:00.000Z');
  assert.equal(new Date(sunday.endMs).toISOString(), '2026-08-02T22:50:00.000Z');
  assert.equal(sunday.location, 'Kensington Town Hall');
  assert.equal(sunday.address, 'Hornton Street, London W8 7NX');
  assert.equal(sunday.imageUrl, 'https://kharis.org/a.jpeg');
  assert.equal(midweek.title, 'Midweek & Prayer');
  assert.equal(midweek.location, 'Queen Anne\u2019s School');
  assert.equal(midweek.address, null);
  assert.equal(midweek.imageUrl, null);
  assert.equal(midweek.endMs, midweek.startMs, 'a missing end means it ends at the start');
});

test('campus mapping: "Kharis London" -> London, KP2 kept, unknown refused', () => {
  const branches = ['London', 'Chatham', 'KP2 London'];
  assert.deepEqual(campusesFor(['Kharis London'], branches), { campuses: ['London'], unknown: [] });
  assert.deepEqual(campusesFor(['KP2 London'], branches), { campuses: ['KP2 London'], unknown: [] });
  assert.deepEqual(campusesFor([], branches), { campuses: [null], unknown: [] });
  assert.deepEqual(campusesFor(['Kharis Crawley &amp; West Sussex'], branches), {
    campuses: [],
    unknown: ['Kharis Crawley & West Sussex'],
  });
});

test('doc ids are stable per post, repeat and (multi-)campus', () => {
  assert.equal(webEventDocId({ wpId: 21670, ri: '0' }, 'London', false), 'web_21670');
  assert.equal(webEventDocId({ wpId: 21670, ri: '3' }, null, false), 'web_21670_3');
  assert.equal(webEventDocId({ wpId: 7, ri: '0' }, 'KP2 London', true), 'web_7_kp2-london');
});

test('re-sync writes only the site fields that changed', () => {
  const stored = {
    title: 'Sunday Service',
    startTime: Timestamp.fromMillis(1000),
    location: 'Hall',
    branch: 'Chatham',
  };
  const fields = { title: 'Sunday Service', startTime: Timestamp.fromMillis(1000), location: 'New Hall' };
  assert.deepEqual(changedFields(stored, fields), { location: 'New Hall' });
  assert.deepEqual(changedFields(stored, { title: 'Sunday Service' }), {});
});
