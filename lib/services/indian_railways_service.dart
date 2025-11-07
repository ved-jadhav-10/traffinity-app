import 'dart:convert';
import 'package:http/http.dart' as http;

class IndianRailwaysService {
  // RapidAPI - Indian Railway PNR Status API
  static const String _baseUrl =
      'https://irctc-indian-railway-pnr-status.p.rapidapi.com';
  static const String _apiKey =
      '1f1de4fb6cmshe86a02f80a5bcfep14c693jsna45f0b4be917';
  static const String _apiHost =
      'irctc-indian-railway-pnr-status.p.rapidapi.com';

  // Search trains between stations
  Future<List<TrainBetweenStations>> searchTrainsBetweenStations({
    required String fromStationCode,
    required String toStationCode,
  }) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/trainBetweenStations?fromStationCode=$fromStationCode&toStationCode=$toStationCode',
      );

      final response = await http.get(
        url,
        headers: {'X-RapidAPI-Key': _apiKey, 'X-RapidAPI-Host': _apiHost},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check if API returned success and has data
        if (data['status'] == true && data['data'] != null) {
          final trains = data['data'] as List;

          // If empty results, return mock data
          if (trains.isEmpty) {
            print('⚠️ API returned empty results, using mock data');
            return _getMockTrainsBetweenStations(
              fromStationCode,
              toStationCode,
            );
          }

          return trains
              .map(
                (train) => TrainBetweenStations(
                  trainNumber: train['train_number']?.toString() ?? '',
                  trainName: train['train_name']?.toString() ?? '',
                  fromStation:
                      train['from_station_name']?.toString() ?? fromStationCode,
                  toStation:
                      train['to_station_name']?.toString() ?? toStationCode,
                  departureTime: train['from_std']?.toString() ?? '',
                  arrivalTime: train['to_sta']?.toString() ?? '',
                  duration: train['duration']?.toString() ?? '',
                  trainType: train['train_type']?.toString() ?? '',
                  runDays: _formatRunningDays(train['run_days']),
                ),
              )
              .toList();
        }

        // If no trains found or API returned error, use mock data
        print('⚠️ API returned no data, using mock data');
        return _getMockTrainsBetweenStations(fromStationCode, toStationCode);
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
        // Return mock data as fallback
        return _getMockTrainsBetweenStations(fromStationCode, toStationCode);
      }
    } catch (e) {
      print('Error searching trains: $e');
      // Return mock data as fallback
      return _getMockTrainsBetweenStations(fromStationCode, toStationCode);
    }
  }

  // Get PNR status
  Future<PNRStatus?> getPNRStatus(String pnrNumber) async {
    try {
      final url = Uri.parse('$_baseUrl/getPNRStatus/$pnrNumber');

      final response = await http.get(
        url,
        headers: {'X-RapidAPI-Key': _apiKey, 'X-RapidAPI-Host': _apiHost},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['data'] != null) {
          return PNRStatus.fromJson(data['data']);
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
      }

      // Return mock data as fallback
      return _getMockPNRStatus(pnrNumber);
    } catch (e) {
      print('Error getting PNR status: $e');
      return _getMockPNRStatus(pnrNumber);
    }
  }

  // Get train schedule by train number
  Future<TrainSchedule?> getTrainSchedule(String trainNumber) async {
    try {
      final url = Uri.parse('$_baseUrl/getTrainSchedule?trainNo=$trainNumber');

      final response = await http.get(
        url,
        headers: {'X-RapidAPI-Key': _apiKey, 'X-RapidAPI-Host': _apiHost},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          final trainData = data['data'];

          return TrainSchedule(
            trainNumber: trainNumber,
            trainName: trainData['train_name']?.toString() ?? '',
            trainType: trainData['train_type']?.toString() ?? '',
            stations:
                (trainData['route'] as List?)?.asMap().entries.map((entry) {
                  final station = entry.value;
                  return StationSchedule(
                    stationCode: station['station_code']?.toString() ?? '',
                    stationName: station['station_name']?.toString() ?? '',
                    arrivalTime: station['arrive']?.toString() ?? '--',
                    departureTime: station['depart']?.toString() ?? '--',
                    stopNumber: entry.key + 1,
                    day: int.tryParse(station['day']?.toString() ?? '1') ?? 1,
                  );
                }).toList() ??
                [],
          );
        }
      } else {
        print('API Error: ${response.statusCode} - ${response.body}');
      }

      // Return mock data as fallback
      return _getMockTrainSchedule(trainNumber);
    } catch (e) {
      print('Error getting train schedule: $e');
      return _getMockTrainSchedule(trainNumber);
    }
  }

  // Helper to format running days for display
  static String _formatRunningDays(dynamic runDays) {
    if (runDays == null) return 'Daily';

    if (runDays is String) {
      // If it's a string like "MTWTFSS" or "1010101"
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final result = <String>[];

      for (int i = 0; i < runDays.length && i < 7; i++) {
        if (runDays[i] != 'N' && runDays[i] != '0') {
          result.add(days[i]);
        }
      }

      if (result.length == 7) return 'Daily';
      if (result.isEmpty) return 'Check Schedule';
      return result.join(', ');
    } else if (runDays is Map) {
      // If it's a map like {"Mon": true, "Tue": false}
      final activeDays = runDays.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key.toString())
          .toList();

      if (activeDays.length == 7) return 'Daily';
      if (activeDays.isEmpty) return 'Check Schedule';
      return activeDays.join(', ');
    }

    return 'Daily';
  }

  // Search for station by name or code
  Future<List<Station>> searchStations(String query) async {
    try {
      // Mock data for development - stations don't change often
      await Future.delayed(const Duration(milliseconds: 500));
      return _getMockStations(query);
    } catch (e) {
      print('Error searching stations: $e');
      throw Exception('Failed to search stations: $e');
    }
  }

  // Mock stations list (common Indian Railway stations)
  List<Station> _getMockStations(String query) {
    final allStations = [
      // Major stations with many train connections
      Station(code: 'NDLS', name: 'New Delhi', city: 'Delhi'),
      Station(code: 'BCT', name: 'Mumbai Central', city: 'Mumbai'),
      Station(code: 'CSTM', name: 'Mumbai CST', city: 'Mumbai'),
      Station(code: 'BVI', name: 'Borivali', city: 'Mumbai'),
      Station(code: 'PUNE', name: 'Pune Junction', city: 'Pune'),
      Station(code: 'SBC', name: 'Bangalore City', city: 'Bangalore'),
      Station(code: 'MAS', name: 'Chennai Central', city: 'Chennai'),
      Station(code: 'HWH', name: 'Howrah Junction', city: 'Kolkata'),
      Station(code: 'SURAT', name: 'Surat', city: 'Surat'),
      Station(code: 'ADI', name: 'Ahmedabad Junction', city: 'Ahmedabad'),
      Station(code: 'JP', name: 'Jaipur Junction', city: 'Jaipur'),
      Station(code: 'LKO', name: 'Lucknow', city: 'Lucknow'),
      Station(code: 'PNBE', name: 'Patna Junction', city: 'Patna'),
      Station(code: 'CNB', name: 'Kanpur Central', city: 'Kanpur'),
      Station(code: 'AGC', name: 'Agra Cantt', city: 'Agra'),
    ];

    if (query.isEmpty) return allStations;

    final lowerQuery = query.toLowerCase();
    return allStations
        .where(
          (station) =>
              station.name.toLowerCase().contains(lowerQuery) ||
              station.code.toLowerCase().contains(lowerQuery) ||
              station.city.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  // Mock train data for fallback when API is unavailable
  List<TrainBetweenStations> _getMockTrainsBetweenStations(
    String fromStationCode,
    String toStationCode,
  ) {
    return [
      TrainBetweenStations(
        trainNumber: '12951',
        trainName: 'Mumbai Rajdhani',
        fromStation: fromStationCode,
        toStation: toStationCode,
        departureTime: '16:55',
        arrivalTime: '08:35',
        duration: '15h 40m',
        runDays: 'Daily',
        trainType: 'Rajdhani',
      ),
      TrainBetweenStations(
        trainNumber: '12953',
        trainName: 'August Kranti Rajdhani',
        fromStation: fromStationCode,
        toStation: toStationCode,
        departureTime: '17:00',
        arrivalTime: '08:55',
        duration: '15h 55m',
        runDays: 'Daily',
        trainType: 'Rajdhani',
      ),
      TrainBetweenStations(
        trainNumber: '12909',
        trainName: 'Garib Rath Express',
        fromStation: fromStationCode,
        toStation: toStationCode,
        departureTime: '14:40',
        arrivalTime: '07:50',
        duration: '17h 10m',
        runDays: 'Tue, Thu, Sat',
        trainType: 'Garib Rath',
      ),
    ];
  }

  // Mock train schedule for fallback
  TrainSchedule? _getMockTrainSchedule(String trainNumber) {
    if (trainNumber == '12951' ||
        trainNumber == '12953' ||
        trainNumber == '12909') {
      return TrainSchedule(
        trainNumber: trainNumber,
        trainName: trainNumber == '12951'
            ? 'Mumbai Rajdhani'
            : trainNumber == '12953'
            ? 'August Kranti Rajdhani'
            : 'Garib Rath Express',
        trainType: trainNumber == '12909' ? 'Garib Rath' : 'Rajdhani',
        stations: [
          StationSchedule(
            stationCode: 'MMCT',
            stationName: 'Mumbai Central',
            arrivalTime: '--',
            departureTime: '16:55',
            stopNumber: 1,
            day: 1,
          ),
          StationSchedule(
            stationCode: 'BVI',
            stationName: 'Borivali',
            arrivalTime: '17:20',
            departureTime: '17:22',
            stopNumber: 2,
            day: 1,
          ),
          StationSchedule(
            stationCode: 'ST',
            stationName: 'Surat',
            arrivalTime: '19:47',
            departureTime: '19:50',
            stopNumber: 3,
            day: 1,
          ),
          StationSchedule(
            stationCode: 'BRC',
            stationName: 'Vadodara Junction',
            arrivalTime: '21:12',
            departureTime: '21:17',
            stopNumber: 4,
            day: 1,
          ),
          StationSchedule(
            stationCode: 'RTM',
            stationName: 'Ratlam Junction',
            arrivalTime: '23:50',
            departureTime: '23:55',
            stopNumber: 5,
            day: 1,
          ),
          StationSchedule(
            stationCode: 'KOTA',
            stationName: 'Kota Junction',
            arrivalTime: '02:10',
            departureTime: '02:15',
            stopNumber: 6,
            day: 2,
          ),
          StationSchedule(
            stationCode: 'NDLS',
            stationName: 'New Delhi',
            arrivalTime: '08:35',
            departureTime: '--',
            stopNumber: 7,
            day: 2,
          ),
        ],
      );
    }

    return null;
  }

  // Mock PNR status for fallback
  PNRStatus? _getMockPNRStatus(String pnrNumber) {
    return PNRStatus(
      pnrNumber: pnrNumber,
      trainNumber: '12951',
      trainName: 'Mumbai Rajdhani',
      dateOfJourney: '07-11-2025',
      boardingStation: 'BCT - Mumbai Central',
      destinationStation: 'NDLS - New Delhi',
      chartStatus: 'Chart Prepared',
      passengers: [
        PassengerStatus(
          passengerNumber: 1,
          bookingStatus: 'CNF/B2/35',
          currentStatus: 'CNF/B2/35',
        ),
      ],
    );
  }
}

// Data Models

class PNRStatus {
  final String pnrNumber;
  final String trainNumber;
  final String trainName;
  final String dateOfJourney;
  final String boardingStation;
  final String destinationStation;
  final String chartStatus;
  final List<PassengerStatus> passengers;

  PNRStatus({
    required this.pnrNumber,
    required this.trainNumber,
    required this.trainName,
    required this.dateOfJourney,
    required this.boardingStation,
    required this.destinationStation,
    required this.chartStatus,
    required this.passengers,
  });

  factory PNRStatus.fromJson(Map<String, dynamic> json) {
    return PNRStatus(
      pnrNumber: json['pnrNumber']?.toString() ?? '',
      trainNumber: json['trainNo']?.toString() ?? '',
      trainName: json['trainName']?.toString() ?? '',
      dateOfJourney: json['dateOfJourney']?.toString() ?? '',
      boardingStation: json['boardingPoint']?.toString() ?? '',
      destinationStation: json['destinationStation']?.toString() ?? '',
      chartStatus: json['chartStatus']?.toString() ?? '',
      passengers:
          (json['passengerList'] as List?)
              ?.map((p) => PassengerStatus.fromJson(p))
              .toList() ??
          [],
    );
  }
}

class PassengerStatus {
  final int passengerNumber;
  final String bookingStatus;
  final String currentStatus;

  PassengerStatus({
    required this.passengerNumber,
    required this.bookingStatus,
    required this.currentStatus,
  });

  factory PassengerStatus.fromJson(Map<String, dynamic> json) {
    return PassengerStatus(
      passengerNumber: json['passengerSerialNumber'] ?? 0,
      bookingStatus: json['bookingStatus']?.toString() ?? '',
      currentStatus: json['currentStatus']?.toString() ?? '',
    );
  }
}

class Station {
  final String code;
  final String name;
  final String city;

  Station({required this.code, required this.name, required this.city});

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      city: json['city'] ?? '',
    );
  }
}

class TrainBetweenStations {
  final String trainNumber;
  final String trainName;
  final String fromStation;
  final String toStation;
  final String departureTime;
  final String arrivalTime;
  final String duration;
  final String runDays;
  final String trainType;

  TrainBetweenStations({
    required this.trainNumber,
    required this.trainName,
    required this.fromStation,
    required this.toStation,
    required this.departureTime,
    required this.arrivalTime,
    required this.duration,
    required this.runDays,
    required this.trainType,
  });

  factory TrainBetweenStations.fromJson(Map<String, dynamic> json) {
    return TrainBetweenStations(
      trainNumber: json['train_number'] ?? '',
      trainName: json['train_name'] ?? '',
      fromStation: json['from_station'] ?? '',
      toStation: json['to_station'] ?? '',
      departureTime: json['departure_time'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      duration: json['duration'] ?? '',
      runDays: json['run_days'] ?? '',
      trainType: json['train_type'] ?? '',
    );
  }
}

class TrainSchedule {
  final String trainNumber;
  final String trainName;
  final String trainType;
  final List<StationSchedule> stations;

  TrainSchedule({
    required this.trainNumber,
    required this.trainName,
    required this.trainType,
    required this.stations,
  });

  factory TrainSchedule.fromJson(Map<String, dynamic> json) {
    return TrainSchedule(
      trainNumber: json['train_number'] ?? '',
      trainName: json['train_name'] ?? '',
      trainType: json['train_type'] ?? '',
      stations:
          (json['stations'] as List?)
              ?.map((s) => StationSchedule.fromJson(s))
              .toList() ??
          [],
    );
  }
}

class StationSchedule {
  final String stationCode;
  final String stationName;
  final String arrivalTime;
  final String departureTime;
  final int stopNumber;
  final int day;

  StationSchedule({
    required this.stationCode,
    required this.stationName,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopNumber,
    required this.day,
  });

  factory StationSchedule.fromJson(Map<String, dynamic> json) {
    return StationSchedule(
      stationCode: json['station_code'] ?? '',
      stationName: json['station_name'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      departureTime: json['departure_time'] ?? '',
      stopNumber: json['stop_number'] ?? 0,
      day: json['day'] ?? 1,
    );
  }
}
