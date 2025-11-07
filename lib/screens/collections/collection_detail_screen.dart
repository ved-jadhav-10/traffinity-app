import 'package:flutter/material.dart';
import '../../models/collection_model.dart';
import '../../models/collection_location_model.dart';
import '../../services/collections_service.dart';
import 'add_edit_location_screen.dart';
import 'location_detail_screen.dart';

class CollectionDetailScreen extends StatefulWidget {
  final Collection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  final CollectionsService _collectionsService = CollectionsService();
  List<CollectionLocation> _locations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    setState(() => _isLoading = true);
    try {
      final locations = await _collectionsService
          .fetchLocationsInCollection(widget.collection.id);
      setState(() {
        _locations = locations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading locations: $e'),
            backgroundColor: const Color(0xFFf54748),
          ),
        );
      }
    }
  }

  Future<void> _deleteLocation(CollectionLocation location) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Location',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFFf5f6fa),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${location.memoryName}"?',
            style: const TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFF9e9e9e),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF9e9e9e),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf54748),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      try {
        await _collectionsService.deleteLocation(location.id);
        _loadLocations();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location deleted successfully'),
              backgroundColor: Color(0xFF06d6a0),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting location: $e'),
              backgroundColor: const Color(0xFFf54748),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: CustomScrollView(
        slivers: [
          // App Bar with Collection Image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF2a2a2a),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
              onPressed: () => Navigator.pop(context, true),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.collection.collectionName,
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFFf5f6fa),
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: widget.collection.collectionPicture != null
                  ? Image.network(
                      widget.collection.collectionPicture!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildHeaderPlaceholder();
                      },
                    )
                  : _buildHeaderPlaceholder(),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Description
                  if (widget.collection.collectionDescription != null &&
                      widget.collection.collectionDescription!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        widget.collection.collectionDescription!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF9e9e9e),
                          height: 1.5,
                        ),
                      ),
                    ),

                  // Locations header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Locations (${_locations.length})',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Hint text
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: const Color(0xFF06d6a0).withOpacity(0.7),
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Long press any location to edit or delete',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            color: Color(0xFF9e9e9e),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Locations List
          _isLoading
              ? const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF06d6a0),
                    ),
                  ),
                )
              : _locations.isEmpty
                  ? SliverFillRemaining(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final location = _locations[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildLocationCard(location),
                            );
                          },
                          childCount: _locations.length,
                        ),
                      ),
                    ),

          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditLocationScreen(
                collectionId: widget.collection.id,
              ),
            ),
          );
          if (result == true) {
            _loadLocations();
          }
        },
        backgroundColor: const Color(0xFF06d6a0),
        child: const Icon(Icons.add_location_alt, color: Color(0xFF1c1c1c)),
      ),
    );
  }

  Widget _buildHeaderPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF06d6a0).withOpacity(0.3),
            const Color(0xFF06d6a0).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.collections,
          size: 80,
          color: Color(0xFF06d6a0),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_on_outlined,
              size: 80,
              color: const Color(0xFF06d6a0).withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Locations Yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add your first location to this collection by tapping the + button below.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Color(0xFF9e9e9e),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard(CollectionLocation location) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LocationDetailScreen(location: location),
          ),
        );
        if (result == true) {
          _loadLocations();
        }
      },
      onLongPress: () => _showLocationOptions(location),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Image
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(16)),
                child: SizedBox(
                  width: 100,
                  child: location.picture != null
                      ? Image.network(
                          location.picture!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildLocationPlaceholder();
                          },
                        )
                      : _buildLocationPlaceholder(),
                ),
              ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.memoryName,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFf5f6fa),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.address != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Color(0xFF9e9e9e),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location.address!,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: Color(0xFF9e9e9e),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (location.memoryDescription != null &&
                        location.memoryDescription!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        location.memoryDescription!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9e9e9e),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Color(0xFF9e9e9e),
              size: 16,
            ),
            const SizedBox(width: 16),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildLocationPlaceholder() {
    return Container(
      width: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF06d6a0).withOpacity(0.3),
            const Color(0xFF06d6a0).withOpacity(0.1),
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.location_on,
          size: 40,
          color: Color(0xFF06d6a0),
        ),
      ),
    );
  }

  void _showLocationOptions(CollectionLocation location) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2a2a2a),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Edit Location',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddEditLocationScreen(
                        collectionId: widget.collection.id,
                        location: location,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadLocations();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFFf54748)),
                title: const Text(
                  'Delete Location',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf54748),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteLocation(location);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
