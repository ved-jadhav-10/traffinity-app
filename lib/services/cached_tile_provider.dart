import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'map_tile_cache_manager.dart';

/// Cached tile provider for TomTom map tiles
///
/// This provider:
/// - Checks cache before making network requests
/// - Downloads tiles only if not cached or expired
/// - Provides faster map rendering
class CachedTileProvider extends TileProvider {
  final CacheManager cacheManager;

  CachedTileProvider({CacheManager? cacheManager})
    : cacheManager = cacheManager ?? MapTileCacheManager();

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // Build the tile URL
    final url = getTileUrl(coordinates, options);

    // Return a cached network image provider
    return CachedTileImageProvider(
      url: url,
      cacheManager: cacheManager,
      errorListener: () {
        debugPrint('Error loading tile: $url');
      },
    );
  }
}

/// Custom image provider that uses cache manager
class CachedTileImageProvider extends ImageProvider<CachedTileImageProvider> {
  final String url;
  final CacheManager cacheManager;
  final VoidCallback? errorListener;

  const CachedTileImageProvider({
    required this.url,
    required this.cacheManager,
    this.errorListener,
  });

  @override
  ImageStreamCompleter loadImage(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: url,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Tile URL: $url'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    CachedTileImageProvider key,
    ImageDecoderCallback decode,
  ) async {
    try {
      // Try to get the tile from cache or download it
      final file = await cacheManager.getSingleFile(url);
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Tile is empty');
      }

      // Decode the image
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      errorListener?.call();
      debugPrint('Error loading tile: $e');
      rethrow;
    }
  }

  @override
  Future<CachedTileImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<CachedTileImageProvider>(this);
  }

  @override
  bool operator ==(Object other) {
    if (other is! CachedTileImageProvider) return false;
    return url == other.url;
  }

  @override
  int get hashCode => url.hashCode;
}
