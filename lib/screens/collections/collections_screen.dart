import 'package:flutter/material.dart';
import '../../models/collection_model.dart';
import '../../services/collections_service.dart';
import 'collection_detail_screen.dart';
import 'add_edit_collection_screen.dart';

class CollectionsScreen extends StatefulWidget {
  const CollectionsScreen({super.key});

  @override
  State<CollectionsScreen> createState() => _CollectionsScreenState();
}

class _CollectionsScreenState extends State<CollectionsScreen> {
  final CollectionsService _collectionsService = CollectionsService();
  List<Collection> _collections = [];
  Map<String, int> _locationCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() => _isLoading = true);
    try {
      final collections = await _collectionsService.fetchCollections();
      final counts = <String, int>{};

      // Get location count for each collection
      for (var collection in collections) {
        final count =
            await _collectionsService.getLocationCount(collection.id);
        counts[collection.id] = count;
      }

      setState(() {
        _collections = collections;
        _locationCounts = counts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading collections: $e'),
            backgroundColor: const Color(0xFFf54748),
          ),
        );
      }
    }
  }

  Future<void> _deleteCollection(Collection collection) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2a2a2a),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Delete Collection',
            style: TextStyle(
              fontFamily: 'Poppins',
              color: Color(0xFFf5f6fa),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${collection.collectionName}"? This will also delete all locations in this collection.',
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
        await _collectionsService.deleteCollection(collection.id);
        _loadCollections();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Collection deleted successfully'),
              backgroundColor: Color(0xFF06d6a0),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting collection: $e'),
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
      appBar: AppBar(
        backgroundColor: const Color(0xFF2a2a2a),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Collections',
          style: TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFf5f6fa),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF06d6a0),
              ),
            )
          : _collections.isEmpty
              ? _buildEmptyState()
              : _buildCollectionsList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditCollectionScreen(),
            ),
          );
          if (result == true) {
            _loadCollections();
          }
        },
        backgroundColor: const Color(0xFF06d6a0),
        child: const Icon(Icons.add, color: Color(0xFF1c1c1c)),
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
              Icons.collections_outlined,
              size: 80,
              color: const Color(0xFF06d6a0).withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Collections Yet',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Create your first collection to start organizing your favorite places and memories.',
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

  Widget _buildCollectionsList() {
    return Column(
      children: [
        // Hint text
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: const Color(0xFF06d6a0).withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Long press any collection to edit or delete',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFF9e9e9e),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Grid
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.85,
            ),
            itemCount: _collections.length,
            itemBuilder: (context, index) {
              final collection = _collections[index];
              final locationCount = _locationCounts[collection.id] ?? 0;
              return _buildCollectionCard(collection, locationCount);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCollectionCard(Collection collection, int locationCount) {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                CollectionDetailScreen(collection: collection),
          ),
        );
        if (result == true) {
          _loadCollections();
        }
      },
      onLongPress: () => _showCollectionOptions(collection),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2a2a2a),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: collection.collectionPicture != null
                  ? Image.network(
                      collection.collectionPicture!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildPlaceholderImage();
                      },
                    )
                  : _buildPlaceholderImage(),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    collection.collectionName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFf5f6fa),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$locationCount ${locationCount == 1 ? 'place' : 'places'}',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF9e9e9e),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 120,
      width: double.infinity,
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
      child: const Icon(
        Icons.collections,
        size: 48,
        color: Color(0xFF06d6a0),
      ),
    );
  }

  void _showCollectionOptions(Collection collection) {
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
                leading:
                    const Icon(Icons.edit, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Edit Collection',
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
                      builder: (context) => AddEditCollectionScreen(
                        collection: collection,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadCollections();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Color(0xFFf54748)),
                title: const Text(
                  'Delete Collection',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf54748),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCollection(collection);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
