import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/collection_model.dart';
import '../../services/collections_service.dart';

class AddEditCollectionScreen extends StatefulWidget {
  final Collection? collection;

  const AddEditCollectionScreen({super.key, this.collection});

  @override
  State<AddEditCollectionScreen> createState() =>
      _AddEditCollectionScreenState();
}

class _AddEditCollectionScreenState extends State<AddEditCollectionScreen> {
  final CollectionsService _collectionsService = CollectionsService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String? _selectedImagePath;
  String? _existingImageUrl;
  bool _isLoading = false;

  bool get _isEditing => widget.collection != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.collection!.collectionName;
      _descriptionController.text =
          widget.collection!.collectionDescription ?? '';
      _existingImageUrl = widget.collection!.collectionPicture;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
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
          _existingImageUrl = null; // Clear existing image if new one selected
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
                leading: const Icon(Icons.photo_library, color: Color(0xFF06d6a0)),
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

  Future<void> _saveCollection() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a collection name'),
          backgroundColor: Color(0xFFf54748),
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
            '${DateTime.now().millisecondsSinceEpoch}_collection.jpg';
        imageUrl = await _collectionsService.uploadImage(
          _selectedImagePath!,
          fileName,
        );
      }

      if (_isEditing) {
        // Update existing collection
        await _collectionsService.updateCollection(
          collectionId: widget.collection!.id,
          collectionName: _nameController.text.trim(),
          collectionDescription: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          collectionPicture: imageUrl,
        );
      } else {
        // Create new collection
        await _collectionsService.createCollection(
          collectionName: _nameController.text.trim(),
          collectionDescription: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          collectionPicture: imageUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing
                ? 'Collection updated successfully'
                : 'Collection created successfully'),
            backgroundColor: const Color(0xFF06d6a0),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving collection: $e'),
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
          _isEditing ? 'Edit Collection' : 'New Collection',
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
              onPressed: _saveCollection,
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

            // Collection Name
            const Text(
              'Collection Name',
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
                hintText: 'e.g., Favorite Cafes, Weekend Trips',
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
            const Text(
              'Description (Optional)',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFFf5f6fa),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: Color(0xFFf5f6fa),
              ),
              decoration: InputDecoration(
                hintText: 'Add a brief description...',
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
