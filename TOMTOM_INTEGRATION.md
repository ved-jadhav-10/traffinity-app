# TomTom Map Integration - Setup Guide

This document explains the TomTom Maps integration in the Traffinity app and how to set up the required Supabase tables.

## Features Implemented

### 1. **Interactive Map with TomTom Tiles**
- Full-screen map using TomTom map tiles
- Custom styling with dark theme integration
- Real-time location tracking
- Smooth map animations and transitions

### 2. **Location Search**
- Autocomplete search with 500ms debounce
- Maximum 5 search results displayed
- Search results prioritized by proximity to current location
- Recent searches saved to Supabase for cross-device sync

### 3. **Route Planning**
- Calculate routes between current location and destination
- Display route as a polyline in brand color (#06d6a0)
- Show start and end markers
- Route information card displaying:
  - Total distance (meters/kilometers)
  - Estimated travel time
  - Traffic delays and conditions

### 4. **Nearby Places Search**
- Search by category:
  - Gas Stations
  - Restaurants
  - Parking Lots
  - EV Charging Stations
  - ATMs
  - Hotels
- Results displayed as markers on the map
- Tap markers to view place details
- Get directions to any nearby place

### 5. **Favorite Locations**
- Save locations to Supabase
- View all favorites in a list
- Quickly navigate to favorite locations
- Delete favorites
- Sync across devices

### 6. **Location Permissions**
- Request and handle location permissions
- Support for foreground location tracking
- Background location updates capability
- Graceful handling of permission denials

### 7. **User Interface**
- Dark theme matching app design (#1c1c1c background)
- Brand color accents (#06d6a0)
- User's first name displayed from Supabase
- Favorites button to access saved locations
- Recenter button to return to current location
- Nearby places button in top bar
- Clean search interface at bottom

## Supabase Setup

### Step 1: Create Tables

Run the SQL script in `backend/supabase_tables.sql` in your Supabase SQL Editor:

```sql
-- This will create:
-- 1. favorite_locations table
-- 2. recent_searches table
-- 3. Appropriate indexes for performance
-- 4. Row Level Security policies
```

### Step 2: Verify Tables

After running the script, verify the tables exist:
1. Go to Supabase Dashboard → Table Editor
2. You should see:
   - `favorite_locations`
   - `recent_searches`

### Step 3: Test Permissions

The RLS policies ensure:
- Users can only see their own data
- Users can insert, update, and delete their own data
- No user can access another user's favorites or searches

## API Configuration

### TomTom API Key
The API key is stored in `/lib/config/tomtom_config.dart`:
```dart
static const String apiKey = 'KyVOSYpmJE5kGcAGF23ebcVIvtsy0LuI';
```

**Note:** This key should be moved to environment variables in production.

### API Endpoints Used
1. **Search API**: Location autocomplete and search
2. **Routing API**: Calculate routes with traffic data
3. **Places API**: Find nearby places by category
4. **Reverse Geocoding**: Get addresses from coordinates
5. **Map Tiles**: Display TomTom map

## Android Permissions

Already configured in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

## File Structure

```
lib/
├── config/
│   ├── supabase_config.dart      # Supabase credentials
│   └── tomtom_config.dart         # TomTom API configuration
├── models/
│   └── location_model.dart        # Location, Search, Route models
├── services/
│   ├── location_service.dart      # GPS location handling
│   ├── tomtom_service.dart        # TomTom API calls
│   └── supabase_service.dart      # Database operations (extended)
├── widgets/
│   └── map_home_page.dart         # Main map interface
└── home_page.dart                  # Entry point (redirects to map)
```

## Usage Guide

### For Users

1. **Search for a Location**:
   - Tap the search field at the bottom
   - Start typing a location name
   - Select from autocomplete results

2. **Get Directions**:
   - After selecting a destination, tap "Get Directions"
   - Route will appear on the map in green (#06d6a0)
   - View distance, time, and traffic info

3. **Find Nearby Places**:
   - Tap the search icon (top left)
   - Choose a category (Gas, Restaurants, etc.)
   - Blue markers will appear on the map
   - Tap any marker to see details and get directions

4. **Save Favorites**:
   - When viewing place details, tap "Save"
   - Access favorites via the heart icon (top right)
   - Tap any favorite to navigate to it

5. **Recenter Map**:
   - Tap the location button (bottom right) to return to your current position

### For Developers

#### Add New Place Categories
Edit `_buildNearbyCategoriesSheet()` in `map_home_page.dart`:
```dart
final categories = [
  {'name': 'Category Name', 'icon': Icons.icon_name, 'query': 'tomtom_category'},
  // Add more categories
];
```

#### Customize Route Color
Edit `lib/config/tomtom_config.dart`:
```dart
static const String routeColor = '#06d6a0'; // Change this
```

#### Adjust Search Debounce
Edit `_onSearchChanged()` in `map_home_page.dart`:
```dart
_searchDebounce = Timer(const Duration(milliseconds: 500), () {
  // Change milliseconds value
});
```

## Testing

### Test Checklist
- [ ] Location permissions granted
- [ ] Current location displayed on map
- [ ] Search autocomplete works
- [ ] Routes display correctly
- [ ] Nearby places search works
- [ ] Favorites save to Supabase
- [ ] Favorites load from Supabase
- [ ] Recent searches save correctly
- [ ] Map recenters on button press
- [ ] User's first name displays correctly
- [ ] Logout functionality works

### Common Issues

1. **Map not loading**: Check internet connection and TomTom API key
2. **Location not found**: Ensure location permissions are granted
3. **Favorites not saving**: Check Supabase connection and RLS policies
4. **Search not working**: Verify TomTom API key and network connection

## Dependencies

```yaml
dependencies:
  flutter_map: ^7.0.2          # Map widget
  latlong2: ^0.9.1             # Latitude/Longitude handling
  geolocator: ^13.0.2          # GPS location services
  permission_handler: ^11.3.1   # Permission management
  http: ^1.2.2                  # HTTP requests
  supabase_flutter: ^2.5.6     # Supabase integration
```

## Next Steps

### Recommended Enhancements
1. Add offline map caching
2. Implement route alternatives
3. Add voice navigation
4. Include public transport routes
5. Show real-time traffic overlays
6. Add location sharing between users
7. Implement geofencing alerts
8. Add parking availability data
9. Include speed limit warnings
10. Support multi-waypoint routes

## Support

For issues or questions:
1. Check the Flutter console for errors
2. Verify Supabase table structure
3. Confirm TomTom API key is valid
4. Check Android permissions in manifest

## Color Scheme

- **Background**: #1c1c1c (Dark gray)
- **Secondary Background**: #2a2a2a
- **Text Primary**: #f5f6fa (Off-white)
- **Text Secondary**: #9e9e9e (Gray)
- **Brand Color**: #06d6a0 (Teal/Green)
- **Accent**: #3a3a3a
- **Route Line**: #06d6a0
- **Current Location**: #06d6a0
- **Destination**: Red
- **Nearby Places**: Blue

---

**Implementation Date**: November 6, 2025
**Version**: 1.0.0
**Developer**: Traffinity Team
