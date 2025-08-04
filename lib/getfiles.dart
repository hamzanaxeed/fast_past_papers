import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

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
  Future<void> fetchRootFoldersAndFiles() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final mainBucket = 'pastpapers';
      final tempBucket = 'pastpaper1';

      // If cache is empty, fetch from Supabase and update cache
      bool cacheEmpty = (_cache[mainBucket]?[''] == null) && (_cache[tempBucket]?[''] == null);

      if (cacheEmpty) {
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
      _error = 'Failed to fetch files: ${e.toString()}';
      _items = [];
    }

    _loading = false;
    notifyListeners();
  }

  // Fetch folder contents (from cache if available)
  Future<void> fetchFolderContents(String bucket, String folderPath) async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final cached = _cache[bucket]?[folderPath];
      if (cached != null) {
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
      _error = 'Failed to fetch files: ${e.toString()}';
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
      provider.fetchRootFoldersAndFiles();
    } else {
      provider.fetchFolderContents(bucket ?? '', folderPath);
    }
    provider.currentPath = folderPath;
    provider.currentBucket = bucket;
  }
}

// Helper to count files/folders inside a folder
Future<int> getFolderItemCount(BuildContext context, FolderFile folder) async {
  final provider = Provider.of<PastPaperProvider>(context, listen: false);
  final cached = provider.items;
  if (cached.isNotEmpty && folder.fullPath == provider.currentPath && folder.bucket == provider.currentBucket) {
    return cached.length;
  }
  final cacheMap = provider.cache[folder.bucket];
  if (cacheMap != null && cacheMap.containsKey(folder.fullPath)) {
    return cacheMap[folder.fullPath]!.length;
  }
  final client = folder.bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
  final items = await client.storage.from(folder.bucket).list(path: folder.fullPath);
  return items.length;
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
