# New Features Implementation Guide

## Overview
This document describes the three new features that have been added to the Traffinity app:

1. **Compass Feature** - Device orientation-based compass with map recentering
2. **Voice Search** - Speech-to-text functionality for location search
3. **User Profile Management** - Comprehensive profile editing with vehicle management

---

## 1. Compass Feature

### Description
A compass button that rotates based on device orientation (pointing north) and allows users to recenter and reset the map to north-up orientation.

### Location
- **File**: `lib/widgets/map_home_page.dart`
- **Position**: Right side of the map, above the "My Location" button

### Implementation Details
- **Package Used**: `flutter_compass: ^0.8.0`
- The compass icon rotates in real-time based on device orientation
- Clicking the compass button:
  - Recenters the map to user's current location
  - Resets map rotation to north-up (0 degrees)
- The button dynamically adjusts its position based on whether route info is shown

### Key Methods
- `_initializeCompass()` - Initializes compass sensor listening
- `_resetMapRotation()` - Handles compass button click

---

## 2. Voice Search Feature

### Description
A microphone button in the search bar that enables voice-based location search using speech recognition.

### Location
- **File**: `lib/widgets/map_home_page.dart`
- **Position**: Inside the search bar, between the search input and hamburger menu

### Implementation Details
- **Package Used**: `speech_to_text: ^7.0.0`
- **Language Support**: English (en_US)
- **Visual Feedback**: 
  - Black mic icon when inactive
  - Green mic icon when listening/recording
- **Error Handling**: Shows "Try again" message if recognition fails or permission denied

### Key Methods
- `_initializeSpeechToText()` - Initializes speech recognition
- `_toggleListening()` - Starts/stops voice recognition
- Automatically populates search field with recognized text

### Permissions Required
- **Android**: `RECORD_AUDIO` (added to AndroidManifest.xml)
- **iOS**: Microphone and Speech Recognition (added to Info.plist)

---

## 3. User Profile Management

### Description
A comprehensive profile page where users can edit personal information, manage vehicles, and change passwords.

### Location
- **Main File**: `lib/screens/profile/profile_screen.dart`
- **Access**: Click hamburger menu → Profile (first option)

### Features

#### Personal Information
- **Name** (required)
- **Phone Number** (optional, with 10-digit validation)

#### Vehicle Management
- Users can add up to **3 vehicles**
- Each vehicle has:
  - **Type**: Dropdown (Car/Bike)
  - **Model**: Text input (e.g., "Honda Civic")
  - **Fuel Type**: Dropdown (Petrol/Diesel/CNG/EV)
- Vehicles are optional
- Users can add/remove vehicles dynamically

#### Password Change
- Requires current password verification (security)
- New password must be at least 6 characters
- Confirm password validation
- Expandable section (hidden by default)

### Database Schema

#### New Table: `user_profiles`
```sql
CREATE TABLE public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    phone_number TEXT,
    vehicles JSONB DEFAULT '[]'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT now()
);
```

#### Vehicles JSON Format
```json
[
  {
    "type": "car",
    "model": "Honda Civic",
    "fuel": "petrol"
  },
  {
    "type": "bike",
    "model": "Royal Enfield",
    "fuel": "petrol"
  }
]
```

### Supabase Service Methods
- `getUserProfile()` - Fetches user profile data
- `updateUserProfile()` - Updates profile (name, phone, vehicles)
- `updatePassword()` - Changes password with verification

### Security Features
- Row Level Security (RLS) enabled
- Users can only view/edit their own profiles
- Current password verification required for password changes
- Automatic profile creation on user signup (via trigger)

---

## Database Setup

Run the SQL script in `backend/supabase_tables.sql` in your Supabase SQL Editor to:
1. Create the `user_profiles` table
2. Set up Row Level Security policies
3. Create automatic profile creation trigger

---

## Testing Checklist

### Compass Feature
- [ ] Compass icon rotates with device orientation
- [ ] Clicking compass recenters map to user location
- [ ] Map rotation resets to north-up (0 degrees)
- [ ] Button position adjusts when route info is shown

### Voice Search
- [ ] Mic button appears in search bar
- [ ] Permission prompt appears on first use
- [ ] Mic turns green when listening
- [ ] Recognized speech populates search field
- [ ] Search results appear after speech recognition
- [ ] Error message shown on failure

### Profile Page
- [ ] Profile page opens from hamburger menu
- [ ] User name loads correctly
- [ ] Phone number validates (10 digits)
- [ ] Can add up to 3 vehicles
- [ ] Can remove vehicles (minimum 1)
- [ ] Vehicle dropdowns work correctly
- [ ] Password change requires current password
- [ ] Profile updates sync to Supabase
- [ ] Name updates reflect in hamburger menu

---

## Package Dependencies Added

```yaml
# Compass sensor for map orientation
flutter_compass: ^0.8.0

# Speech to text for voice search
speech_to_text: ^7.0.0
```

Run `flutter pub get` to install these packages.

---

## Notes

1. **Compass Feature**: The compass uses the device's magnetometer. It may be less accurate near magnetic interference.

2. **Voice Search**: Currently supports English only. Can be extended to other languages by modifying the `localeId` parameter in `_toggleListening()`.

3. **Profile Updates**: Changes to name are stored in user metadata, while phone and vehicles are in the `user_profiles` table.

4. **Vehicle Limit**: Maximum 3 vehicles to keep the UI clean and data manageable.

---

## Future Enhancements

### Possible Improvements
1. **Compass**: Add calibration feature for better accuracy
2. **Voice Search**: Multi-language support
3. **Profile**: 
   - Profile picture upload
   - Email change functionality
   - Account deletion option
   - Driving preferences (avoid tolls, highways, etc.)
4. **Vehicle Management**: 
   - Set default vehicle
   - Fuel efficiency tracking
   - Maintenance reminders

---

## Support

For issues or questions:
1. Check the implementation in the respective files
2. Verify database setup in Supabase
3. Ensure all permissions are granted in device settings
4. Check console logs for detailed error messages
