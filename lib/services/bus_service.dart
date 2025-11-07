class BusService {
  // Get bus routes between two locations
  Future<List<BusRoute>> searchBusRoutes({
    required String fromLocation,
    required String toLocation,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    return _getBusRoutesByLocations(fromLocation, toLocation);
  }

  // Get bus details by route number
  Future<BusRouteDetails?> getBusRouteDetails(String routeNumber) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return _getBusRouteDetailsByNumber(routeNumber);
  }

  // Search bus stops
  Future<List<BusStop>> searchBusStops(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _searchBusStopsLocal(query);
  }

  // Get live bus tracking (mock data)
  Future<BusLiveLocation?> getLiveBusLocation(String busNumber) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockBusLocation(busNumber);
  }

  // Private helper methods

  List<BusRoute> _getBusRoutesByLocations(String from, String to) {
    final fromLower = from.toLowerCase();
    final toLower = to.toLowerCase();

    // Mumbai routes
    if ((fromLower.contains('mumbai') ||
            fromLower.contains('bandra') ||
            fromLower.contains('andheri')) &&
        (toLower.contains('mumbai') ||
            toLower.contains('dadar') ||
            toLower.contains('cst') ||
            toLower.contains('colaba'))) {
      return _getMumbaiRoutes();
    }

    // Delhi routes
    if ((fromLower.contains('delhi') ||
            fromLower.contains('connaught') ||
            fromLower.contains('karol')) &&
        (toLower.contains('delhi') ||
            toLower.contains('hauz') ||
            toLower.contains('nehru'))) {
      return _getDelhiRoutes();
    }

    // Bangalore routes
    if ((fromLower.contains('bangalore') ||
            fromLower.contains('bengaluru') ||
            fromLower.contains('koramangala')) &&
        (toLower.contains('bangalore') ||
            toLower.contains('whitefield') ||
            toLower.contains('electronic'))) {
      return _getBangaloreRoutes();
    }

    // Pune routes
    if ((fromLower.contains('pune') ||
            fromLower.contains('kothrud') ||
            fromLower.contains('shivaji')) &&
        (toLower.contains('pune') ||
            toLower.contains('hadapsar') ||
            toLower.contains('camp'))) {
      return _getPuneRoutes();
    }

    // Raipur routes
    if ((fromLower.contains('raipur') ||
            fromLower.contains('pandri') ||
            fromLower.contains('telibandha')) &&
        (toLower.contains('raipur') ||
            toLower.contains('station') ||
            toLower.contains('civil'))) {
      return _getRaipurRoutes();
    }

    // Default generic routes
    return _getGenericRoutes(from, to);
  }

  List<BusRoute> _getMumbaiRoutes() {
    return [
      BusRoute(
        routeNumber: 'AS-1',
        busName: 'Andheri Stn (E) - CST',
        busType: 'AC',
        operator: 'BEST',
        departureTime: 'Every 15 mins',
        estimatedDuration: '45 mins',
        fare: '₹45',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '37',
        busName: 'Bandra Reclamation - Santacruz Depot',
        busType: 'Non-AC',
        operator: 'BEST',
        departureTime: 'Every 20 mins',
        estimatedDuration: '35 mins',
        fare: '₹20',
        frequency: 'High',
        occupancy: 'Low',
      ),
      BusRoute(
        routeNumber: 'C-62',
        busName: 'Mulund Stn (W) - Rani Laxmibai Chowk',
        busType: 'AC',
        operator: 'BEST',
        departureTime: 'Every 25 mins',
        estimatedDuration: '55 mins',
        fare: '₹50',
        frequency: 'Medium',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '83',
        busName: 'Goregaon Depot - Dadar Stn (E)',
        busType: 'Non-AC',
        operator: 'BEST',
        departureTime: 'Every 12 mins',
        estimatedDuration: '40 mins',
        fare: '₹25',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: 'AS-515',
        busName: 'Borivali Stn (E) - Churchgate',
        busType: 'AC Express',
        operator: 'BEST',
        departureTime: 'Every 30 mins',
        estimatedDuration: '65 mins',
        fare: '₹60',
        frequency: 'Medium',
        occupancy: 'Low',
      ),
    ];
  }

  List<BusRoute> _getDelhiRoutes() {
    return [
      BusRoute(
        routeNumber: '764',
        busName: 'Karol Bagh - Nehru Place Terminal',
        busType: 'AC',
        operator: 'DTC',
        departureTime: 'Every 10 mins',
        estimatedDuration: '50 mins',
        fare: '₹25',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '534',
        busName: 'Connaught Place - Hauz Khas Terminal',
        busType: 'Non-AC',
        operator: 'DTC',
        departureTime: 'Every 15 mins',
        estimatedDuration: '35 mins',
        fare: '₹15',
        frequency: 'High',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '181',
        busName: 'Kashmere Gate - ISBT Anand Vihar',
        busType: 'AC',
        operator: 'DTC',
        departureTime: 'Every 20 mins',
        estimatedDuration: '45 mins',
        fare: '₹30',
        frequency: 'Medium',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '402',
        busName: 'Dwarka Sector 21 - Rajiv Chowk',
        busType: 'Metro Feeder',
        operator: 'DTC',
        departureTime: 'Every 8 mins',
        estimatedDuration: '40 mins',
        fare: '₹20',
        frequency: 'High',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '615',
        busName: 'Rohini Sector 24 - ITO',
        busType: 'AC Low Floor',
        operator: 'Cluster',
        departureTime: 'Every 12 mins',
        estimatedDuration: '55 mins',
        fare: '₹35',
        frequency: 'High',
        occupancy: 'Medium',
      ),
    ];
  }

  List<BusRoute> _getBangaloreRoutes() {
    return [
      BusRoute(
        routeNumber: 'G-4',
        busName: 'Koramangala - Majestic',
        busType: 'Volvo AC',
        operator: 'BMTC',
        departureTime: 'Every 15 mins',
        estimatedDuration: '40 mins',
        fare: '₹40',
        frequency: 'High',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '500K',
        busName: 'Kempegowda Bus Stn - Electronic City',
        busType: 'Non-AC',
        operator: 'BMTC',
        departureTime: 'Every 10 mins',
        estimatedDuration: '55 mins',
        fare: '₹30',
        frequency: 'High',
        occupancy: 'Very High',
      ),
      BusRoute(
        routeNumber: 'KBS-1',
        busName: 'Whitefield - Kempegowda Bus Station',
        busType: 'Volvo AC',
        operator: 'BMTC',
        departureTime: 'Every 20 mins',
        estimatedDuration: '70 mins',
        fare: '₹50',
        frequency: 'Medium',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '356',
        busName: 'Indiranagar - Jayanagar 4th Block',
        busType: 'Non-AC',
        operator: 'BMTC',
        departureTime: 'Every 12 mins',
        estimatedDuration: '35 mins',
        fare: '₹20',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: 'AS-220',
        busName: 'Bellandur - Hebbal',
        busType: 'Vayu Vajra AC',
        operator: 'BMTC',
        departureTime: 'Every 30 mins',
        estimatedDuration: '65 mins',
        fare: '₹70',
        frequency: 'Medium',
        occupancy: 'Low',
      ),
    ];
  }

  List<BusRoute> _getPuneRoutes() {
    return [
      BusRoute(
        routeNumber: '2',
        busName: 'Swargate - Shivaji Nagar',
        busType: 'Rainbow AC',
        operator: 'PMPML',
        departureTime: 'Every 10 mins',
        estimatedDuration: '30 mins',
        fare: '₹25',
        frequency: 'Very High',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '103',
        busName: 'Kothrud Depot - Hadapsar',
        busType: 'Non-AC',
        operator: 'PMPML',
        departureTime: 'Every 15 mins',
        estimatedDuration: '45 mins',
        fare: '₹18',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '152',
        busName: 'Deccan - Aundh',
        busType: 'Rainbow AC',
        operator: 'PMPML',
        departureTime: 'Every 20 mins',
        estimatedDuration: '35 mins',
        fare: '₹28',
        frequency: 'Medium',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '501',
        busName: 'Katraj - Pimpri Chinchwad',
        busType: 'Non-AC',
        operator: 'PMPML',
        departureTime: 'Every 25 mins',
        estimatedDuration: '60 mins',
        fare: '₹22',
        frequency: 'Medium',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '27',
        busName: 'Pune Station - Kharadi',
        busType: 'Rainbow AC',
        operator: 'PMPML',
        departureTime: 'Every 18 mins',
        estimatedDuration: '50 mins',
        fare: '₹32',
        frequency: 'High',
        occupancy: 'Medium',
      ),
    ];
  }

  List<BusRoute> _getRaipurRoutes() {
    return [
      BusRoute(
        routeNumber: 'R-1',
        busName: 'Telibandha - Civil Lines',
        busType: 'AC Express',
        operator: 'Nagar Nigam Raipur',
        departureTime: 'Every 12 mins',
        estimatedDuration: '35 mins',
        fare: '₹20',
        frequency: 'Very High',
        occupancy: 'High',
      ),
      BusRoute(
        routeNumber: '5A',
        busName: 'Pandri - Raipur Station',
        busType: 'Non-AC',
        operator: 'Nagar Nigam Raipur',
        departureTime: 'Every 10 mins',
        estimatedDuration: '25 mins',
        fare: '₹12',
        frequency: 'Very High',
        occupancy: 'Very High',
      ),
      BusRoute(
        routeNumber: '14',
        busName: 'Dhamtari Road - GE Road',
        busType: 'AC',
        operator: 'Nagar Nigam Raipur',
        departureTime: 'Every 15 mins',
        estimatedDuration: '40 mins',
        fare: '₹18',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '22B',
        busName: 'Mowa - Devendra Nagar',
        busType: 'Non-AC',
        operator: 'Nagar Nigam Raipur',
        departureTime: 'Every 20 mins',
        estimatedDuration: '45 mins',
        fare: '₹15',
        frequency: 'Medium',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: 'R-9',
        busName: 'Marine Drive - VIP Road',
        busType: 'AC Express',
        operator: 'Nagar Nigam Raipur',
        departureTime: 'Every 18 mins',
        estimatedDuration: '30 mins',
        fare: '₹22',
        frequency: 'High',
        occupancy: 'Low',
      ),
      BusRoute(
        routeNumber: '31',
        busName: 'Shankar Nagar - Sunder Nagar',
        busType: 'Non-AC',
        operator: 'Nagar Nigam Raipur',
        departureTime: 'Every 25 mins',
        estimatedDuration: '50 mins',
        fare: '₹14',
        frequency: 'Medium',
        occupancy: 'High',
      ),
    ];
  }

  List<BusRoute> _getGenericRoutes(String from, String to) {
    return [
      BusRoute(
        routeNumber: '101',
        busName: '$from - $to',
        busType: 'AC',
        operator: 'City Bus',
        departureTime: 'Every 15 mins',
        estimatedDuration: '40 mins',
        fare: '₹30',
        frequency: 'High',
        occupancy: 'Medium',
      ),
      BusRoute(
        routeNumber: '202',
        busName: '$from - $to (Express)',
        busType: 'AC Express',
        operator: 'City Bus',
        departureTime: 'Every 30 mins',
        estimatedDuration: '30 mins',
        fare: '₹45',
        frequency: 'Medium',
        occupancy: 'Low',
      ),
      BusRoute(
        routeNumber: '303',
        busName: '$from - $to (Local)',
        busType: 'Non-AC',
        operator: 'City Bus',
        departureTime: 'Every 20 mins',
        estimatedDuration: '50 mins',
        fare: '₹20',
        frequency: 'High',
        occupancy: 'High',
      ),
    ];
  }

  BusRouteDetails? _getBusRouteDetailsByNumber(String routeNumber) {
    // Sample detailed route for demonstration
    if (routeNumber == 'AS-1' ||
        routeNumber == '764' ||
        routeNumber == 'G-4' ||
        routeNumber == '2') {
      return BusRouteDetails(
        routeNumber: routeNumber,
        routeName: _getRouteNameByNumber(routeNumber),
        busType: _getBusTypeByRoute(routeNumber),
        operator: _getOperatorByRoute(routeNumber),
        stops: _getStopsByRoute(routeNumber),
        firstBus: '05:30 AM',
        lastBus: '11:45 PM',
        frequency: '10-15 mins',
        fare: '₹25-45',
      );
    }
    return null;
  }

  String _getRouteNameByNumber(String routeNumber) {
    switch (routeNumber) {
      case 'AS-1':
        return 'Andheri Station (E) - CST';
      case '764':
        return 'Karol Bagh - Nehru Place Terminal';
      case 'G-4':
        return 'Koramangala - Majestic';
      case '2':
        return 'Swargate - Shivaji Nagar';
      case 'R-1':
        return 'Telibandha - Civil Lines';
      case '5A':
        return 'Pandri - Raipur Station';
      case '14':
        return 'Dhamtari Road - GE Road';
      case '22B':
        return 'Mowa - Devendra Nagar';
      case 'R-9':
        return 'Marine Drive - VIP Road';
      case '31':
        return 'Shankar Nagar - Sunder Nagar';
      default:
        return 'Bus Route $routeNumber';
    }
  }

  String _getBusTypeByRoute(String routeNumber) {
    if (routeNumber.startsWith('AS')) return 'AC';
    if (routeNumber.startsWith('G-')) return 'Volvo AC';
    if (routeNumber.startsWith('R-')) return 'AC Express';
    if (routeNumber == '5A' || routeNumber == '22B' || routeNumber == '31')
      return 'Non-AC';
    if (routeNumber == '14') return 'AC';
    return 'Rainbow AC';
  }

  String _getOperatorByRoute(String routeNumber) {
    if (routeNumber.startsWith('AS') || routeNumber == '37') return 'BEST';
    if (routeNumber == '764' || routeNumber == '534') return 'DTC';
    if (routeNumber.startsWith('G-') || routeNumber == '500K') return 'BMTC';
    if (routeNumber.startsWith('R-') ||
        routeNumber == '5A' ||
        routeNumber == '14' ||
        routeNumber == '22B' ||
        routeNumber == '31')
      return 'Nagar Nigam Raipur';
    return 'PMPML';
  }

  List<BusStopInfo> _getStopsByRoute(String routeNumber) {
    // Sample stops for AS-1 (Mumbai)
    if (routeNumber == 'AS-1') {
      return [
        BusStopInfo(
          stopName: 'Andheri Station East',
          arrivalTime: '--',
          stopNumber: 1,
        ),
        BusStopInfo(stopName: 'MIDC', arrivalTime: '5 mins', stopNumber: 2),
        BusStopInfo(
          stopName: 'Kurla Station',
          arrivalTime: '12 mins',
          stopNumber: 3,
        ),
        BusStopInfo(
          stopName: 'Sion Hospital',
          arrivalTime: '20 mins',
          stopNumber: 4,
        ),
        BusStopInfo(
          stopName: 'Dadar TT',
          arrivalTime: '28 mins',
          stopNumber: 5,
        ),
        BusStopInfo(
          stopName: 'Byculla Station',
          arrivalTime: '35 mins',
          stopNumber: 6,
        ),
        BusStopInfo(stopName: 'CST', arrivalTime: '45 mins', stopNumber: 7),
      ];
    }

    // Sample stops for 764 (Delhi)
    if (routeNumber == '764') {
      return [
        BusStopInfo(
          stopName: 'Karol Bagh Metro',
          arrivalTime: '--',
          stopNumber: 1,
        ),
        BusStopInfo(
          stopName: 'Patel Nagar',
          arrivalTime: '6 mins',
          stopNumber: 2,
        ),
        BusStopInfo(
          stopName: 'Rajendra Place',
          arrivalTime: '12 mins',
          stopNumber: 3,
        ),
        BusStopInfo(
          stopName: 'INA Market',
          arrivalTime: '25 mins',
          stopNumber: 4,
        ),
        BusStopInfo(stopName: 'AIIMS', arrivalTime: '32 mins', stopNumber: 5),
        BusStopInfo(stopName: 'Kalkaji', arrivalTime: '42 mins', stopNumber: 6),
        BusStopInfo(
          stopName: 'Nehru Place Terminal',
          arrivalTime: '50 mins',
          stopNumber: 7,
        ),
      ];
    }

    // Sample stops for G-4 (Bangalore)
    if (routeNumber == 'G-4') {
      return [
        BusStopInfo(
          stopName: 'Koramangala Sony Signal',
          arrivalTime: '--',
          stopNumber: 1,
        ),
        BusStopInfo(
          stopName: 'Koramangala 6th Block',
          arrivalTime: '4 mins',
          stopNumber: 2,
        ),
        BusStopInfo(
          stopName: 'BTM Layout',
          arrivalTime: '10 mins',
          stopNumber: 3,
        ),
        BusStopInfo(
          stopName: 'Jayanagar 4th Block',
          arrivalTime: '18 mins',
          stopNumber: 4,
        ),
        BusStopInfo(
          stopName: 'Lalbagh Main Gate',
          arrivalTime: '26 mins',
          stopNumber: 5,
        ),
        BusStopInfo(
          stopName: 'KR Market',
          arrivalTime: '33 mins',
          stopNumber: 6,
        ),
        BusStopInfo(
          stopName: 'Majestic Bus Stand',
          arrivalTime: '40 mins',
          stopNumber: 7,
        ),
      ];
    }

    // Sample stops for route 2 (Pune)
    if (routeNumber == '2') {
      return [
        BusStopInfo(
          stopName: 'Swargate Bus Stand',
          arrivalTime: '--',
          stopNumber: 1,
        ),
        BusStopInfo(stopName: 'Parvati', arrivalTime: '5 mins', stopNumber: 2),
        BusStopInfo(
          stopName: 'Pune Station',
          arrivalTime: '12 mins',
          stopNumber: 3,
        ),
        BusStopInfo(
          stopName: 'Alka Talkies',
          arrivalTime: '18 mins',
          stopNumber: 4,
        ),
        BusStopInfo(stopName: 'JM Road', arrivalTime: '24 mins', stopNumber: 5),
        BusStopInfo(
          stopName: 'Shivaji Nagar',
          arrivalTime: '30 mins',
          stopNumber: 6,
        ),
      ];
    }

    // Sample stops for R-1 (Raipur)
    if (routeNumber == 'R-1') {
      return [
        BusStopInfo(
          stopName: 'Telibandha Bus Stand',
          arrivalTime: '--',
          stopNumber: 1,
        ),
        BusStopInfo(
          stopName: 'Pandri Police Chowki',
          arrivalTime: '6 mins',
          stopNumber: 2,
        ),
        BusStopInfo(
          stopName: 'Kota Crossing',
          arrivalTime: '12 mins',
          stopNumber: 3,
        ),
        BusStopInfo(
          stopName: 'Jaistambh Chowk',
          arrivalTime: '18 mins',
          stopNumber: 4,
        ),
        BusStopInfo(
          stopName: 'Liberty Chowk',
          arrivalTime: '25 mins',
          stopNumber: 5,
        ),
        BusStopInfo(
          stopName: 'Hirapur Chowk',
          arrivalTime: '30 mins',
          stopNumber: 6,
        ),
        BusStopInfo(
          stopName: 'Civil Lines',
          arrivalTime: '35 mins',
          stopNumber: 7,
        ),
      ];
    }

    // Sample stops for 5A (Raipur)
    if (routeNumber == '5A') {
      return [
        BusStopInfo(stopName: 'Pandri Chowk', arrivalTime: '--', stopNumber: 1),
        BusStopInfo(
          stopName: 'Gurudwara Chowk',
          arrivalTime: '5 mins',
          stopNumber: 2,
        ),
        BusStopInfo(
          stopName: 'Moti Bagh',
          arrivalTime: '10 mins',
          stopNumber: 3,
        ),
        BusStopInfo(
          stopName: 'Raj Mohalla',
          arrivalTime: '15 mins',
          stopNumber: 4,
        ),
        BusStopInfo(
          stopName: 'Gol Bazar',
          arrivalTime: '20 mins',
          stopNumber: 5,
        ),
        BusStopInfo(
          stopName: 'Raipur Railway Station',
          arrivalTime: '25 mins',
          stopNumber: 6,
        ),
      ];
    }

    return [];
  }

  List<BusStop> _searchBusStopsLocal(String query) {
    final allStops = [
      // Mumbai stops
      BusStop(name: 'Andheri Station East', code: 'AND-E', city: 'Mumbai'),
      BusStop(name: 'Bandra Station West', code: 'BND-W', city: 'Mumbai'),
      BusStop(name: 'CST', code: 'CST', city: 'Mumbai'),
      BusStop(name: 'Dadar TT', code: 'DDR', city: 'Mumbai'),
      BusStop(name: 'Kurla Station', code: 'KRL', city: 'Mumbai'),
      BusStop(name: 'Goregaon Depot', code: 'GRG', city: 'Mumbai'),
      BusStop(name: 'Borivali Station', code: 'BVL', city: 'Mumbai'),

      // Delhi stops
      BusStop(name: 'Karol Bagh Metro', code: 'KRB', city: 'Delhi'),
      BusStop(name: 'Connaught Place', code: 'CNP', city: 'Delhi'),
      BusStop(name: 'Nehru Place Terminal', code: 'NPL', city: 'Delhi'),
      BusStop(name: 'Kashmere Gate ISBT', code: 'KSG', city: 'Delhi'),
      BusStop(name: 'Hauz Khas Terminal', code: 'HKZ', city: 'Delhi'),
      BusStop(name: 'Dwarka Sector 21', code: 'DWK21', city: 'Delhi'),

      // Bangalore stops
      BusStop(name: 'Koramangala', code: 'KRM', city: 'Bangalore'),
      BusStop(name: 'Majestic Bus Stand', code: 'MJT', city: 'Bangalore'),
      BusStop(name: 'Whitefield', code: 'WHF', city: 'Bangalore'),
      BusStop(name: 'Electronic City', code: 'ELC', city: 'Bangalore'),
      BusStop(name: 'Indiranagar', code: 'ING', city: 'Bangalore'),
      BusStop(name: 'Hebbal', code: 'HBL', city: 'Bangalore'),

      // Pune stops
      BusStop(name: 'Swargate Bus Stand', code: 'SWG', city: 'Pune'),
      BusStop(name: 'Shivaji Nagar', code: 'SHV', city: 'Pune'),
      BusStop(name: 'Kothrud Depot', code: 'KTD', city: 'Pune'),
      BusStop(name: 'Hadapsar', code: 'HDP', city: 'Pune'),
      BusStop(name: 'Pune Station', code: 'PNE', city: 'Pune'),
      BusStop(name: 'Deccan Gymkhana', code: 'DGK', city: 'Pune'),

      // Raipur stops
      BusStop(name: 'Telibandha Bus Stand', code: 'TLB', city: 'Raipur'),
      BusStop(name: 'Pandri Chowk', code: 'PDR', city: 'Raipur'),
      BusStop(name: 'Civil Lines', code: 'CVL', city: 'Raipur'),
      BusStop(name: 'Raipur Railway Station', code: 'RPR-STN', city: 'Raipur'),
      BusStop(name: 'Jaistambh Chowk', code: 'JST', city: 'Raipur'),
      BusStop(name: 'Marine Drive', code: 'MRD', city: 'Raipur'),
      BusStop(name: 'GE Road', code: 'GER', city: 'Raipur'),
      BusStop(name: 'Devendra Nagar', code: 'DVN', city: 'Raipur'),
      BusStop(name: 'Shankar Nagar', code: 'SHN', city: 'Raipur'),
      BusStop(name: 'Mowa', code: 'MWA', city: 'Raipur'),
      BusStop(name: 'VIP Road', code: 'VIP', city: 'Raipur'),
      BusStop(name: 'Dhamtari Road', code: 'DHM', city: 'Raipur'),
    ];

    if (query.isEmpty) return allStops;

    final lowerQuery = query.toLowerCase();
    return allStops
        .where(
          (stop) =>
              stop.name.toLowerCase().contains(lowerQuery) ||
              stop.code.toLowerCase().contains(lowerQuery) ||
              stop.city.toLowerCase().contains(lowerQuery),
        )
        .toList();
  }

  BusLiveLocation? _getMockBusLocation(String busNumber) {
    return BusLiveLocation(
      busNumber: busNumber,
      currentLocation: 'Near Dadar TT',
      nextStop: 'Byculla Station',
      estimatedArrival: '8 mins',
      occupancy: 'Medium',
      latitude: 19.0176,
      longitude: 72.8561,
      speed: 25,
    );
  }
}

// Data Models

class BusRoute {
  final String routeNumber;
  final String busName;
  final String busType;
  final String operator;
  final String departureTime;
  final String estimatedDuration;
  final String fare;
  final String frequency;
  final String occupancy;

  BusRoute({
    required this.routeNumber,
    required this.busName,
    required this.busType,
    required this.operator,
    required this.departureTime,
    required this.estimatedDuration,
    required this.fare,
    required this.frequency,
    required this.occupancy,
  });
}

class BusRouteDetails {
  final String routeNumber;
  final String routeName;
  final String busType;
  final String operator;
  final List<BusStopInfo> stops;
  final String firstBus;
  final String lastBus;
  final String frequency;
  final String fare;

  BusRouteDetails({
    required this.routeNumber,
    required this.routeName,
    required this.busType,
    required this.operator,
    required this.stops,
    required this.firstBus,
    required this.lastBus,
    required this.frequency,
    required this.fare,
  });
}

class BusStopInfo {
  final String stopName;
  final String arrivalTime;
  final int stopNumber;

  BusStopInfo({
    required this.stopName,
    required this.arrivalTime,
    required this.stopNumber,
  });
}

class BusStop {
  final String name;
  final String code;
  final String city;

  BusStop({required this.name, required this.code, required this.city});
}

class BusLiveLocation {
  final String busNumber;
  final String currentLocation;
  final String nextStop;
  final String estimatedArrival;
  final String occupancy;
  final double latitude;
  final double longitude;
  final int speed;

  BusLiveLocation({
    required this.busNumber,
    required this.currentLocation,
    required this.nextStop,
    required this.estimatedArrival,
    required this.occupancy,
    required this.latitude,
    required this.longitude,
    required this.speed,
  });
}
