# Quick Setup Instructions

## 1. Install Dependencies
The dependencies are already installed. If you need to reinstall:
```bash
flutter pub get
```

## 2. Set Up Supabase Tables

### Option A: Using Supabase Dashboard (Recommended)
1. Go to https://supabase.com/dashboard
2. Select your project: `pmsemyznsxeigmfhzyfg`
3. Click on "SQL Editor" in the left sidebar
4. Click "New query"
5. Copy the entire content from `backend/supabase_tables.sql`
6. Paste it into the SQL editor
7. Click "Run" button
8. You should see "Success. No rows returned"

### Option B: Manual Table Creation
If you prefer to create tables manually through the Table Editor:

#### Create `favorite_locations` table:
- id: uuid, primary key, default: gen_random_uuid()
- user_id: uuid, foreign key to auth.users
- name: text, required
- latitude: float8, required
- longitude: float8, required
- address: text, nullable
- category: text, nullable
- created_at: timestamptz, default: now()

#### Create `recent_searches` table:
- id: uuid, primary key, default: gen_random_uuid()
- user_id: uuid, foreign key to auth.users
- query: text, required
- name: text, required
- latitude: float8, required
- longitude: float8, required
- address: text, nullable
- created_at: timestamptz, default: now()

#### Enable RLS and Create Policies:
For both tables, enable Row Level Security and create policies that:
- Allow SELECT where auth.uid() = user_id
- Allow INSERT where auth.uid() = user_id
- Allow UPDATE where auth.uid() = user_id (recent_searches only)
- Allow DELETE where auth.uid() = user_id

## 3. Run the App

```bash
flutter run
```

## 4. Test the Features

1. **Allow Location Permissions** when prompted
2. **Search for a location** using the bottom search bar
3. **Select a result** and tap "Get Directions"
4. **Try nearby places** by tapping the search icon (top left)
5. **Save a location** to favorites
6. **View favorites** by tapping the heart icon (top right)

## 5. Troubleshooting

### Map Not Loading
- Check internet connection
- Verify TomTom API key in `lib/config/tomtom_config.dart`

### Location Not Working
- Ensure location permissions are granted in Android settings
- Check that GPS is enabled on the device

### Favorites Not Saving
- Verify Supabase tables are created correctly
- Check that RLS policies are set up
- Ensure user is logged in

### Search Not Working
- Check network connection
- Verify TomTom API key is valid
- Look for errors in Flutter console

## Color Reference

When customizing the UI, use these colors to maintain consistency:

- Background: `Color(0xFF1c1c1c)`
- Secondary: `Color(0xFF2a2a2a)`
- Text Light: `Color(0xFFf5f6fa)`
- Text Gray: `Color(0xFF9e9e9e)`
- Brand Green: `Color(0xFF06d6a0)`
- Border: `Color(0xFF3a3a3a)`

## File Locations

- Main map widget: `lib/widgets/map_home_page.dart`
- TomTom service: `lib/services/tomtom_service.dart`
- Location service: `lib/services/location_service.dart`
- Supabase extensions: `lib/services/supabase_service.dart`
- Config: `lib/config/tomtom_config.dart`
- Models: `lib/models/location_model.dart`

## Important Notes

1. **API Key Security**: The TomTom API key is currently hardcoded. In production, move it to environment variables.

2. **Background Location**: Background location permission is requested but not actively used. Implement background tracking if needed.

3. **iOS Support**: Only Android permissions are configured. Add iOS location permissions in `ios/Runner/Info.plist` if needed.

4. **Rate Limiting**: TomTom API has rate limits. Monitor usage in production.

5. **Offline Support**: The app requires internet connection. Consider implementing offline map caching for production.

## Next Steps

After successful setup:
1. Test all features thoroughly
2. Add error handling for edge cases
3. Implement loading states for better UX
4. Add analytics to track feature usage
5. Consider adding route alternatives
6. Implement turn-by-turn navigation
7. Add voice guidance

---

For detailed documentation, see `TOMTOM_INTEGRATION.md`
