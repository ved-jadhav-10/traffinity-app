import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Custom cache manager for TomTom map tiles
///
/// This provides:
/// - Faster load times by caching tiles locally
/// - Configurable cache duration (7 days default)
/// - Automatic cleanup of old tiles
/// - Reduced API calls to TomTom
class MapTileCacheManager extends CacheManager {
  static const key = 'tomtomMapTileCache';

  static MapTileCacheManager? _instance;

  factory MapTileCacheManager() {
    _instance ??= MapTileCacheManager._();
    return _instance!;
  }

  MapTileCacheManager._()
    : super(
        Config(
          key,
          // Cache map tiles for 7 days
          stalePeriod: const Duration(days: 7),
          // Store up to 500 tiles (approximately 50-100 MB)
          maxNrOfCacheObjects: 500,
          // Use a custom file service for better performance
          repo: JsonCacheInfoRepository(databaseName: key),
          fileService: HttpFileService(),
        ),
      );
}
