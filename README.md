# 🚗 Traffinity - Smart Navigation & Urban Mobility Platform

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.9.2+-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.9.2+-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-Database-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![TomTom](https://img.shields.io/badge/TomTom-Maps_API-FF6C00?style=for-the-badge&logo=tomtom&logoColor=white)

---

**A comprehensive smart transportation and navigation platform designed for Indian cities**

[Features](#-key-features) • [Installation](#-installation) • [Architecture](#-architecture) • [ParkHub](#-parkhub-parking-management) • [Contributing](#-contributing)

</div>

---

## 📱 Overview

**Traffinity** is an all-in-one smart transportation app that combines real-time traffic intelligence, turn-by-turn navigation, public transport tracking, city event monitoring, and parking management. Built specifically for Indian cities, it integrates multiple data sources to provide the most accurate and comprehensive mobility solution.

### 🎯 Core Capabilities

- **🗺️ Smart Navigation**: Real-time traffic-aware routing with voice guidance
- **🚌 Public Transport**: Bus & train schedules, live tracking, and route planning
- **🚨 City Intelligence**: Live traffic incidents, events, and city monitoring
- **🅿️ ParkHub**: Smart parking discovery and booking system
- **🌱 Sustainability**: Carbon footprint tracking and eco-friendly route options
- **📍 Collections**: Organize and save your favorite places
- **👤 User Profiles**: Personalized experience with vehicle management

---

## ✨ Key Features

### 🗺️ Navigation & Routing

- **Turn-by-turn navigation** with voice guidance (500m, 100m, 30m alerts)
- **Real-time traffic** integration with color-coded overlays
- **Multi-stop waypoints** with drag-to-reorder functionality
- **Route optimization** using TomTom Waypoint API
- **Alternative routes** comparison with traffic analysis
- **Weather impact** calculation on travel time
- **Optimal departure times** based on traffic predictions
- **Offline map** support with tile caching
- **Off-route detection** with automatic rerouting (>30m threshold)

### 🔍 Smart Search

- **Voice search** using speech-to-text
- **Location autocomplete** with TomTom Search API
- **Nearby places** discovery (restaurants, gas stations, ATMs, hospitals, parking, etc.)
- **Search history** with favorites system
- **Collections** to organize saved locations

### 🚨 Traffic & Incidents

- **Live traffic flow** visualization with color-coded routes
- **Real-time incidents** from TomTom + crowdsourced user reports
- **Incident reporting** with photo upload capability
- **Emergency SOS** button for critical situations
- **Traffic delay** predictions and alerts
- **Severity levels**: Minor, Moderate, Severe
- **Incident types**: Accidents, traffic jams, road work, hazards, closures, weather delays

### 🎉 Live Events

- **Multi-source events** (Reddit, RSS feeds, user submissions)
- **Event types**: Concerts, hackathons, festivals, conferences, expos, sports
- **Smart deduplication** using Levenshtein distance algorithm (70% similarity threshold)
- **Traffic impact** analysis for events
- **Event submission** with auto-location detection
- **Event filtering** by type and date
- **In-app navigation** to event locations

### 🅿️ ParkHub - Parking Management

A comprehensive parking discovery and booking system:

- **Interactive parking map** with real-time availability
- **Pre-assigned vehicle types** based on slot zones:
  - Zone A (A-*): 4-Wheeler slots
  - Zone B (B-*): 2-Wheeler slots  
  - Zone C (C-*): Heavy Motor Vehicle (HMV) slots
- **Smart slot filtering** by vehicle type
- **Real-time slot status**: Available, Occupied, Booked
- **Booking system** with pending approval workflow
- **In-app notifications** via SnackBar (no email required)
- **Booking management**:
  - View active bookings with countdown timers
  - Track pending approval requests
  - Access booking history
  - Cancel bookings
- **Parking layouts** with detailed facility information
- **Dynamic pricing** per vehicle type
- **Live updates** via Supabase real-time subscriptions
- **User-friendly booking form** with vehicle validation

### 🚌 Public Transport

- **Bus search** (stop-to-stop & route number)
- **Train tracking** with Indian Railways integration
- **Live status** and PNR checking
- **Schedule lookup** with platform information
- **Trip planning** and history
- **Multi-modal routing** with transfers

### 🌱 Environmental Impact

- **Carbon footprint** calculator for each route
- **Transport mode** comparison (walking, cycling, metro, car, bus, etc.)
- **Eco-friendly routing** suggestions
- **Cost analysis** and savings tracking
- **Emissions data** per trip

### 🏙️ City Monitoring

- **Civic issue reporting**: Potholes, garbage, street lights, water leaks
- **Photo documentation** for reported issues
- **Issue tracking** with status updates
- **Community-driven** problem solving
- **Geolocation-based** issue mapping

### 👤 User Features

- **Multiple auth methods**: Email, Google OAuth, Phone OTP
- **Vehicle management**: Add up to 3 vehicles with fuel types
- **Profile customization** with photo upload
- **Favorites & collections** with full CRUD operations
- **Feedback system** with star ratings (1-5) and text reviews
- **Trip history** with detailed statistics
- **Personalized settings** and preferences

---

## 🛠️ Technology Stack

### Frontend
- **Framework**: Flutter 3.9.2+
- **Language**: Dart 3.9.2+
- **State Management**: Provider pattern, StreamControllers, TabControllers
- **Maps**: flutter_map 7.0.2 with TomTom tiles
- **UI Components**: Material Design 3 with custom dark theme
- **Animations**: Smooth transitions and loading states

### Backend & Services
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth (Email, OAuth, Phone)
- **Storage**: Supabase Storage for images
- **Security**: Row Level Security (RLS) policies
- **Real-time**: Supabase real-time subscriptions for live updates

### APIs & Integrations
- **TomTom APIs**: 
  - Routing API (route calculation)
  - Traffic API (real-time traffic flow)
  - Search API (POI search, autocomplete)
  - Geocoding API (address lookup)
  - Waypoint Optimization API
- **OpenStreetMap**: Nominatim reverse geocoding
- **Reddit API**: Live events scraping
- **RSS Feeds**: News aggregation for events
- **Google Sign-In**: OAuth 2.0 authentication
- **Indian Railways API**: Train tracking and PNR status

### Device Features
- **GPS**: Real-time location tracking with Geolocator
- **Compass**: Map orientation using flutter_compass
- **Camera**: Incident photo capture with image_picker
- **Microphone**: Voice search with speech_to_text
- **TTS**: Voice guidance during navigation with flutter_tts
- **Secure Storage**: Token encryption with flutter_secure_storage

### Database Schema
- **users/profiles**: User authentication and profile data
- **parking_layouts**: Parking facility details
- **parking_slots**: Individual slot information (slot_number, vehicle_type, status)
- **vehicle_types**: Pricing information (parking_layout_id, name, price_per_hour)
- **bookings**: Parking reservations (status: pending/approved/rejected/cancelled)
- **traffic_incidents**: User-reported incidents
- **civic_issues**: Community-reported city problems
- **live_events**: Aggregated event data
- **collections**: User-organized location collections
- **feedback**: App ratings and reviews

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
   - Copy your project URL and anon key
   - Create `lib/config/supabase_config.dart`:
     ```dart
     class SupabaseConfig {
       static const String supabaseUrl = 'YOUR_SUPABASE_PROJECT_URL';
       static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
     }
     ```
   
   - **Set up database tables** in Supabase SQL Editor:
     ```sql
     -- profiles table
     CREATE TABLE profiles (
       id UUID PRIMARY KEY REFERENCES auth.users(id),
       name TEXT,
       email TEXT,
       phone TEXT,
       photo_url TEXT,
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- parking_layouts table
     CREATE TABLE parking_layouts (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       name TEXT NOT NULL,
       location TEXT NOT NULL,
       latitude DOUBLE PRECISION NOT NULL,
       longitude DOUBLE PRECISION NOT NULL,
       description TEXT,
       total_slots INTEGER DEFAULT 0,
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- parking_slots table (pre-assigned vehicle types by slot number)
     CREATE TABLE parking_slots (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       layout_id UUID REFERENCES parking_layouts(id) ON DELETE CASCADE,
       slot_number TEXT NOT NULL,
       vehicle_type VARCHAR(20) CHECK (vehicle_type IN ('2-Wheeler', '4-Wheeler', 'HMV')),
       status VARCHAR(20) DEFAULT 'available' CHECK (status IN ('available', 'occupied', 'booked')),
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- vehicle_types table (pricing per vehicle type)
     CREATE TABLE vehicle_types (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       parking_layout_id UUID REFERENCES parking_layouts(id) ON DELETE CASCADE,
       name TEXT NOT NULL,
       price_per_hour NUMERIC(10, 2) NOT NULL,
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- bookings table (parking reservations)
     CREATE TABLE bookings (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
       slot_id UUID REFERENCES parking_slots(id) ON DELETE CASCADE,
       vehicle_type_id UUID REFERENCES vehicle_types(id),
       vehicle_number TEXT NOT NULL,
       vehicle_type TEXT NOT NULL,
       user_name TEXT NOT NULL,
       duration INTEGER NOT NULL,
       booking_start_time TIMESTAMPTZ NOT NULL,
       booking_end_time TIMESTAMPTZ NOT NULL,
       status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled')),
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- traffic_incidents table
     CREATE TABLE traffic_incidents (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       user_id UUID REFERENCES auth.users(id),
       incident_type TEXT NOT NULL,
       severity TEXT NOT NULL,
       latitude DOUBLE PRECISION NOT NULL,
       longitude DOUBLE PRECISION NOT NULL,
       duration_minutes INTEGER,
       description TEXT,
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- feedback table
     CREATE TABLE feedback (
       id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
       user_id UUID REFERENCES auth.users(id),
       rating INTEGER CHECK (rating >= 1 AND rating <= 5),
       comments TEXT,
       created_at TIMESTAMPTZ DEFAULT NOW()
     );

     -- Enable Row Level Security
     ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
     ALTER TABLE bookings ENABLE ROW LEVEL SECURITY;
     ALTER TABLE traffic_incidents ENABLE ROW LEVEL SECURITY;

     -- RLS Policies
     CREATE POLICY "Users can view own profile" ON profiles
       FOR SELECT USING (auth.uid() = id);

     CREATE POLICY "Users can view own bookings" ON bookings
       FOR SELECT USING (auth.uid() = user_id);

     CREATE POLICY "Users can insert bookings" ON bookings
       FOR INSERT WITH CHECK (auth.uid() = user_id);
     ```

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
├── config/                    # Configuration files
│   ├── app_theme.dart        # Material 3 theme and colors
│   ├── supabase_config.dart  # Supabase credentials
│   └── tomtom_config.dart    # TomTom API key
│
├── models/                    # Data models
│   ├── civic_issue_model.dart
│   ├── collection_location_model.dart
│   ├── collection_model.dart
│   ├── location_model.dart
│   ├── parking_booking.dart
│   ├── parking_layout.dart
│   ├── parking_slot.dart
│   ├── traffic_incident_model.dart
│   ├── traffic_model.dart
│   ├── trip_model.dart
│   └── vehicle_type.dart
│
├── screens/                   # UI screens
│   ├── auth/                 # Authentication screens
│   │   ├── sign_in_screen.dart
│   │   ├── sign_up_screen.dart
│   │   ├── phone_sign_in_screen.dart
│   │   └── otp_verification_screen.dart
│   │
│   ├── parking/              # ParkHub parking management
│   │   ├── parkhub_map_screen.dart
│   │   ├── parking_layout_screen.dart
│   │   ├── booking_form_screen.dart
│   │   └── my_bookings_screen.dart
│   │
│   ├── profile/              # User profile
│   │   └── profile_screen.dart
│   │
│   ├── collections/          # Location collections
│   │   ├── collections_screen.dart
│   │   ├── collection_detail_screen.dart
│   │   └── add_to_collection_screen.dart
│   │
│   ├── feedback/             # User feedback
│   │   └── feedback_screen.dart
│   │
│   ├── transport/            # Public transport
│   │   ├── bus_search_screen.dart
│   │   └── train_search_screen.dart
│   │
│   ├── trips/                # Trip history
│   │   └── trips_screen.dart
│   │
│   ├── city_incident_map_screen.dart   # Traffic incident map
│   ├── civic_issue_map_screen.dart     # Civic issue reporting
│   └── live_events_map_screen.dart     # Live city events
│
├── services/                  # Business logic & API services
│   ├── supabase_service.dart        # Authentication & database
│   ├── parking_service.dart         # Parking bookings & slots
│   ├── tomtom_service.dart          # Routing & traffic
│   ├── tomtom_native_service.dart   # Native TomTom features
│   ├── navigation_service.dart      # Turn-by-turn navigation
│   ├── location_service.dart        # GPS & location
│   ├── geocoding_service.dart       # Address lookup
│   ├── weather_service.dart         # Weather data
│   ├── live_event_service.dart      # Event aggregation
│   ├── bus_service.dart             # Bus schedules
│   ├── indian_railways_service.dart # Train tracking
│   ├── collections_service.dart     # User collections
│   ├── cached_tile_provider.dart    # Map tile caching
│   └── map_tile_cache_manager.dart  # Cache management
│
├── widgets/                   # Reusable widgets
│   ├── map_home_page.dart    # Main map screen with hamburger menu
│   └── territory_page.dart   # Territory/city features page
│
├── main.dart                  # App entry point
├── home_page.dart             # Home screen with location check
├── splash_screen.dart         # Splash screen
└── onboarding_screen.dart     # First-time user onboarding
```

### Key Architectural Patterns

1. **Service Layer Pattern**: All business logic is in services, keeping screens clean
2. **Real-time Subscriptions**: Supabase streams for live data updates (bookings, incidents)
3. **State Management**: StatefulWidgets with StreamControllers and TabControllers
4. **Caching Strategy**: Map tiles and event data cached for offline support
5. **Modular Design**: Features separated into independent screens and services

---
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

### 🗺️ Navigation System

The navigation system uses a multi-layered approach:

1. **Route Calculation**: TomTom Routing API calculates optimal routes with real-time traffic
2. **Real-time Updates**: GPS stream updates position every 10 meters
3. **Voice Guidance**: Text-to-speech announces turns at 500m, 100m, and 30m
4. **Off-route Detection**: Automatically reroutes if user deviates >30m from path
5. **Traffic Integration**: Color-coded polylines show traffic conditions
6. **Weather Impact**: Calculates delays due to weather conditions
7. **ETA Consistency**: Fixed arrival time displayed before and during navigation

### 🚨 Incident Reporting

Users can report traffic incidents with:
- **Type selection**: Accident, traffic jam, road work, hazard, closure, weather delay
- **Severity levels**: Minor, Moderate, Severe
- **Photo upload** capability with camera integration
- **Duration estimates** (15min - 4+ hours)
- **Anonymous or named** reporting options
- **GPS auto-location** with manual adjustment
- **Real-time validation** to prevent spam
- **SOS emergency button** for critical situations

### 🎉 Event System

Events are aggregated from multiple sources with smart deduplication:
- **Reddit**: Scrapes Indian event subreddits (r/India, r/Mumbai, etc.)
- **RSS Feeds**: Parses news sites for events
- **User Submissions**: Direct event creation with location tagging
- **Deduplication**: 70% Levenshtein similarity threshold removes duplicates
- **Geocoding**: Smart location handling with coordinate storage
- **Caching**: 1-hour cache for improved performance
- **Traffic impact**: Analysis of event effects on nearby traffic

### 🅿️ ParkHub - Parking Management

Comprehensive parking booking system with real-time updates:

**Discovery & Search**
- Interactive map showing all parking facilities
- Real-time availability counter per layout
- Auto-refresh every 30 seconds
- Compass-enabled map orientation
- Distance calculation from current location

**Pre-assigned Vehicle Types**
Parking slots are organized by zones with fixed vehicle types:
- **Zone A (A-1, A-2, etc.)**: 4-Wheeler slots
- **Zone B (B-1, B-2, etc.)**: 2-Wheeler slots
- **Zone C (C-1, C-2, etc.)**: Heavy Motor Vehicle (HMV) slots

**Booking Flow**
1. Browse parking layouts on map
2. Select layout to view available slots
3. Filter slots by vehicle type (2-Wheeler/4-Wheeler/HMV)
4. Choose slot and duration (1-24 hours)
5. Enter vehicle details
6. Submit booking (status: "pending")
7. Receive in-app notification when approved
8. Access active booking with countdown timer

**My Bookings Screen** (accessible via hamburger menu)
- **Active Tab**: Current bookings with countdown timers
- **Pending Tab**: Awaiting approval with real-time status updates
- **Past Tab**: Booking history with details
- **SnackBar notifications**: No email required - instant in-app alerts
- **Real-time sync**: Supabase subscriptions for live updates
- **Cancel functionality**: Cancel pending/active bookings

**Admin Features** (available on website)
- Approve/reject booking requests
- Manage slot availability
- Update pricing dynamically
- And many more features for government bodies, do explore!

### 🚌 Public Transport

Comprehensive public transport integration:
- **Bus search**: Stop-to-stop routing and route number lookup
- **Train tracking**: Indian Railways API integration
- **Live status**: Real-time train running status
- **PNR checking**: Passenger Name Record status
- **Schedule lookup**: Departure times and platform information
- **Trip planning**: Save and view transport trip history

### 🌱 Environmental Impact

Track your environmental footprint:
- **Carbon calculator**: Estimate CO2 emissions per trip
- **Mode comparison**: Compare emissions across transport modes
- **Eco-routing**: Suggestions for greener alternatives
- **Cost analysis**: Calculate fuel costs vs public transport
- **Statistics**: View cumulative environmental impact

### 📍 Collections & Favorites

Organize your places:
- **Unlimited collections**: Create custom groups of locations
- **Customization**: Name, color, and icon selection
- **Multi-source adding**: Search, map pins, or manual entry
- **Photo attachments**: Up to 5 photos per location
- **Rating system**: 5-star ratings with notes
- **Visit tracking**: Mark and track visited places
- **Sharing**: Share collections with others
- **CRUD operations**: Full create, read, update, delete support

---

## 🔐 Security & Privacy

- **Encrypted Storage**: Authentication tokens stored with flutter_secure_storage
- **HTTPS Only**: All API calls use secure TLS connections
- **Row Level Security (RLS)**: Database-level access control in Supabase
- **Anonymous Options**: Report incidents without personal identification
- **Data Minimization**: Only essential data collected and stored
- **User Control**: Users can delete their data at any time
- **Authentication**: Multi-factor authentication support (Email + OTP, Phone OTP, OAuth)
- **Input Validation**: Profanity filter and content moderation on user inputs

---

## 📱 Platform Support

- ✅ **Android** (API 21+ / Android 5.0 Lollipop+)
- ✅ **iOS** (iOS 12.0+)
- 🚧 **Web** (Seperate website made my teammates Ansh Dudhe, Harshil Biyani for admin purposes)

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

- **App Developers**: Ved Jadhav, Aditya Rajput
- **Web Developers**: Ansh Dudhe, Harshil Biyani
- **Repository**: [ved-jadhav-10/traffinity-app](https://github.com/ved-jadhav-10/traffinity-app)
- **Repository**: [anshdudhe15/New_Traffinity_Website](https://github.com/anshdudhe15/New_Traffinity_Website)

---

## 📞 Support

For support, email [ved.amit.jadhav@gmail.com](mailto:ved.amit.jadhav@gmail.com) or open an issue on GitHub.

---

## 🙏 Acknowledgments

- **TomTom** for mapping and routing APIs
- **Supabase** for backend infrastructure
- **Flutter Team** for the amazing framework
- **OpenStreetMap** for geocoding services

---

## 📊 Stats

- **25+ Screens** (including parking management)
- **14 Services** (including parking_service.dart)
- **11 Data Models** (including parking models)
- **6+ Third-party APIs** (TomTom, Supabase, Reddit, Indian Railways, etc.)
- **10+ Database Tables** (including parking_slots, bookings, vehicle_types)
- **3 Auth Methods** (Email, Phone OTP, Google OAuth)
- **8+ Transport Modes** (Walking, cycling, car, bus, train, metro, etc.)
- **Real-time Features**: Live bookings, traffic incidents, events

---

<div align="center">

**Built with ❤️ for India's Urban Mobility**

[⭐ Star this repo](https://github.com/ved-jadhav-10/traffinity-app) • [🐛 Report Bug](https://github.com/ved-jadhav-10/traffinity-app/issues) • [💡 Request Feature](https://github.com/ved-jadhav-10/traffinity-app/issues)

</div>

---

_Last Updated: December 12, 2025_  
_Version: 1.0.0_