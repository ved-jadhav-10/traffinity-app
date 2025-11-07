import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/collection_location_model.dart';
import '../../models/location_model.dart';
import '../../services/collections_service.dart';
import '../../services/tomtom_service.dart';

class AddEditLocationScreen extends StatefulWidget {
  final String collectionId;
  final CollectionLocation? location;

  const AddEditLocationScreen({
    super.key,
    required this.collectionId,
    this.location,
  });

  @override
  State<AddEditLocationScreen> createState() => _AddEditLocationScreenState();
}

class _AddEditLocationScreenState extends State<AddEditLocationScreen> {
  final CollectionsService _collectionsService = CollectionsService();
  final TomTomService _tomtomService = TomTomService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedImagePath;
  String? _existingImageUrl;
  bool _isLoading = false;
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  SearchResult? _selectedLocation;
  Timer? _searchDebounce;

  bool get _isEditing => widget.location != null;
  final int _maxDescriptionLength = 200;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.location!.memoryName;
      _descriptionController.text = widget.location!.memoryDescription ?? '';
      _existingImageUrl = widget.location!.picture;
      _searchController.text = widget.location!.address ?? '';
      // Set selected location from existing data
      _selectedLocation = SearchResult(
        name: widget.location!.memoryName,
        address: widget.location!.address ?? '',
        latitude: widget.location!.latitude,
        longitude: widget.location!.longitude,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _tomtomService.searchLocations(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isSearching = false);
        }
      }
    });
  }

  void _selectLocation(SearchResult result) {
    setState(() {
      _selectedLocation = result;
      _searchController.text = result.address;
      if (_nameController.text.isEmpty) {
        _nameController.text = result.name;
      }
      _searchResults = [];
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _existingImageUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: const Color(0xFFf54748),
          ),
        );
      }
    }
  }

  void _showImageSourceDialog() {
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
                leading: const Icon(Icons.camera_alt, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Take Photo',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFF06d6a0)),
                title: const Text(
                  'Choose from Gallery',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFFf5f6fa),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_selectedImagePath != null || _existingImageUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Color(0xFFf54748)),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFFf54748),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImagePath = null;
                      _existingImageUrl = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveLocation() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a memory name'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please search and select a location'),
          backgroundColor: Color(0xFFf54748),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.length > _maxDescriptionLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Description must be $_maxDescriptionLength characters or less'),
          backgroundColor: const Color(0xFFf54748),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imageUrl = _existingImageUrl;

      // Upload new image if selected
      if (_selectedImagePath != null) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_location.jpg';
        imageUrl = await _collectionsService.uploadImage(
          _selectedImagePath!,
          fileName,
        );
      }

      if (_isEditing) {
        // Update existing location
        await _collectionsService.updateLocation(
          locationId: widget.location!.id,
          memoryName: _nameController.text.trim(),
          memoryDescription:
              description.isEmpty ? null : description,
          picture: imageUrl,
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _selectedLocation!.address,
        );
      } else {
        // Add new location
        await _collectionsService.addLocation(
          collectionId: widget.collectionId,
          memoryName: _nameController.text.trim(),
          memoryDescription:
              description.isEmpty ? null : description,
          picture: imageUrl,
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude,
          address: _selectedLocation!.address,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Location updated successfully'
                : 'Location added successfully'),
            backgroundColor: const Color(0xFF06d6a0),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving location: $e'),
            backgroundColor: const Color(0xFFf54748),
          ),
        );
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
        title: Text(
          _isEditing ? 'Edit Location' : 'Add Location',
          style: const TextStyle(
            fontFamily: 'Poppins',
            color: Color(0xFFf5f6fa),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF06d6a0),
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Color(0xFF06d6a0)),
              onPressed: _saveLocation,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image picker
            GestureDetector(
              onTap: _showImageSourceDialog,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF3a3a3a), width: 1),
                ),
                child: _selectedImagePath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(_selectedImagePath!),
                          fit: BoxFit.cover,
                        ),
                      )
                    : _existingImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              _existingImageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildImagePlaceholder();
                              },
                            ),
                          )
                        : _buildImagePlaceholder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap to add/change photo',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12,
                color: Color(0xFF9e9e9e),
              ),
            ),
            const SizedBox(height: 32),

            // Location Search
            const Text(
              'Location',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Search for a location...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF9e9e9e),
                ),
                prefixIcon:
                    const Icon(Icons.search, color: Color(0xFF06d6a0)),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF06d6a0),
                          ),
                        ),
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF06d6a0)),
                ),
              ),
            ),

            // Search Results
            if (_searchResults.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF3a3a3a)),
                ),
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => const Divider(
                    color: Color(0xFF3a3a3a),
                    height: 1,
                  ),
                  itemBuilder: (context, index) {
                    final result = _searchResults[index];
                    return ListTile(
                      leading: const Icon(
                        Icons.location_on,
                        color: Color(0xFF06d6a0),
                        size: 20,
                      ),
                      title: Text(
                        result.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Color(0xFFf5f6fa),
                        ),
                      ),
                      subtitle: Text(
                        result.address,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF9e9e9e),
                        ),
                      ),
                      onTap: () => _selectLocation(result),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Memory Name
            const Text(
              'Memory Name',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'e.g., Best Coffee Shop, Sunset Point',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF9e9e9e),
                ),
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF06d6a0)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Description (${_descriptionController.text.length}/$_maxDescriptionLength)',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: _maxDescriptionLength,
              onChanged: (value) => setState(() {}),
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Share your memory about this place...',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  color: Color(0xFF9e9e9e),
                ),
                filled: true,
                fillColor: const Color(0xFF2a2a2a),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF3a3a3a)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF06d6a0)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate,
          size: 64,
          color: const Color(0xFF06d6a0).withOpacity(0.5),
        ),
        const SizedBox(height: 12),
        const Text(
          'Add Photo',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: Color(0xFF9e9e9e),
          ),
        ),
      ],
    );
  }
}
