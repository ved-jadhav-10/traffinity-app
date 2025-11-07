import 'dart:convert';
import 'package:http/http.dart' as http;

class WeatherService {
  static final WeatherService _instance = WeatherService._internal();
  factory WeatherService() => _instance;
  WeatherService._internal();

  final String _apiKey = '3f17cc8fc635e6b29600fb3de9e788fa';
  final String _baseUrl = 'https://api.openweathermap.org/data/2.5';

  /// Get current weather for a location
  Future<WeatherData?> getCurrentWeather(double lat, double lon) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/weather?lat=$lat&lon=$lon&appid=$_apiKey&units=metric',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WeatherData.fromJson(data);
      }
      return null;
    } catch (e) {
      print('Error fetching current weather: $e');
      return null;
    }
  }

  /// Get weather forecast for next few hours
  Future<List<WeatherForecast>> getHourlyForecast(
    double lat,
    double lon, {
    int hours = 12,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/forecast?lat=$lat&lon=$lon&appid=$_apiKey&units=metric&cnt=${(hours / 3).ceil()}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['list'] as List;

        return list
            .take(hours ~/ 3)
            .map((item) => WeatherForecast.fromJson(item))
            .toList();
      }
      return [];
    } catch (e) {
      print('Error fetching forecast: $e');
      return [];
    }
  }

  /// Calculate weather impact on travel time (percentage increase)
  double calculateWeatherImpact(WeatherData weather) {
    // Base impact factors
    double impactFactor = 0.0;

    // Rain impact (0-20% depending on intensity)
    if (weather.rain1h != null && weather.rain1h! > 0) {
      if (weather.rain1h! > 10) {
        impactFactor += 0.20; // Heavy rain: 20% slower
      } else if (weather.rain1h! > 5) {
        impactFactor += 0.15; // Moderate rain: 15% slower
      } else {
        impactFactor += 0.10; // Light rain: 10% slower
      }
    }

    // Snow impact (10-30% depending on intensity)
    if (weather.snow1h != null && weather.snow1h! > 0) {
      if (weather.snow1h! > 5) {
        impactFactor += 0.30; // Heavy snow: 30% slower
      } else if (weather.snow1h! > 2) {
        impactFactor += 0.20; // Moderate snow: 20% slower
      } else {
        impactFactor += 0.15; // Light snow: 15% slower
      }
    }

    // Wind impact (0-10% for strong winds)
    if (weather.windSpeed > 15) {
      impactFactor += 0.10; // Strong winds: 10% slower
    } else if (weather.windSpeed > 10) {
      impactFactor += 0.05; // Moderate winds: 5% slower
    }

    // Visibility impact (fog, mist)
    if (weather.visibility < 1000) {
      impactFactor += 0.15; // Poor visibility: 15% slower
    } else if (weather.visibility < 5000) {
      impactFactor += 0.10; // Reduced visibility: 10% slower
    }

    return impactFactor;
  }

  /// Get weather description for display
  String getWeatherImpactDescription(WeatherData weather) {
    final impact = calculateWeatherImpact(weather);

    if (impact >= 0.25) {
      return 'Severe weather impact';
    } else if (impact >= 0.15) {
      return 'Significant weather delays';
    } else if (impact >= 0.10) {
      return 'Moderate weather impact';
    } else if (impact > 0) {
      return 'Minor weather delays';
    } else {
      return 'No weather impact';
    }
  }
}

class WeatherData {
  final String description;
  final String main;
  final double temp;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int visibility;
  final double? rain1h;
  final double? snow1h;
  final DateTime dateTime;

  WeatherData({
    required this.description,
    required this.main,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.visibility,
    this.rain1h,
    this.snow1h,
    required this.dateTime,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];

    return WeatherData(
      description: weather['description'] ?? '',
      main: weather['main'] ?? '',
      temp: (main['temp'] as num).toDouble(),
      feelsLike: (main['feels_like'] as num).toDouble(),
      humidity: main['humidity'] as int,
      windSpeed: (wind['speed'] as num).toDouble(),
      visibility: json['visibility'] as int? ?? 10000,
      rain1h: json['rain']?['1h']?.toDouble(),
      snow1h: json['snow']?['1h']?.toDouble(),
      dateTime: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000),
    );
  }
}

class WeatherForecast {
  final DateTime dateTime;
  final double temp;
  final String description;
  final String main;
  final double? rain3h;
  final double? snow3h;
  final double windSpeed;
  final int visibility;

  WeatherForecast({
    required this.dateTime,
    required this.temp,
    required this.description,
    required this.main,
    this.rain3h,
    this.snow3h,
    required this.windSpeed,
    required this.visibility,
  });

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'][0];
    final main = json['main'];
    final wind = json['wind'];

    return WeatherForecast(
      dateTime: DateTime.fromMillisecondsSinceEpoch((json['dt'] as int) * 1000),
      temp: (main['temp'] as num).toDouble(),
      description: weather['description'] ?? '',
      main: weather['main'] ?? '',
      rain3h: json['rain']?['3h']?.toDouble(),
      snow3h: json['snow']?['3h']?.toDouble(),
      windSpeed: (wind['speed'] as num).toDouble(),
      visibility: json['visibility'] as int? ?? 10000,
    );
  }
}
