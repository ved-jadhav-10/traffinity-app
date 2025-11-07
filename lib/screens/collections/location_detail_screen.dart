import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/collection_location_model.dart';
import '../../services/collections_service.dart';
import 'add_edit_location_screen.dart';

class LocationDetailScreen extends StatefulWidget {
  final CollectionLocation location;

  const LocationDetailScreen({super.key, required this.location});

  @override
  State<LocationDetailScreen> createState() => _LocationDetailScreenState();
}

class _LocationDetailScreenState extends State<LocationDetailScreen> {
  final CollectionsService _collectionsService = CollectionsService();

  Future<void> _deleteLocation() async {
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
            'Are you sure you want to delete "${widget.location.memoryName}"? This action cannot be undone.',
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
        await _collectionsService.deleteLocation(widget.location.id);
        if (mounted) {
          Navigator.pop(context, true); // Return true to refresh previous screen
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
    final dateFormat = DateFormat('MMMM dd, yyyy');
    
    return Scaffold(
      backgroundColor: const Color(0xFF1c1c1c),
      body: CustomScrollView(
        slivers: [
          // App Bar with Location Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: const Color(0xFF2a2a2a),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Color(0xFFf5f6fa)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete, color: Color(0xFFf54748)),
                onPressed: _deleteLocation,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: widget.location.picture != null
                  ? Image.network(
                      widget.location.picture!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildImagePlaceholder();
                      },
                    )
                  : _buildImagePlaceholder(),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Memory Name
                  Text(
                    widget.location.memoryName,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFf5f6fa),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Address
                  if (widget.location.address != null) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF06d6a0),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.location.address!,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Color(0xFF9e9e9e),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Coordinates
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location,
                        color: Color(0xFF06d6a0),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.location.latitude.toStringAsFixed(6)}, ${widget.location.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Added
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF06d6a0),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Added on ${dateFormat.format(widget.location.dateAdded)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                    ],
                  ),

                  // Description
                  if (widget.location.memoryDescription != null &&
                      widget.location.memoryDescription!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    const Text(
                      'Memory',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFf5f6fa),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2a2a2a),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF3a3a3a),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        widget.location.memoryDescription!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFFf5f6fa),
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            // TODO: Open in maps app
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening in maps...'),
                                backgroundColor: Color(0xFF06d6a0),
                              ),
                            );
                          },
                          icon: const Icon(Icons.directions),
                          label: const Text('Directions'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF06d6a0),
                            foregroundColor: const Color(0xFF1c1c1c),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddEditLocationScreen(
                                  collectionId: widget.location.collectionId,
                                  location: widget.location,
                                ),
                              ),
                            );
                            if (result == true && mounted) {
                              // Refresh by popping back
                              Navigator.pop(context, true);
                            }
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF06d6a0),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(
                              color: Color(0xFF06d6a0),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
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
          Icons.location_on,
          size: 100,
          color: Color(0xFF06d6a0),
        ),
      ),
    );
  }
}
