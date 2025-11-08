# Traffinity App - Complete Feature Documentation

## 📱 Application Overview

**Traffinity** is a comprehensive smart transportation and navigation app designed for Indian cities, combining real-time traffic intelligence, live navigation, public transport tracking, and city event monitoring.

---

## 🎯 Core Navigation System

### 1. **Bottom Navigation Bar (3 Main Sections)**

- **Transport** (Index 0): Public transport & sustainability features
- **Traffinity/Map** (Index 1): Main map interface with navigation
- **Territory** (Index 2): City features, incidents, events, collections

---

## 🗺️ CATEGORY 1: MAP & NAVIGATION FEATURES

### **1.1 Interactive TomTom Map**

- **Dark Theme Night Mode**: TomTom tiles with night styling
- **Real-time User Location Tracking**:
  - GPS-based positioning with 10-meter distance filter
  - Blue circular marker with navigation icon
  - Continuous position updates via Geolocator stream
- **Compass Integration**:
  - FlutterCompass for orientation tracking
  - Compass button to reset map rotation and recenter
  - Transform rotation based on device heading
- **Map Tile Caching**:
  - Cached tile provider for offline map access
  - Map tile cache manager for persistent storage
  - Improved performance and reduced data usage

### **1.2 Location Search & Autocomplete**

- **TomTom Search Integration**: Up to 5 suggestions per query
- **Voice Search**: Speech-to-text integration for hands-free searching
- **Search History**:
  - Recent searches stored in Supabase
  - Duplicate removal based on coordinates
  - Quick access to previous locations
- **Favorites System**:
  - Save/unsave locations to Supabase
  - Heart icon toggle in search results
  - Dedicated favorites view with horizontal slider
  - Collection organization

### **1.3 Route Planning & Calculation**

- **Smart Route Calculation**:
  - Primary route with TomTom routing API
  - Up to 3 alternative routes comparison
  - Real-time traffic integration
  - Distance, time, and ETA display
- **Multi-Stop Waypoints**:
  - Add unlimited stops (A → B → C → D...)
  - Drag-to-reorder waypoint functionality
  - Remove individual waypoints
  - Visual waypoint numbering on map (1, 2, 3...)
- **Route Optimization**:
  - TomTom Waypoint Optimization API
  - Automatically reorder stops for fastest route
  - One-click optimize button
  - Preserves start and end locations

### **1.4 Advanced Route Intelligence**

- **Traffic Analysis**:
  - Real-time traffic flow overlays (green/yellow/orange/red)
  - Traffic level indicators (Light/Moderate/Heavy/Severe)
  - Live traffic flow polylines on map
  - Traffic section breakdown with color coding
- **Weather Impact Analysis**:
  - Current and destination weather data
  - Weather impact calculation on travel time
  - Weather icons and conditions display
  - Delay estimates due to weather
- **Optimal Departure Times**:
  - Calculate best time to leave (next 6 hours)
  - Traffic prediction integration
  - Time savings comparison
  - Formatted departure time suggestions
- **Alternative Route Comparison**:
  - Side-by-side route comparison
  - Reason for route selection display
  - Switch to alternative routes with one tap
  - Visual route ranking

### **1.5 Live Turn-by-Turn Navigation**

- **Real-time Navigation Screen**:
  - Full-screen map view during navigation
  - Current speed display (km/h)
  - Distance to next turn
  - Total distance remaining
  - Estimated Time of Arrival (ETA)
  - Live traffic updates during navigation
- **Voice Guidance**:
  - Text-to-speech announcements
  - Turn-by-turn instructions
  - Distance-based announcements (500m, 100m, 30m)
  - Mute/unmute toggle
  - Customizable voice settings
- **Navigation Intelligence**:
  - Off-route detection (30m threshold)
  - Automatic rerouting
  - GPS noise filtering (20m accuracy threshold)
  - Speed validation (rejects >150 km/h spikes)
  - Instruction advancement system
  - Arrival detection (50m threshold)
- **Visual Navigation Elements**:
  - Top instruction card with maneuver icon
  - Bottom stats footer (ETA, Distance, Speed)
  - Route polyline with traffic colors
  - Current position marker (car icon)
  - Direction-specific icons (left, right, U-turn, roundabout, etc.)

### **1.6 Nearby Places Discovery**

- **Category-Based Search**:
  - **Petrol Stations** (petrol-pump.png)
  - **Restaurants & Cafes** (restaurant.png)
  - **Parking** (parking.png) - Street, garage, and lot types
  - **EV Charging Stations** (charging-station.png)
  - **ATMs** (atm.png) - ATM and cash dispenser
  - **Hotels** (hotel.png) - Hotels, motels, resorts, hostels
  - **Hospitals** (hospital.png)
- **Search Features**:
  - Radius-based search around user location
  - Multiple type combinations per category
  - Custom marker icons for each category
  - Toggle categories on/off
  - Result count display
- **Place Information**:
  - Name, address, coordinates
  - Distance from user
  - Get directions integration
  - Save to favorites
  - View on map with marker

---

## 🚨 CATEGORY 2: CITY INCIDENT & TRAFFIC MONITORING

### **2.1 City Incident Map Screen**

- **Dual Data Sources**:
  - **User-Submitted Incidents**: Supabase database
  - **TomTom Live Incidents**: Real-time API data
- **Incident Types**:
  - Accidents (red marker with crash icon)
  - Traffic Jams (orange marker)
  - Road Work (yellow marker)
  - Weather Delays (blue marker)
  - Events (purple marker)
- **Severity Levels**: Minor, Moderate, Severe
- **Incident Reporting**:
  - Quick report button
  - Type selection
  - Severity selection
  - Duration estimation
  - Description field
  - Auto-location detection
  - Photo upload capability
  - Anonymous or named reporting

### **2.2 Live Traffic Flow Visualization**

- **Real-Time Traffic Data**:
  - TomTom Traffic Flow API
  - Bounding box calculation (20km radius)
  - Traffic flow polylines with color coding:
    - Green: Free flow
    - Yellow: Moderate
    - Orange: Heavy
    - Red: Severe congestion
- **Traffic Refresh**:
  - Auto-refresh every 30 seconds
  - Manual refresh button
  - Map move debouncing
  - Zoom-based granularity (zoom 12)

### **2.3 Incident Details & Management**

- **Incident Information Display**:
  - Type badge with color coding
  - Severity indicator
  - Exact location address
  - Timestamp (relative: "2 hours ago")
  - Description
  - Duration estimate
  - Submitted by user info
  - Photo gallery (if available)
- **User Actions**:
  - View full details in modal
  - Get directions to/from incident
  - Report similar incident
  - Mark as resolved (own incidents)
  - Share incident information

### **2.4 Emergency SOS System**

- **SOS Incident Reporting**:
  - Dedicated SOS button (red, prominent)
  - Confirmation dialog with warning
  - Auto-location capture
  - Contact information inclusion
  - Severe accident categorization
  - 60-minute default duration
  - Notify nearby users
  - Emergency services alert integration
- **Safety Features**:
  - Double confirmation required
  - User contact details attached
  - Immediate visibility to all users
  - High-priority incident marker

---

## 🎉 CATEGORY 3: LIVE EVENTS TRACKING

### **3.1 Live Events Map Screen**

- **Multi-Source Event Aggregation**:
  - **Reddit API**: r/IndianEvents, city subreddits
  - **RSS Feeds**: Times of India, Hindustan Times
  - **User Submissions**: Supabase database
- **Supported Cities**: Mumbai, Delhi, Bangalore, Pune, Raipur
- **Event Types**:
  - Concerts (pink marker)
  - Hackathons (blue marker)
  - Festivals (orange marker)
  - Conferences (purple marker)
  - Expos (cyan marker)
  - Sports (green marker)
  - Other (gray marker)

### **3.2 Event Discovery & Display**

- **Event Information**:
  - Title and description
  - Location with coordinates
  - Start and end time
  - Estimated attendance
  - Traffic impact level (Low/Medium/High)
  - Event type categorization
  - Source attribution (Reddit/RSS/User)
- **Map Visualization**:
  - Color-coded event markers (event.png)
  - User location marker (blue navigation icon)
  - Event count banner at top
  - TomTom night theme map
- **Event Cards Slider**:
  - Horizontal scrolling at bottom
  - Event type badge
  - Location and time display
  - Tap to navigate indicator
  - Selected card highlighting:
    - Tinted background (15% opacity)
    - Thicker border (3px)
    - Stronger glow shadow
  - Auto-scroll to selected event

### **3.3 Event Interaction**

- **Card Actions**:
  - Tap to move map to event location
  - Tap to open event details modal
  - Visual selection feedback
- **Event Details Modal**:
  - Full event description
  - Exact location address
  - Date and time (formatted)
  - Attendee count estimate
  - Traffic impact indicator
  - Source information
  - User/public submission badge
- **Filtering & Sorting**:
  - Filter by event type
  - Show all events option
  - Real-time filter application
  - Event count updates

### **3.4 User Event Submission**

- **Add Event Feature**:
  - Floating Action Button (green)
  - Event title input
  - Description (optional)
  - Location field with **auto-detect**:
    - GPS location button (my_location icon)
    - Reverse geocoding with OpenStreetMap Nominatim
    - Address display with coordinate fallback
    - Direct coordinate storage (no re-geocoding)
  - Event type dropdown (7 types)
  - Expected crowd estimate
  - Traffic impact selection
  - Start/end time pickers
- **Geocoding Intelligence**:
  - Auto-detected location: Uses GPS coordinates directly
  - Manual location: Geocodes text to coordinates
  - Prevents double geocoding errors
  - Coordinate validation
  - City-based fallback

### **3.5 Event Deduplication**

- **Levenshtein Distance Algorithm**:
  - 70% similarity threshold
  - Title-based duplicate detection
  - Cross-source deduplication
  - Preserves unique events
- **Background Processing**:
  - Events load asynchronously
  - Non-blocking UI updates
  - Progress indicators
  - Error handling with retry

### **3.6 Event Database (Supabase)**

- **Schema Features**:
  - UUID primary keys
  - User submission tracking
  - Coordinate validation (-90 to 90 lat, -180 to 180 lng)
  - Time range validation (end > start)
  - Check constraints
  - Auto-timestamps (created_at, updated_at)
- **Security (RLS)**:
  - Public read access
  - Authenticated user create
  - Owner-only update/delete
  - CASCADE delete on user removal
- **Indexing**:
  - City index
  - Time-based indices
  - Coordinate index
  - Type index
  - Composite city+time index
- **Auto-Cleanup**:
  - Expired events removal (7 days after end)
  - Scheduled pg_cron job (optional)
  - Manual cleanup function

---

## 🚌 CATEGORY 4: PUBLIC TRANSPORT

### **4.1 Bus Search & Tracking**

- **Search Modes**:
  - **Stop to Stop**: Find routes between two bus stops
  - **Route Number**: Search by specific route number
- **City Coverage**: Mumbai, Delhi, Bangalore, Pune, Raipur
- **Bus Route Information**:
  - Route number and name
  - Frequency (every X minutes)
  - Operating hours (formatted)
  - Route path (array of stops)
  - Number of stops
  - Estimated travel time
  - Fare information
- **Search Features**:
  - Bus stop autocomplete
  - City-specific route database
  - Real-time (simulated) tracking
  - Next bus arrival predictions
- **Display**:
  - Route cards with color coding
  - Stop list with arrival times
  - Map view option
  - Save favorite routes

### **4.2 Train Search & Schedules**

- **Indian Railways Integration**:
  - Live train running status
  - PNR status checking
  - Train schedule lookup
  - Station-to-station search
- **Train Information**:
  - Train number and name
  - Source and destination
  - Departure and arrival times
  - Stops en route
  - Class availability
  - Current location (live tracking)
  - Delay information
- **Station Schedule**:
  - Arriving trains
  - Departing trains
  - Platform information
  - Expected delays
- **Search Capabilities**:
  - Train number search
  - Station name search
  - Route search
  - PNR verification

### **4.3 My Trips Planning**

- **Trip Management**:
  - Create new trips
  - Save trip details
  - View trip history
  - Edit/delete trips
- **Trip Information**:
  - Start and end locations
  - Date and time
  - Transport mode selection
  - Notes and reminders
  - Cost tracking
  - Carbon footprint calculation

---

## 🌱 CATEGORY 5: SUSTAINABILITY & IMPACT

### **5.1 Environmental Impact Calculator**

- **Transport Mode Comparison**:
  - Walking
  - Cycling
  - Electric Scooter
  - Metro
  - Bus
  - Auto-rickshaw
  - Personal Car
  - Cab/Taxi
- **Calculation Metrics**:
  - Distance-based CO₂ emissions
  - Cost per kilometer
  - Time estimates
  - Health benefits (walking/cycling)
  - Calories burned
- **Impact Display**:
  - Carbon footprint (kg CO₂)
  - Money saved vs. car
  - Environmental impact rating
  - Visual comparisons
  - Recommendations

### **5.2 Eco-Friendly Routing**

- **Green Route Options**:
  - Public transport prioritization
  - Cycling route suggestions
  - Walking path recommendations
  - EV charging station locations
- **Sustainability Metrics**:
  - Carbon savings display
  - Eco-score for routes
  - Green alternative suggestions

---

## 📍 CATEGORY 6: COLLECTIONS & FAVORITES

### **6.1 Collection Management**

- **Create Collections**:
  - Custom collection names
  - Optional descriptions
  - Color themes
  - Icon selection
  - Creation timestamps
- **Collection Features**:
  - Unlimited collections per user
  - Organize locations by category
  - Share collections
  - Export collection data
- **User Interface**:
  - Grid view with cards
  - Location count per collection
  - Visual color indicators
  - Quick access buttons

### **6.2 Location Management**

- **Add Locations to Collections**:
  - Search and add
  - Map selection
  - Manual coordinate entry
  - Import from favorites
- **Location Details**:
  - Name and address
  - Coordinates (lat/lng)
  - Custom notes
  - Photos (up to 5)
  - Category tags
  - Visit count
  - Rating (5-star)
  - Last visited date
- **Location Actions**:
  - View on map
  - Get directions
  - Edit details
  - Remove from collection
  - Share location
  - Add to other collections

### **6.3 Collection Features**

- **Detailed Collection View**:
  - Full location list
  - Map view with all locations
  - Filter and sort options
  - Bulk actions
- **Collection Sharing**:
  - Share as link
  - Export as JSON
  - Collaborate with others
  - Import shared collections
- **Collection Statistics**:
  - Total locations
  - Most visited
  - Recent additions
  - Coverage area

---

## 👤 CATEGORY 7: USER PROFILE & AUTHENTICATION

### **7.1 Authentication Methods**

- **Email/Password**:
  - Sign up with email
  - Email verification
  - Password reset
  - Secure password hashing (Supabase Auth)
- **Google OAuth**:
  - One-tap Google Sign-In
  - Account picker
  - Automatic profile creation
  - Token-based authentication
- **Phone Authentication**:
  - OTP-based verification
  - SMS delivery
  - Phone number verification
  - Resend OTP functionality
- **Session Management**:
  - Persistent login
  - Auto-logout on security issues
  - Multi-device support
  - Secure token storage (flutter_secure_storage)

### **7.2 User Profile Management**

- **Profile Information**:
  - Full name (first & last)
  - Email address
  - Phone number
  - Profile picture
  - User metadata
  - Account creation date
- **Vehicle Management**:
  - Add up to 3 vehicles
  - Vehicle types: Car, Bike, Scooter, Other
  - Model information
  - Fuel type: Petrol, Diesel, Electric, CNG
  - Default vehicle selection
  - Delete vehicles
- **Profile Features**:
  - Edit personal information
  - Change password
  - Update phone number
  - Manage vehicles
  - View account statistics
  - Privacy settings

### **7.3 User Data & Preferences**

- **Saved Data**:
  - Search history
  - Recent searches (top 3 displayed)
  - Favorite locations
  - Collections
  - Trip history
  - Vehicle preferences
- **App Settings**:
  - Theme preferences
  - Notification settings
  - Language selection
  - Privacy controls
  - Data management

---

## 🎨 CATEGORY 8: UI/UX FEATURES

### **8.1 Onboarding Experience**

- **3-Screen Onboarding**:
  1. Smart routing introduction
  2. Real-time city monitoring
  3. Public transport tracking
- **Features**:
  - Swipe navigation
  - Progress indicators
  - Skip to end option
  - Animated transitions
  - Custom imagery with frames
  - Sign up/Sign in CTAs

### **8.2 Splash Screen**

- **App Launch**:
  - Traffinity logo display
  - Brand color (0xFF06d6a0)
  - Loading animation
  - Auto-navigation to onboarding/home
  - Authentication check

### **8.3 Design System**

- **Color Palette**:
  - Primary Green: #06d6a0
  - Background Dark: #1c1c1c
  - Card Background: #2a2a2a
  - Divider: #3a3a3a
  - Text Primary: #f5f6fa
  - Text Secondary: #9e9e9e
  - Error Red: #f54748
  - Warning Orange: #ffa726
  - Info Blue: #4a90e2
- **Typography**:
  - Primary Font: Poppins
  - Display Font: CormorantSC
  - Font weights: Light (300), Regular (400), Medium (500), Bold (700)
- **Components**:
  - Rounded corners (8px, 12px, 16px, 20px)
  - Card shadows and elevation
  - Gradient buttons
  - Custom icons and markers
  - Consistent spacing (8px, 12px, 16px, 24px)

### **8.4 Interactive Elements**

- **Gestures**:
  - Swipe navigation
  - Tap interactions
  - Long press actions
  - Drag and drop (waypoints)
  - Pinch to zoom (map)
  - Double tap to zoom
- **Feedback**:
  - Haptic feedback
  - Visual state changes
  - Loading indicators
  - Success/error snackbars
  - Modal bottom sheets
  - Toast notifications

---

## 🔧 CATEGORY 9: TECHNICAL INFRASTRUCTURE

### **9.1 Backend Services**

- **Supabase Integration**:
  - PostgreSQL database
  - Row Level Security (RLS)
  - Real-time subscriptions
  - Authentication service
  - Storage buckets
  - Edge functions (potential)
- **Database Tables**:
  - `profiles`: User information
  - `traffic_incidents`: User-reported incidents
  - `live_events`: Event submissions
  - `favorites`: Saved locations
  - `collections`: Location collections
  - `collection_locations`: Collection items
  - `recent_searches`: Search history
  - `trips`: Planned trips

### **9.2 Third-Party APIs**

- **TomTom APIs**:
  - Search/Geocoding
  - Routing
  - Traffic Flow
  - Traffic Incidents
  - Waypoint Optimization
  - Map Tiles
- **OpenStreetMap**:
  - Nominatim geocoding (reverse)
  - Tile layers (cached)
  - Place search
- **Reddit API**:
  - Subreddit search
  - Post scraping
  - Event extraction
- **RSS Feeds**:
  - News aggregation
  - Event parsing
  - XML to JSON conversion
- **Google Services**:
  - Google Sign-In
  - OAuth authentication
- **Indian Railways**:
  - Train running status
  - PNR status
  - Schedule information

### **9.3 Data Models**

- **Location Model**: SearchResult, LatLng, Address
- **Route Model**: RouteInfo, RouteInstruction, NavigationState
- **Traffic Model**: TrafficFlowSegment, TrafficSection, DepartureTimeOption
- **Incident Model**: TrafficIncident, TomTomIncident
- **Event Model**: LiveEvent
- **Collection Model**: Collection, CollectionLocation
- **Trip Model**: Trip planning data

### **9.4 Device Features**

- **Sensors**:
  - GPS/Location services
  - Compass/Magnetometer
  - Accelerometer (potential)
- **Hardware**:
  - Camera (incident photos)
  - Microphone (voice search)
  - Speaker (voice guidance)
  - Storage (caching)
- **Permissions**:
  - Location (always/when in use)
  - Camera
  - Microphone
  - Storage
  - Network state

### **9.5 Performance Optimizations**

- **Caching**:
  - Map tile caching
  - API response caching
  - Image caching
  - Search history caching
- **Lazy Loading**:
  - Event loading (background)
  - Image lazy loading
  - Pagination (future)
- **State Management**:
  - Provider pattern
  - StreamControllers
  - FutureBuilders
  - Efficient rebuilds

---

## 🔐 CATEGORY 10: SECURITY & PRIVACY

### **10.1 Data Protection**

- **Encryption**:
  - Secure token storage
  - HTTPS for all API calls
  - Encrypted database connections
  - Secure password hashing
- **Authentication Security**:
  - JWT tokens
  - Token expiration
  - Refresh token rotation
  - Multi-factor authentication ready

### **10.2 Privacy Features**

- **User Control**:
  - Anonymous incident reporting option
  - Location sharing controls
  - Data deletion options
  - Privacy settings
- **Data Minimization**:
  - Collect only necessary data
  - Auto-cleanup of old data
  - User consent for sharing
  - GDPR-ready architecture

### **10.3 Row Level Security (RLS)**

- **Profiles**: User can only access own profile
- **Incidents**: Public read, authenticated create, owner update/delete
- **Events**: Public read, authenticated create, owner update/delete
- **Collections**: Owner-only access
- **Favorites**: Owner-only access
- **Searches**: Owner-only access

---

## 📊 CATEGORY 11: ANALYTICS & MONITORING

### **11.1 User Activity Tracking**

- **Search Analytics**:
  - Popular searches
  - Search frequency
  - Location patterns
  - Time-based trends
- **Route Analytics**:
  - Common routes
  - Average trip duration
  - Popular destinations
  - Route preferences

### **11.2 Performance Monitoring**

- **App Performance**:
  - Load times
  - API response times
  - Error rates
  - Crash reports
- **User Engagement**:
  - Daily active users
  - Session duration
  - Feature usage
  - Retention rates

---

## 🚀 CATEGORY 12: COMING SOON FEATURES

### **12.1 Planned Features**

- **Public Transport**:
  - Metro integration
  - Bus live tracking
  - Transit pass integration
  - Multimodal route planning
- **Social Features**:
  - Share trips with friends
  - Carpooling suggestions
  - Community incident reports
  - User reviews and ratings
- **Advanced Navigation**:
  - Lane guidance
  - 3D maps
  - AR navigation
  - Offline maps
- **Sustainability**:
  - Carbon offset purchases
  - Green route challenges
  - Eco-driving tips
  - Reward system

### **12.2 Territory Features (Under Development)**

- "Explore Nearby" feature
- Additional city services
- Local business integration
- Tourist guides

---

## 📱 CATEGORY 13: PLATFORM SUPPORT

### **13.1 Supported Platforms**

- Android (Primary)
- iOS (Primary)
- Web (Limited)
- Linux (Desktop - experimental)
- macOS (Desktop - experimental)
- Windows (Desktop - experimental)

### **13.2 Minimum Requirements**

- **Android**: API 21+ (Android 5.0 Lollipop)
- **iOS**: iOS 12.0+
- **Flutter SDK**: 3.9.2+
- **Dart SDK**: 3.9.2+

---

## 🎯 KEY DIFFERENTIATORS

### **What Makes Traffinity Unique:**

1. **India-Focused**: Tailored for Indian cities, traffic patterns, and transport
2. **Multi-Source Intelligence**: Combines official APIs, social media, and user reports
3. **Sustainability First**: Built-in carbon footprint tracking and eco-routing
4. **Complete Transport Solution**: Single app for driving, public transport, and walking
5. **Real-Time Everything**: Live traffic, events, incidents, and navigation
6. **Smart Features**: AI-powered route optimization, duplicate detection, weather impact
7. **User Empowerment**: Report incidents, submit events, create collections
8. **Privacy-Conscious**: Strong RLS, data minimization, user control

---

## 📈 FEATURE MATURITY LEVELS

### **Production Ready** ✅

- User authentication (all methods)
- Map navigation and search
- Route calculation
- Live navigation
- Traffic monitoring
- Incident reporting
- Favorites and collections
- User profiles

### **Beta/Testing** 🧪

- Live events tracking
- Bus search
- Train search
- Impact calculator
- Weather integration
- Optimal departure times

### **In Development** 🚧

- My trips planning
- Delay alerts
- Explore nearby (partial)
- Social features
- Advanced analytics

---

## 📝 TOTAL FEATURE COUNT

**Screens**: 20+ screens
**Services**: 12 services
**Models**: 8 data models
**APIs**: 6 third-party integrations
**Database Tables**: 7+ tables
**Authentication Methods**: 3 (Email, Google, Phone)
**Transport Modes**: 8+ modes
**Event Types**: 7 types
**Incident Types**: 5 types
**Collection Features**: Full CRUD operations

---

## 🏆 CONCLUSION

Traffinity is a **comprehensive, feature-rich transportation platform** that combines:

- **Smart Navigation** with real-time traffic and weather
- **Public Transport** integration for sustainable travel
- **City Intelligence** with live events and incident tracking
- **User Empowerment** through reporting and collections
- **Environmental Impact** awareness and tracking

The app serves as a **one-stop solution** for all urban mobility needs in India, with a strong focus on **user experience, data accuracy, and environmental sustainability**.

---

_Last Updated: November 8, 2025_
_Version: 1.0.0_
_Platform: Flutter_
