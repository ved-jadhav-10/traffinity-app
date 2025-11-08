import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'supabase_service.dart';

class LiveEventService {
  final SupabaseService _supabaseService = SupabaseService();

  // Get all events (Reddit + RSS + User-submitted)
  Future<List<LiveEvent>> getCityEvents(String city) async {
    try {
      final List<LiveEvent> allEvents = [];

      // 1. Get Reddit events
      final redditEvents = await _getRedditEvents(city);
      allEvents.addAll(redditEvents);

      // 2. Get RSS feed events
      final rssEvents = await _getRSSEvents(city);
      allEvents.addAll(rssEvents);

      // 3. Get user-submitted events from Supabase
      final userEvents = await _getUserSubmittedEvents(city);
      allEvents.addAll(userEvents);

      // Remove duplicates and sort by date
      final uniqueEvents = _removeDuplicates(allEvents);
      uniqueEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

      return uniqueEvents;
    } catch (e) {
      print('Error fetching events: $e');
      return [];
    }
  }

  // Reddit API - Search city subreddits
  Future<List<LiveEvent>> _getRedditEvents(String city) async {
    try {
      final subreddit = _getCitySubreddit(city);
      final searchTerms = [
        'concert',
        'festival',
        'event',
        'hackathon',
        'meetup',
        'gathering',
        'celebration',
        'conference',
      ];

      final List<LiveEvent> events = [];

      for (final term in searchTerms) {
        final url = Uri.parse(
          'https://www.reddit.com/r/$subreddit/search.json?q=$term&restrict_sr=1&sort=new&t=week&limit=25',
        );

        final response = await http.get(
          url,
          headers: {'User-Agent': 'Traffinity/1.0'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final posts = data['data']['children'] as List;

          for (var post in posts) {
            final postData = post['data'];
            final event = _parseRedditPost(postData, city);
            if (event != null) {
              events.add(event);
            }
          }
        }

        // Delay to avoid rate limiting
        await Future.delayed(const Duration(milliseconds: 500));
      }

      return events;
    } catch (e) {
      print('Reddit API error: $e');
      return [];
    }
  }

  // Parse Reddit post to LiveEvent
  LiveEvent? _parseRedditPost(Map<String, dynamic> postData, String city) {
    try {
      final title = postData['title'] as String;
      final description = postData['selftext'] as String? ?? '';
      final createdUtc = postData['created_utc'] as num;
      final permalink = postData['permalink'] as String;

      // Filter out non-event posts
      if (!_isEventPost(title, description)) {
        return null;
      }

      // Extract date/time if mentioned (basic parsing)
      final eventDate = _extractEventDate(title, description);

      return LiveEvent(
        id: postData['id'],
        title: title,
        description: description.length > 200
            ? '${description.substring(0, 200)}...'
            : description,
        location: _extractLocation(title, description, city),
        city: city,
        startTime:
            eventDate ??
            DateTime.fromMillisecondsSinceEpoch((createdUtc * 1000).toInt()),
        endTime: eventDate?.add(const Duration(hours: 3)),
        source: 'Reddit',
        sourceUrl: 'https://reddit.com$permalink',
        eventType: _categorizeEvent(title, description),
        estimatedAttendance: _estimateAttendance(title, description),
        trafficImpact: TrafficImpact.medium,
        latitude: null, // Will be geocoded
        longitude: null,
        isUserSubmitted: false,
      );
    } catch (e) {
      print('Error parsing Reddit post: $e');
      return null;
    }
  }

  // RSS Feeds - Times of India, Hindustan Times, etc.
  Future<List<LiveEvent>> _getRSSEvents(String city) async {
    try {
      final List<LiveEvent> events = [];
      final feeds = _getCityRSSFeeds(city);

      for (final feedUrl in feeds) {
        try {
          final response = await http.get(Uri.parse(feedUrl));
          if (response.statusCode == 200) {
            final feedEvents = _parseRSSFeed(response.body, city);
            events.addAll(feedEvents);
          }
        } catch (e) {
          print('RSS feed error for $feedUrl: $e');
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }

      return events;
    } catch (e) {
      print('RSS error: $e');
      return [];
    }
  }

  // Parse RSS XML (basic implementation)
  List<LiveEvent> _parseRSSFeed(String xmlContent, String city) {
    final List<LiveEvent> events = [];

    try {
      // Simple regex-based parsing (in production, use xml package)
      final itemPattern = RegExp(r'<item>(.*?)</item>', dotAll: true);
      final titlePattern = RegExp(r'<title>(.*?)</title>');
      final descPattern = RegExp(r'<description>(.*?)</description>');
      final linkPattern = RegExp(r'<link>(.*?)</link>');
      final pubDatePattern = RegExp(r'<pubDate>(.*?)</pubDate>');

      final items = itemPattern.allMatches(xmlContent);

      for (var item in items) {
        final itemContent = item.group(1) ?? '';

        final titleMatch = titlePattern.firstMatch(itemContent);
        final descMatch = descPattern.firstMatch(itemContent);
        final linkMatch = linkPattern.firstMatch(itemContent);
        final dateMatch = pubDatePattern.firstMatch(itemContent);

        if (titleMatch != null) {
          final title = _decodeHtml(titleMatch.group(1) ?? '');
          final description = _decodeHtml(descMatch?.group(1) ?? '');

          if (_isEventPost(title, description)) {
            final pubDate = dateMatch?.group(1);
            DateTime? eventDate;

            if (pubDate != null) {
              eventDate = _parseRSSDate(pubDate);
            }

            events.add(
              LiveEvent(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                title: title,
                description: description.length > 200
                    ? '${description.substring(0, 200)}...'
                    : description,
                location: _extractLocation(title, description, city),
                city: city,
                startTime: eventDate ?? DateTime.now(),
                endTime: eventDate?.add(const Duration(hours: 4)),
                source: 'RSS Feed',
                sourceUrl: linkMatch?.group(1) ?? '',
                eventType: _categorizeEvent(title, description),
                estimatedAttendance: _estimateAttendance(title, description),
                trafficImpact: TrafficImpact.medium,
                latitude: null,
                longitude: null,
                isUserSubmitted: false,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('RSS parse error: $e');
    }

    return events;
  }

  // Get user-submitted events from Supabase
  Future<List<LiveEvent>> _getUserSubmittedEvents(String city) async {
    try {
      final response = await SupabaseService.client
          .from('live_events')
          .select()
          .eq('city', city)
          .gte('end_time', DateTime.now().toIso8601String())
          .order('start_time', ascending: true);

      final List<LiveEvent> events = [];

      for (var eventData in response) {
        events.add(
          LiveEvent(
            id: eventData['id'],
            title: eventData['title'],
            description: eventData['description'] ?? '',
            location: eventData['location'],
            city: eventData['city'],
            startTime: DateTime.parse(eventData['start_time']),
            endTime: DateTime.parse(eventData['end_time']),
            source: 'User Submitted',
            sourceUrl: '',
            eventType: eventData['event_type'] ?? 'other',
            estimatedAttendance: eventData['estimated_attendance'] ?? 0,
            trafficImpact: _stringToTrafficImpact(eventData['traffic_impact']),
            latitude: eventData['latitude'],
            longitude: eventData['longitude'],
            isUserSubmitted: true,
          ),
        );
      }

      return events;
    } catch (e) {
      print('Error fetching user events: $e');
      return [];
    }
  }

  // Submit user event
  Future<bool> submitUserEvent(LiveEvent event) async {
    try {
      await SupabaseService.client.from('live_events').insert({
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'city': event.city,
        'start_time': event.startTime.toIso8601String(),
        'end_time':
            event.endTime?.toIso8601String() ??
            DateTime.now().add(const Duration(hours: 3)).toIso8601String(),
        'event_type': event.eventType,
        'estimated_attendance': event.estimatedAttendance,
        'traffic_impact': event.trafficImpact.toString().split('.').last,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'submitted_by': _supabaseService.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      print('Error submitting event: $e');
      return false;
    }
  }

  // Geocode location to coordinates
  Future<Map<String, double>?> geocodeLocation(
    String location,
    String city,
  ) async {
    try {
      // Using OpenStreetMap Nominatim (free, no API key needed)
      final query = '$location, $city, India';
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'Traffinity/1.0'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final result = data[0];
          return {
            'latitude': double.parse(result['lat']),
            'longitude': double.parse(result['lon']),
          };
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  // Helper methods
  String _getCitySubreddit(String city) {
    final subreddits = {
      'Mumbai': 'mumbai',
      'Delhi': 'delhi',
      'Bangalore': 'bangalore',
      'Pune': 'pune',
      'Raipur': 'chhattisgarh',
    };
    return subreddits[city] ?? 'india';
  }

  List<String> _getCityRSSFeeds(String city) {
    // Times of India RSS feeds
    return [
      'https://timesofindia.indiatimes.com/rssfeeds/${city.toLowerCase()}.cms',
      'https://www.hindustantimes.com/rss/${city.toLowerCase()}/rssfeed.xml',
    ];
  }

  bool _isEventPost(String title, String description) {
    final eventKeywords = [
      'event',
      'concert',
      'festival',
      'hackathon',
      'meetup',
      'gathering',
      'conference',
      'expo',
      'fair',
      'marathon',
      'rally',
      'protest',
      'celebration',
      'party',
      'show',
      'performance',
      'exhibition',
    ];

    final text = '${title.toLowerCase()} ${description.toLowerCase()}';
    return eventKeywords.any((keyword) => text.contains(keyword));
  }

  String _extractLocation(String title, String description, String city) {
    // Simple location extraction (can be enhanced with NLP)
    final text = '$title $description';
    final locationPattern = RegExp(
      r'(?:at|@|venue:|location:)\s+([A-Z][a-zA-Z\s]+(?:Stadium|Arena|Hall|Center|Park|Ground|Grounds))',
    );

    final match = locationPattern.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim() ?? city;
    }

    return city; // Default to city name
  }

  DateTime? _extractEventDate(String title, String description) {
    // Basic date extraction (can be enhanced)
    final text = '$title $description';
    final datePatterns = [
      RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'),
      RegExp(r'(today|tomorrow|this weekend)'),
    ];

    for (var pattern in datePatterns) {
      if (pattern.hasMatch(text)) {
        // Return approximate date
        return DateTime.now().add(const Duration(days: 1));
      }
    }

    return null;
  }

  String _categorizeEvent(String title, String description) {
    final text = '${title.toLowerCase()} ${description.toLowerCase()}';

    if (text.contains('concert') || text.contains('music')) return 'concert';
    if (text.contains('hackathon') || text.contains('tech')) return 'hackathon';
    if (text.contains('festival')) return 'festival';
    if (text.contains('conference') || text.contains('summit')) {
      return 'conference';
    }
    if (text.contains('expo') || text.contains('fair')) return 'expo';
    if (text.contains('sports') || text.contains('match')) return 'sports';

    return 'other';
  }

  int _estimateAttendance(String title, String description) {
    final text = '${title.toLowerCase()} ${description.toLowerCase()}';

    // Extract numbers mentioned
    final numberPattern = RegExp(r'(\d+)\s*(k|thousand|hundred)?');
    final matches = numberPattern.allMatches(text);

    for (var match in matches) {
      final number = int.tryParse(match.group(1) ?? '0') ?? 0;
      final multiplier = match.group(2);

      if (multiplier == 'k' || multiplier == 'thousand') {
        return number * 1000;
      } else if (number > 100) {
        return number;
      }
    }

    // Default estimates by event type
    if (text.contains('concert')) return 5000;
    if (text.contains('hackathon')) return 500;
    if (text.contains('festival')) return 10000;
    if (text.contains('conference')) return 1000;

    return 200; // Default
  }

  TrafficImpact _stringToTrafficImpact(String? impact) {
    switch (impact?.toLowerCase()) {
      case 'low':
        return TrafficImpact.low;
      case 'high':
        return TrafficImpact.high;
      default:
        return TrafficImpact.medium;
    }
  }

  DateTime? _parseRSSDate(String dateStr) {
    try {
      // RFC 822 format: "Mon, 01 Jan 2025 12:00:00 GMT"
      return DateFormat('EEE, dd MMM yyyy HH:mm:ss').parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  String _decodeHtml(String html) {
    return html
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('<[^>]*>', '');
  }

  List<LiveEvent> _removeDuplicates(List<LiveEvent> events) {
    final seen = <String>{};
    return events.where((event) {
      final key = event.title.toLowerCase().trim();
      if (seen.contains(key)) return false;
      seen.add(key);
      return true;
    }).toList();
  }

  // Calculate traffic impact based on attendance
  TrafficImpact calculateTrafficImpact(int attendance) {
    if (attendance < 500) return TrafficImpact.low;
    if (attendance < 2000) return TrafficImpact.medium;
    return TrafficImpact.high;
  }
}

// Models
class LiveEvent {
  final String id;
  final String title;
  final String description;
  final String location;
  final String city;
  final DateTime startTime;
  final DateTime? endTime;
  final String source;
  final String sourceUrl;
  final String eventType;
  final int estimatedAttendance;
  final TrafficImpact trafficImpact;
  double? latitude;
  double? longitude;
  final bool isUserSubmitted;

  LiveEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.city,
    required this.startTime,
    this.endTime,
    required this.source,
    required this.sourceUrl,
    required this.eventType,
    required this.estimatedAttendance,
    required this.trafficImpact,
    this.latitude,
    this.longitude,
    required this.isUserSubmitted,
  });
}

enum TrafficImpact {
  low, // < 500 people
  medium, // 500-2000 people
  high, // > 2000 people
}
