# 🚗 Traffinity - Smart Navigation & Urban Mobility App

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Database-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
**A comprehensive smart transportation and navigation platform designed for Indian cities**

[Features](#-key-features) • [Installation](#-installation) • [Architecture](#-architecture) • [Contributing](#-contributing)

</div>

---

## 📱 Overview

**Traffinity** is an all-in-one smart transportation app that combines real-time traffic intelligence, turn-by-turn navigation, public transport tracking, and city event monitoring. Built specifically for Indian cities, it integrates multiple data sources to provide the most accurate and comprehensive mobility solution.

### 🎯 Core Capabilities

- **🗺️ Smart Navigation**: Real-time traffic-aware routing with voice guidance
- **🚌 Public Transport**: Bus & train schedules, live tracking, and route planning
- **🚨 City Intelligence**: Live traffic incidents, events, and city monitoring
- **🌱 Sustainability**: Carbon footprint tracking and eco-friendly route options
- **📍 Collections**: Organize and save your favorite places
- **👤 User Profiles**: Personalized experience with vehicle management

---

## ✨ Key Features

### 🗺️ Navigation & Routing

- **Turn-by-turn navigation** with voice guidance
- **Real-time traffic** integration with color-coded overlays
- **Multi-stop waypoints** with drag-to-reorder functionality
- **Route optimization** using TomTom Waypoint API
- **Alternative routes** comparison with traffic analysis
- **Weather impact** calculation on travel time
- **Optimal departure times** based on traffic predictions
- **Offline map** support with tile caching

### 🔍 Smart Search

- **Voice search** using speech-to-text
- **Location autocomplete** with TomTom Search API
- **Nearby places** discovery (restaurants, gas stations, ATMs, hospitals, etc.)
- **Search history** with favorites system
- **Collections** to organize saved locations

### 🚨 Traffic & Incidents

- **Live traffic flow** visualization
- **Real-time incidents** from TomTom + user reports
- **Incident reporting** with photo upload
- **Emergency SOS** button for critical situations
- **Traffic delay** predictions and alerts

### 🎉 Live Events

- **Multi-source events** (Reddit, RSS feeds, user submissions)
- **Event types**: Concerts, hackathons, festivals, conferences, expos, sports
- **Smart deduplication** using Levenshtein algorithm
- **Traffic impact** analysis for events
- **Event submission** with auto-location detection

### 🚌 Public Transport

- **Bus search** (stop-to-stop & route number)
- **Train tracking** with Indian Railways integration
- **Live status** and PNR checking
- **Schedule lookup** with platform information
- **Trip planning** and history

### 🌱 Environmental Impact

- **Carbon footprint** calculator
- **Transport mode** comparison (walking, cycling, metro, car, etc.)
- **Eco-friendly routing** suggestions
- **Cost analysis** and savings tracking

### 👤 User Features

- **Multiple auth methods**: Email, Google OAuth, Phone OTP
- **Vehicle management**: Add up to 3 vehicles with fuel types
- **Profile customization** with photo upload
- **Favorites & collections** with full CRUD operations
- **Feedback system** with star ratings and text reviews

---

## 🛠️ Technology Stack

### Frontend
- **Framework**: Flutter 3.9.2+
- **Language**: Dart 3.9.2+
- **State Management**: Provider pattern, StreamControllers
- **Maps**: flutter_map with TomTom tiles
- **UI Components**: Material Design 3

### Backend & Services
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Storage**: Supabase Storage for images
- **Security**: Row Level Security (RLS)

### APIs & Integrations
- **TomTom**: Routing, Traffic, Search, Geocoding
- **OpenStreetMap**: Nominatim reverse geocoding
- **Reddit API**: Live events scraping
- **RSS Feeds**: News aggregation
- **Google Sign-In**: OAuth authentication
- **Indian Railways**: Train tracking

### Device Features
- **GPS**: Real-time location tracking
- **Compass**: Map orientation
- **Camera**: Incident photo capture
- **Microphone**: Voice search
- **TTS**: Voice guidance during navigation

---

## 📦 Installation

### Prerequisites

- Flutter SDK 3.9.2 or higher
- Dart SDK 3.9.2 or higher
- Android Studio / Xcode (for mobile development)
- Supabase account
- TomTom API key

### Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/ved-jadhav-10/traffinity-app.git
   cd traffinity-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a new project at [supabase.com](https://supabase.com)
   - Update `lib/config/supabase_config.dart` with your credentials:
     ```dart
     class SupabaseConfig {
       static const String supabaseUrl = 'YOUR_SUPABASE_URL';
       static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     }
     ```
   - Run the database setup scripts:
     - Execute `supabase_feedback_table.sql` for feedback feature
     - Set up other tables as needed (see Database Schema section)

4. **Configure TomTom API**
   - Get API key from [developer.tomtom.com](https://developer.tomtom.com)
   - Update `lib/config/tomtom_config.dart`:
     ```dart
     class TomTomConfig {
       static const String apiKey = 'YOUR_TOMTOM_API_KEY';
     }
     ```

5. **Configure Google Sign-In** (Optional)
   - Follow [Google Sign-In setup](https://pub.dev/packages/google_sign_in)
   - Add `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)

6. **Run the app**
   ```bash
   flutter run
   ```

---

## 🏗️ Architecture

### Project Structure

```
lib/
├── config/              # Configuration files
│   ├── app_theme.dart
│   ├── supabase_config.dart
│   └── tomtom_config.dart
├── models/             # Data models
│   ├── location_model.dart
│   ├── traffic_model.dart
│   └── ...
├── screens/            # UI screens
│   ├── auth/
│   ├── profile/
│   ├── collections/
│   ├── feedback/
│   ├── transport/
│   └── ...
├── services/           # Business logic & API services
│   ├── supabase_service.dart
│   ├── tomtom_service.dart
│   ├── navigation_service.dart
│   ├── location_service.dart
│   └── ...
├── widgets/            # Reusable widgets
│   ├── map_home_page.dart
│   ├── live_navigation_screen.dart
│   ├── transport_page.dart
│   └── territory_page.dart
├── main.dart
├── home_page.dart
├── splash_screen.dart
└── onboarding_screen.dart
```

### Database Schema

**Core Tables:**
- `profiles` - User information and settings
- `feedback` - User feedback with ratings
- `traffic_incidents` - User-reported traffic incidents
- `live_events` - User-submitted events
- `favorite_locations` - Saved favorite places
- `collections` - User-created location collections
- `collection_locations` - Locations within collections
- `recent_searches` - Search history
- `user_trips` - Planned trips

**Security:**
All tables implement Row Level Security (RLS) policies:
- Users can only access their own data
- Public read for incidents and events
- Authenticated users can create
- Owners can update/delete

---

## 🔑 Key Dependencies

```yaml
dependencies:
  # Backend
  supabase_flutter: ^2.5.6
  
  # Authentication
  google_sign_in: ^6.2.1
  flutter_secure_storage: ^9.2.2
  
  # Maps & Location
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  geolocator: ^13.0.2
  permission_handler: ^11.3.1
  flutter_compass: ^0.8.0
  
  # Navigation
  flutter_tts: ^4.2.0
  speech_to_text: ^7.0.0
  
  # Network & Caching
  http: ^1.2.2
  flutter_cache_manager: ^3.4.1
  cached_network_image: ^3.4.1
  
  # UI/UX
  intl: ^0.19.0
  url_launcher: ^6.3.1
  image_picker: ^1.1.2
  shared_preferences: ^2.3.3
```

---

## 🚀 Features in Detail

### Navigation System

The navigation system uses a multi-layered approach:

1. **Route Calculation**: TomTom Routing API calculates optimal routes with traffic
2. **Real-time Updates**: GPS stream updates position every 10 meters
3. **Voice Guidance**: Text-to-speech announces turns at 500m, 100m, and 30m
4. **Off-route Detection**: Automatically reroutes if user deviates >30m
5. **Traffic Integration**: Color-coded polylines show traffic conditions
6. **Weather Impact**: Calculates delays due to weather conditions

### Incident Reporting

Users can report traffic incidents with:
- Type selection (accident, traffic jam, road work, etc.)
- Severity levels (minor, moderate, severe)
- Photo upload capability
- Duration estimates
- Anonymous or named reporting
- GPS auto-location

### Event System

Events are aggregated from multiple sources:
- **Reddit**: Scrapes Indian event subreddits
- **RSS Feeds**: Parses news sites for events
- **User Submissions**: Direct event creation
- **Deduplication**: 70% similarity threshold removes duplicates
- **Geocoding**: Smart location handling with coordinate storage

### Collections & Favorites

Organize locations with:
- Unlimited collections
- Custom names, colors, and icons
- Add locations via search, map, or manual entry
- Attach photos (up to 5 per location)
- Rating system (5 stars)
- Notes and visit tracking
- Share collections

---

## 🔐 Security & Privacy

- **Encrypted Storage**: Tokens stored with flutter_secure_storage
- **HTTPS Only**: All API calls use secure connections
- **Row Level Security**: Database-level access control
- **Anonymous Options**: Report incidents without identification
- **Data Minimization**: Only essential data collected
- **User Control**: Delete data anytime

---

## 📱 Platform Support

- ✅ Android (API 21+)
- ✅ iOS (12.0+)
- 🚧 Web (Limited features)
- 🚧 Desktop (Experimental)

---

## 🎨 Design System

### Color Palette

- **Primary Green**: `#06d6a0`
- **Background**: `#1c1c1c`
- **Cards**: `#2a2a2a`
- **Borders**: `#3a3a3a`
- **Text Primary**: `#f5f6fa`
- **Text Secondary**: `#9e9e9e`

### Typography

- **Primary**: Poppins (300, 400, 500, 700)
- **Display**: CormorantSC

---

## 🧪 Testing

```bash
# Run tests
flutter test

# Check for issues
flutter analyze

# Build for production
flutter build apk --release
flutter build ios --release
```

---

## 📄 Recent Updates

### Latest Features (v1.0.0)

✅ **Feedback System**
- Star rating (1-5)
- Optional text feedback
- User tracking
- Supabase integration

✅ **Location Permission Check**
- Startup location dialog
- Direct settings access
- Non-blocking warning

✅ **ETA Fix**
- Consistent arrival time
- Matches pre-navigation ETA
- No more dynamic recalculation

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Development Guidelines

- Follow Flutter best practices
- Use meaningful commit messages
- Add tests for new features
- Update documentation
- Maintain consistent code style

---

## 👥 Team

- **Developers**: Ved Jadhav, Aditya Rajput
- **Repository**: [ved-jadhav-10/traffinity-app](https://github.com/ved-jadhav-10/traffinity-app)

---

## 📞 Support

For support, email [ved.amit.jadhav@gmail.com](mailto:ved.amit.jadhav@gmail.com) or open an issue on GitHub.

---

## 🙏 Acknowledgments

- **TomTom** for mapping and routing APIs
- **Supabase** for backend infrastructure
- **Flutter Team** for the amazing framework
- **OpenStreetMap** for geocoding services
- **Indian Railways** for train data

---

## 📊 Stats

- **20+ Screens**
- **12 Services**
- **8 Data Models**
- **6 Third-party APIs**
- **7+ Database Tables**
- **3 Auth Methods**
- **8+ Transport Modes**

---

<div align="center">

**Built with ❤️ for India's Urban Mobility**

[⭐ Star this repo](https://github.com/ved-jadhav-10/traffinity-app) • [🐛 Report Bug](https://github.com/ved-jadhav-10/traffinity-app/issues) • [💡 Request Feature](https://github.com/ved-jadhav-10/traffinity-app/issues)

</div>

---

_Last Updated: November 8, 2025_
_Version: 1.0.0_
