# Live Events Feature - Implementation Complete

## Overview
The Live Events feature tracks general events (concerts, hackathons, festivals, etc.) from social media and RSS feeds, displays them on a dedicated map, and allows users to submit their own events.

## Features Implemented

### 1. Event Sources (Free APIs)
- **Reddit API**: Unlimited free tier, searches city subreddits for event keywords
- **RSS Feeds**: Times of India & Hindustan Times city news feeds
- **User Submissions**: Supabase backend for user-submitted events with expiry

### 2. Event Types Supported
- Concerts
- Hackathons
- Festivals
- Conferences
- Expos
- Sports Events
- Other General Events

### 3. City Coverage
- Mumbai
- Delhi
- Bangalore
- Pune
- Raipur

### 4. Traffic Impact Prediction
Events are automatically categorized by expected traffic impact:
- **Low**: < 500 attendees
- **Medium**: 500-2000 attendees
- **High**: > 2000 attendees

## Implementation Details

### Files Created

#### 1. `lib/services/live_event_service.dart`
**Purpose**: Aggregates events from multiple sources

**Key Methods**:
- `getCityEvents(String city)` - Main method to fetch all events for a city
- `_getRedditEvents(String city)` - Searches r/mumbai, r/delhi, etc.
- `_getRSSEvents(String city)` - Fetches from news RSS feeds
- `_getUserSubmittedEvents(String city)` - Queries Supabase
- `submitUserEvent()` - Saves user-submitted events to Supabase
- `geocodeLocation()` - Converts location names to lat/lng using OpenStreetMap Nominatim

**Models**:
```dart
class LiveEvent {
  final String id;
  final String title;
  final String? description;
  final String location;
  final LatLng? coordinates;
  final DateTime startTime;
  final DateTime? endTime;
  final String source; // 'reddit', 'rss', 'user'
  final String? sourceUrl;
  final String eventType;
  final int? estimatedAttendance;
  final TrafficImpact trafficImpact;
}

enum TrafficImpact { low, medium, high }
```

#### 2. `lib/screens/live_events_map_screen.dart`
**Purpose**: Dedicated map screen showing only live events

**Features**:
- Flutter Map with OpenStreetMap tiles
- Color-coded event markers by type
- Event filtering by type
- Tap markers to see full event details
- Bottom sheet with event information
- User event submission dialog
- Automatic geocoding during load

**UI Components**:
- Filter chips for event types
- Event detail modal bottom sheet
- Add event floating action button
- Loading indicators during geocoding

#### 3. `backend/live_events_table.sql`
**Purpose**: Supabase database schema

**Schema**:
```sql
CREATE TABLE live_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  location TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  event_type TEXT NOT NULL,
  estimated_attendance INTEGER,
  traffic_impact TEXT,
  city TEXT NOT NULL,
  user_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

**RLS Policies**:
- Anyone can read events
- Authenticated users can create/update/delete their own events

**Functions**:
- `delete_expired_events()` - Cleanup function for old events

### Files Modified

#### `lib/screens/city_incident_map_screen.dart`
**Changes**:
1. Added imports for `LiveEventService` and `LiveEventsMapScreen`
2. Added `_liveEventsCount` state variable
3. Added `_getCityFromLocation()` helper to detect closest city
4. Added `_loadLiveEventsCount()` to fetch event count
5. Added Live Events card as Positioned widget (top: 200)
6. Card shows event count and navigates to LiveEventsMapScreen

**Card Design**:
- Gradient background (primary green #06d6a0)
- Event icon with badge
- Shows count: "X event(s) happening now"
- Tap to navigate to full events map
- Only appears when events exist (_liveEventsCount > 0)

## Next Steps

### 1. Run Supabase Migration
Execute `backend/live_events_table.sql` in your Supabase dashboard:
1. Go to Supabase project
2. Navigate to SQL Editor
3. Create new query
4. Paste contents of `live_events_table.sql`
5. Run the query

### 2. Test Reddit API Integration
- Reddit API requires proper User-Agent header (already configured)
- Test with city subreddits: r/mumbai, r/delhi, r/bangalore, r/pune, r/raipur
- Keywords searched: concert, hackathon, festival, conference, expo, event

### 3. Test RSS Feed Parsing
- Times of India cities: Mumbai, Delhi, Bangalore, Pune
- Hindustan Times cities: Mumbai, Delhi, Noida
- XML parsing with regex (basic implementation)

### 4. Test Geocoding
- OpenStreetMap Nominatim API (free)
- Rate limit: 1 request per second (already implemented with delays)
- Geocodes event location names to lat/lng

### 5. Add Dependencies (if missing)
Check `pubspec.yaml` for:
```yaml
dependencies:
  http: ^1.1.0  # For API calls
  intl: ^0.18.0  # For date formatting
```

Run `flutter pub get` if needed.

## Usage Flow

1. **User opens Territory Map** → City Incident Map Screen
2. **App detects user location** → Determines closest city
3. **Loads live events count** → Shows card if events exist
4. **User taps Live Events card** → Navigates to LiveEventsMapScreen
5. **Map loads events** → Reddit + RSS + Supabase aggregated
6. **Geocoding happens** → Location names → lat/lng
7. **Events displayed as markers** → Color-coded by type
8. **User can filter** → By event type (concert, hackathon, etc.)
9. **User taps marker** → Shows event details
10. **User can submit event** → FAB → Form → Supabase

## API Rate Limits & Costs

### Free Forever:
- ✅ Reddit API: Unlimited (with User-Agent)
- ✅ RSS Feeds: Unlimited
- ✅ OpenStreetMap Nominatim: Unlimited (1/sec rate limit)
- ✅ Supabase: Free tier sufficient for user events

### No API Keys Required:
- Reddit API (no auth needed for public searches)
- RSS feeds (public URLs)
- Nominatim (optional but recommended to include email)

## Traffic Impact Algorithm

```dart
TrafficImpact _calculateTrafficImpact(int? attendance) {
  if (attendance == null) return TrafficImpact.low;
  if (attendance >= 2000) return TrafficImpact.high;
  if (attendance >= 500) return TrafficImpact.medium;
  return TrafficImpact.low;
}
```

**Default Attendance by Event Type**:
- Concert: 1000 (Medium)
- Hackathon: 300 (Low)
- Festival: 5000 (High)
- Conference: 500 (Medium)
- Expo: 2000 (High)
- Sports: 3000 (High)
- Other: 500 (Medium)

## Color Coding

### Event Type Colors (Map Markers):
- Concert: 🟣 Purple
- Hackathon: 🔵 Blue
- Festival: 🟡 Orange
- Conference: 🟢 Green
- Expo: 🔴 Red
- Sports: 🟠 Deep Orange
- Other: 🟤 Grey

### Traffic Impact Colors:
- Low: Green (#4CAF50)
- Medium: Orange (#FF9800)
- High: Red (#F44336)

## Error Handling

All API calls are wrapped in try-catch blocks:
- Reddit API failures → Skip Reddit events, continue with RSS/Supabase
- RSS parsing errors → Skip failed feeds, continue with others
- Geocoding failures → Event shown without marker on map
- Supabase errors → Logged, doesn't crash app

## Known Limitations

1. **Reddit Search**: Basic keyword matching, may miss events with creative titles
2. **RSS Parsing**: Regex-based, may miss events in complex XML structures
3. **Geocoding**: 1-second delay between requests (Nominatim limit)
4. **City Detection**: Simple distance calculation, may be inaccurate at city borders
5. **Event Expiry**: Manual cleanup needed, not automatic (use Supabase function)

## Future Enhancements

- [ ] Add more RSS feed sources
- [ ] Improve Reddit search with NLP
- [ ] Add event categories (music, tech, sports)
- [ ] Push notifications for new events
- [ ] User event verification system
- [ ] Event popularity voting
- [ ] Share events to social media
- [ ] Calendar integration
- [ ] Event reminders
- [ ] Traffic prediction based on historical data

## Testing Checklist

- [ ] Run Supabase migration
- [ ] Test Reddit API with real city search
- [ ] Test RSS feed parsing with live feeds
- [ ] Test geocoding with sample location names
- [ ] Test user event submission
- [ ] Test event filtering
- [ ] Test navigation from territory to events map
- [ ] Test event detail modal
- [ ] Test traffic impact display
- [ ] Verify expired events are hidden
- [ ] Test with no events (card should hide)
- [ ] Test with multiple cities

## Support & Troubleshooting

### Supabase Connection Issues
- Check `lib/services/supabase_service.dart`
- Verify Supabase credentials in environment

### Reddit API Returns Empty
- Check User-Agent header in `live_event_service.dart`
- Verify subreddit names (r/mumbai, r/delhi, etc.)
- Check Reddit API status

### Geocoding Fails
- Verify internet connection
- Check Nominatim rate limits (1/sec)
- Add email to Nominatim requests (optional but recommended)

### Events Not Showing
- Check `_liveEventsCount` > 0
- Verify city detection logic
- Check console for API errors

---

**Implementation Status**: ✅ Complete
**Last Updated**: December 2024
**Version**: 1.0.0
