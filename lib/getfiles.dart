import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class FolderFile {
  final String name;
  final bool isFolder;
  final String bucket;
  final String fullPath;
  FolderFile({
    required this.name,
    required this.isFolder,
    required this.bucket,
    required this.fullPath,
  });
}

class PastPaperProvider extends ChangeNotifier {
  List<FolderFile> _items = [];
  bool _loading = false;
  String? _error;

  // Cache for all folders/files by bucket and path
  final Map<String, Map<String, List<FolderFile>>> _cache = {};

  // Add public getter for cache
  Map<String, Map<String, List<FolderFile>>> get cache => _cache;

  List<FolderFile> get items => _items;
  bool get loading => _loading;
  String? get error => _error;

  String _currentBucket = 'pastpapers';
  String _currentPath = '';

  String get currentBucket => _currentBucket;
  String get currentPath => _currentPath;

  // Add setters for currentPath and currentBucket
  set currentPath(String value) => _currentPath = value;
  set currentBucket(String? value) => _currentBucket = value ?? '';

  // Prefetch all folders/files on startup
  Future<void> prefetchAll() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final buckets = [
        {'client': Supabase.instance.client, 'name': 'pastpapers'},
        {'client': tempSupabaseClient, 'name': 'pastpaper1'},
      ];

      for (final bucket in buckets) {
        await _prefetchBucket(bucket['client'] as SupabaseClient, bucket['name'] as String);
      }
    } catch (e, stack) {
      debugPrint('[ERROR] Prefetch exception: $e');
      debugPrint('[ERROR] Stack trace: $stack');
      _error = 'Failed to prefetch files: ${e.toString()}';
    }

    _loading = false;
    notifyListeners();
  }

  Future<void> _prefetchBucket(SupabaseClient client, String bucketName) async {
    // Fetch root
    final rootItems = await _fetchFolder(client, bucketName, '');
    _cache[bucketName] = {'': rootItems};

    // Fetch depth 1 folders
    for (final item in rootItems.where((f) => f.isFolder)) {
      final folderPath = item.fullPath;
      final depth1Items = await _fetchFolder(client, bucketName, folderPath);
      _cache[bucketName]![folderPath] = depth1Items;

      // Optionally, fetch deeper folders in background
      for (final subItem in depth1Items.where((f) => f.isFolder)) {
        final subFolderPath = subItem.fullPath;
        _fetchFolder(client, bucketName, subFolderPath).then((deeperItems) {
          _cache[bucketName]![subFolderPath] = deeperItems;
          notifyListeners();
        });
      }
    }
  }

  Future<List<FolderFile>> _fetchFolder(SupabaseClient client, String bucket, String folderPath) async {
    final response = await client.storage.from(bucket).list(path: folderPath);
    final List<FolderFile> items = [];
    for (final item in response) {
      final rawName = item.name;
      if (rawName == '.keep' || rawName == '.emptyFolderPlaceholder') continue;
      bool isFolder = false;
      String displayName = rawName;
      if (rawName.endsWith('_folder')) {
        isFolder = true;
        displayName = rawName.substring(0, rawName.length - '_folder'.length);
      } else {
        // If item has no metadata or has a mime type, treat as file
        isFolder = item.metadata == null && !rawName.contains('.');
      }
      final fullPath = folderPath.isEmpty ? rawName : '$folderPath/$rawName';
      items.add(FolderFile(
        name: displayName,
        isFolder: isFolder,
        bucket: bucket,
        fullPath: fullPath,
      ));
    }
    // No filtering: both folders and files are included
    return items;
  }

  // Fetch root folders/files (from cache if available, otherwise fetch from Supabase)
  Future<void> fetchRootFoldersAndFiles({bool force = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final mainBucket = 'pastpapers';
      final tempBucket = 'pastpaper1';

      bool cacheEmpty = (_cache[mainBucket]?[''] == null) && (_cache[tempBucket]?[''] == null);

      if (cacheEmpty || force) {
        final mainClient = Supabase.instance.client;
        final tempClient = tempSupabaseClient;

        final mainRoot = await _fetchFolder(mainClient, mainBucket, '');
        final tempRoot = await _fetchFolder(tempClient, tempBucket, '');

        _cache[mainBucket] = {'': mainRoot};
        _cache[tempBucket] = {'': tempRoot};

        _items = [...mainRoot, ...tempRoot];
      } else {
        final mainRoot = _cache[mainBucket]?[''] ?? [];
        final tempRoot = _cache[tempBucket]?[''] ?? [];
        _items = [...mainRoot, ...tempRoot];
      }

      _currentBucket = '';
      _currentPath = '';
    } catch (e) {
      if (e.toString().toLowerCase().contains('SocketException') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection')) {
        _error = 'Network error: Please check your internet connection and try again.';
      } else {
        _error = 'Failed to fetch files. Please try again later.';
      }
      _items = [];
    }

    _loading = false;
    notifyListeners();
  }

  // Fetch folder contents (from cache if available)
  Future<void> fetchFolderContents(String bucket, String folderPath, {bool force = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final cached = _cache[bucket]?[folderPath];
      if (cached != null && !force) {
        _items = cached;
      } else {
        final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
        final items = await _fetchFolder(client, bucket, folderPath);
        _items = items;
        _cache[bucket] ??= {};
        _cache[bucket]![folderPath] = items;
      }
      _currentBucket = bucket;
      _currentPath = folderPath;
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection')) {
        _error = 'Network error: Please check your internet connection and try again.';
      } else {
        _error = 'Failed to fetch files. Please try again later.';
      }
    }
    _loading = false;
    notifyListeners();
  }

  // Add this method for clearing items safely
  void clearItems() {
    _items = [];
    notifyListeners();
  }
}

// Fetch folder contents and update provider
void fetchFolder({
  required BuildContext context,
  required String folderPath,
  String? bucket,
  bool force = false,
}) {
  final provider = Provider.of<PastPaperProvider>(context, listen: false);
  if (force || folderPath != provider.currentPath || bucket != provider.currentBucket) {
    if (folderPath.isEmpty) {
      provider.fetchRootFoldersAndFiles(force: force);
    } else {
      provider.fetchFolderContents(bucket ?? '', folderPath, force: force);
    }
    provider.currentPath = folderPath;
    provider.currentBucket = bucket;
  }
}

// Helper to count files/folders inside a folder (excluding .keep and .emptyFolderPlaceholder)
Future<int> getFolderItemCount(BuildContext context, FolderFile folder) async {
  final provider = Provider.of<PastPaperProvider>(context, listen: false);
  final cacheMap = provider.cache[folder.bucket];
  List<FolderFile>? cachedItems = cacheMap != null ? cacheMap[folder.fullPath] : null;
  if (cachedItems != null) {
    // Exclude .keep and .emptyFolderPlaceholder
    return cachedItems
        .where((item) => item.name != '.keep' && item.name != '.emptyFolderPlaceholder')
        .length;
  }
  // If not cached, fetch and filter
  final client = folder.bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
  final items = await client.storage.from(folder.bucket).list(path: folder.fullPath);
  return items
      .where((item) => item.name != '.keep' && item.name != '.emptyFolderPlaceholder')
      .length;
}

// Download logic
Future<void> downloadFile(BuildContext context, FolderFile file) async {
  final client = file.bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
  final url = client.storage.from(file.bucket).getPublicUrl(file.fullPath);
  final filename = file.name;
  final savePath = '/storage/emulated/0/Download/$filename';

  showModalBottomSheet(
    context: context,
    isDismissible: false,
    builder: (context) {
      double progress = 0.0;
      return StatefulBuilder(
        builder: (context, setState) {
          Future.microtask(() async {
            try {
              final response = await client.storage.from(file.bucket).download(file.fullPath);
              final fileOut = File(savePath);
              await fileOut.writeAsBytes(response);
              setState(() {
                progress = 1.0;
              });
            } catch (e) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red),
              );
            }
          });

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Downloading...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 16),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
                const SizedBox(height: 16),
                Text('Saving to: $savePath', style: const TextStyle(fontSize: 13, color: Colors.grey)),
                if (progress == 1.0)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Done'),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}

// Helper to build file URL using correct SupabaseClient and bucket
String buildFileUrl(String bucket, String filePath) {
  final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
  return client.storage.from(bucket).getPublicUrl(filePath);
}

// File upload logic
Future<void> showUploadFileDialog({
  required BuildContext context,
  required String folderPath,
  required String bucket,
  required VoidCallback onUploaded,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      title: const Text('Select File Type', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.image, color: Colors.white),
            label: const Text('Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx, 'image'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text('PDF'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx, 'pdf'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.insert_drive_file, color: Colors.white),
            label: const Text('Other File'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx, 'other'),
          ),
        ],
      ),
    ),
  );
  if (result == 'image') {
    await _showImageSourceDialog(context, folderPath, bucket, onUploaded);
  } else if (result == 'pdf') {
    await _pickAndUploadPDF(context, folderPath, bucket, onUploaded);
  } else if (result == 'other') {
    await _pickAndUploadAny(context, folderPath, bucket, onUploaded);
  }
}

Future<void> _showImageSourceDialog(
  BuildContext context,
  String folderPath,
  String bucket,
  VoidCallback onUploaded,
) async {
  final source = await showDialog<ImageSource>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      title: const Text('Select Image Source', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            label: const Text('Camera'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.photo_library, color: Colors.white),
            label: const Text('Gallery'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              minimumSize: const Size.fromHeight(44),
            ),
            onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source != null) {
    await _pickAndUploadImage(context, source, folderPath, bucket, onUploaded);
  }
}

// Prompt user for a new file name (returns null if cancelled)
Future<String?> promptForFileName(BuildContext context, String originalName) async {
  final ext = originalName.contains('.') ? '.${originalName.split('.').last}' : '';
  final controller = TextEditingController(text: originalName.replaceAll(ext, ''));
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      title: const Text('Rename File', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'File name',
          suffixText: ext,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        autofocus: true,
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, null),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx, '$name$ext');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

// Prompt user for a new folder name (returns null if cancelled)
Future<String?> promptForFolderName(BuildContext context) async {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
      title: const Text('Create Folder', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Folder name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        autofocus: true,
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, null),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.deepPurple,
            side: const BorderSide(color: Colors.deepPurple),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(ctx, name);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Create'),
        ),
      ],
    ),
  );
}

// Create folder in Supabase storage (adds _folder suffix)
Future<void> createFolder({
  required BuildContext context,
  required String folderPath,
  required String bucket,
  required VoidCallback onCreated,
}) async {
  final folderName = await promptForFolderName(context);
  if (folderName == null || folderName.trim().isEmpty) return;

  final folderObjectName = '${folderName}_folder';
  final fullPath = folderPath.isEmpty ? folderObjectName : '$folderPath/$folderObjectName';

  // Use correct client for temp bucket
  final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;

  try {
    // Create a temporary empty file to represent the folder
    final tempDir = Directory.systemTemp;
    final tempFile = await File('${tempDir.path}/empty_folder_placeholder').create();
    await tempFile.writeAsBytes([]);
    await client.storage.from(bucket).upload(
      fullPath,
      tempFile,
      fileOptions: const FileOptions(upsert: false, contentType: 'application/x-empty'),
    );
    await tempFile.delete();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Folder "$folderName" created!'), backgroundColor: Colors.green),
    );
    onCreated();
    refreshCurrentFolder(context);
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to create folder: ${e.toString().replaceAll('Exception: ', '')}'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// Helper to refresh current folder after upload/deletion
void refreshCurrentFolder(BuildContext context) {
  final provider = Provider.of<PastPaperProvider>(context, listen: false);
  if (provider.currentPath.isEmpty) {
    provider.fetchRootFoldersAndFiles(force: true);
  } else {
    provider.fetchFolderContents(provider.currentBucket, provider.currentPath, force: true);
  }
}

Future<void> _pickAndUploadImage(
  BuildContext context,
  ImageSource source,
  String folderPath,
  String bucket,
  VoidCallback onUploaded,
) async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source);
  if (picked == null) return;

  // Ask for new file name
  final newName = await promptForFileName(context, picked.name);
  if (newName == null || newName.trim().isEmpty) return;

  final file = File(picked.path);
  final storagePath = folderPath.isEmpty ? newName : '$folderPath/$newName';

  // Show upload progress as a persistent SnackBar
  final scaffold = ScaffoldMessenger.of(context);
  final progressController = ValueNotifier<double>(0.0);
  final uploadingSnackBar = SnackBar(
    duration: const Duration(days: 1),
    content: ValueListenableBuilder<double>(
      valueListenable: progressController,
      builder: (context, progress, _) {
        return Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                progress < 1.0
                  ? 'Uploading...'
                  : 'Image uploaded!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.deepPurple,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.all(16),
  );
  scaffold.showSnackBar(uploadingSnackBar);

  try {
    // Use correct client for temp bucket
    final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;

    await client.storage.from(bucket).upload(
      storagePath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );
    progressController.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 700));
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('Image uploaded!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        margin: EdgeInsets.all(16),
      ),
    );
    onUploaded();
    refreshCurrentFolder(context);
  } catch (e) {
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          e.toString().contains('SocketException') ||
                  e.toString().toLowerCase().contains('network') ||
                  e.toString().toLowerCase().contains('connection')
              ? 'Network error: Please check your internet connection and try again.'
              : 'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

Future<void> _pickAndUploadPDF(
  BuildContext context,
  String folderPath,
  String bucket,
  VoidCallback onUploaded,
) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
  if (result == null || result.files.isEmpty) return;

  // Ask for new file name
  final newName = await promptForFileName(context, result.files.single.name);
  if (newName == null || newName.trim().isEmpty) return;

  final file = File(result.files.single.path!);
  final storagePath = folderPath.isEmpty ? newName : '$folderPath/$newName';

  // Show upload progress as a persistent SnackBar
  final scaffold = ScaffoldMessenger.of(context);
  final progressController = ValueNotifier<double>(0.0);
  final uploadingSnackBar = SnackBar(
    duration: const Duration(days: 1),
    content: ValueListenableBuilder<double>(
      valueListenable: progressController,
      builder: (context, progress, _) {
        return Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                progress < 1.0
                  ? 'Uploading...'
                  : 'PDF uploaded!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.deepPurple,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.all(16),
  );
  scaffold.showSnackBar(uploadingSnackBar);

  try {
    // Use correct client for temp bucket
    final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;

    await client.storage.from(bucket).upload(
      storagePath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );
    progressController.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 700));
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('PDF uploaded!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        margin: EdgeInsets.all(16),
      ),
    );
    onUploaded();
    refreshCurrentFolder(context);
  } catch (e) {
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          e.toString().contains('SocketException') ||
                  e.toString().toLowerCase().contains('network') ||
                  e.toString().toLowerCase().contains('connection')
              ? 'Network error: Please check your internet connection and try again.'
              : 'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// Add this function for any file type
Future<void> _pickAndUploadAny(
  BuildContext context,
  String folderPath,
  String bucket,
  VoidCallback onUploaded,
) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.any);
  if (result == null || result.files.isEmpty) return;

  final newName = await promptForFileName(context, result.files.single.name);
  if (newName == null || newName.trim().isEmpty) return;

  final file = File(result.files.single.path!);
  final storagePath = folderPath.isEmpty ? newName : '$folderPath/$newName';

  final scaffold = ScaffoldMessenger.of(context);
  final progressController = ValueNotifier<double>(0.0);
  final uploadingSnackBar = SnackBar(
    duration: const Duration(days: 1),
    content: ValueListenableBuilder<double>(
      valueListenable: progressController,
      builder: (context, progress, _) {
        return Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                progress < 1.0
                  ? 'Uploading...'
                  : 'File uploaded!',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.deepPurple,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    margin: const EdgeInsets.all(16),
  );
  scaffold.showSnackBar(uploadingSnackBar);

  try {
    // Use correct client for temp bucket
    final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;

    await client.storage.from(bucket).upload(
      storagePath,
      file,
      fileOptions: const FileOptions(upsert: true),
    );
    progressController.value = 1.0;
    await Future.delayed(const Duration(milliseconds: 700));
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      const SnackBar(
        content: Text('File uploaded!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        margin: EdgeInsets.all(16),
      ),
    );
    onUploaded();
    refreshCurrentFolder(context);
  } catch (e) {
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(
      SnackBar(
        content: Text(
          e.toString().contains('SocketException') ||
                  e.toString().toLowerCase().contains('network') ||
                  e.toString().toLowerCase().contains('connection')
              ? 'Network error: Please check your internet connection and try again.'
              : 'Upload failed: ${e.toString().replaceAll('Exception: ', '')}',
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// Rename file or folder in Supabase storage
Future<bool> renameItem({
  required BuildContext context,
  required FolderFile item,
  required String newName,
}) async {
  final bucket = item.bucket;
  final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
  // Ensure correct parent path and new full path
  final parentPath = item.fullPath.contains('/') ? item.fullPath.substring(0, item.fullPath.lastIndexOf('/')) : '';
  final newFullPath = parentPath.isEmpty ? newName : '$parentPath/$newName';

  try {
    if (item.isFolder) {
      // 1. Create the new folder "file" at the correct path
      final tempDir = Directory.systemTemp;
      final tempFile = await File('${tempDir.path}/empty_folder_placeholder').create();
      await tempFile.writeAsBytes([]);
      await client.storage.from(bucket).upload(
        newFullPath,
        tempFile,
        fileOptions: const FileOptions(upsert: false, contentType: 'application/x-empty'),
      );
      await tempFile.delete();

      // 2. Copy all contents to new folder path
      final contents = await client.storage.from(bucket).list(path: item.fullPath);
      for (final subItem in contents) {
        final oldSubPath = '${item.fullPath}/${subItem.name}';
        final newSubPath = '$newFullPath/${subItem.name}';
        final fileBytes = await client.storage.from(bucket).download(oldSubPath);
        await client.storage.from(bucket).upload(newSubPath, File.fromRawPath(fileBytes), fileOptions: const FileOptions(upsert: true));
      }

      // 3. Delete old folder and its contents
      for (final subItem in contents) {
        await client.storage.from(bucket).remove(['${item.fullPath}/${subItem.name}']);
      }
      await client.storage.from(bucket).remove([item.fullPath]);
    } else {
      // File: copy to new full path, delete old
      final fileBytes = await client.storage.from(bucket).download(item.fullPath);
      await client.storage.from(bucket).upload(newFullPath, File.fromRawPath(fileBytes), fileOptions: const FileOptions(upsert: true));
      await client.storage.from(bucket).remove([item.fullPath]);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Renamed successfully!'), backgroundColor: Colors.green),
    );
    refreshCurrentFolder(context);
    return true;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rename failed: ${e.toString()}'), backgroundColor: Colors.red),
    );
    return false;
  }
}
