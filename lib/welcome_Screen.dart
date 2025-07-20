// To revert to the old look, restore the original _cardDecoration and gradient in build().
import 'other_Viewers.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'image_Viewer.dart';
import 'pdf_Viewer.dart';
import 'dart:async';
import 'feedback.dart'; // <-- Add this import
import 'editor_Handling.dart'; // <-- Add this import
import 'package:path_provider/path_provider.dart'; // <-- Add this import
import 'package:http/http.dart' as http; // <-- Add this import
import 'log.dart'; // <-- Add this import
import 'view_Logs.dart'; // <-- Add this import

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  // Static method to fetch editor emails for role check at login
  static Future<void> fetchEditorEmailsStatic() async {
    try {
      final response = await Supabase.instance.client
          .from('Editors')
          .select('Editor_Email');
      // No need to store globally, just ensures up-to-date on login
    } catch (e) {
      // Ignore errors here, handled in widget
    }
  }

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _SearchResult {
  final FileObject file;
  final String fullPath;
  _SearchResult(this.file, this.fullPath);
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  String currentPath = '';
  List<FileObject> items = [];
  bool loading = true;
  String? error;
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Admin email
  static const String adminEmail = 'l230618@lhr.nu.edu.pk';
  List<String> editor_Emails = []; // Ensure this is always a list, never null
  bool editorsFetched = false;

  // Add this map to cache folder item counts
  final Map<String, int> _folderCounts = {};

  // Add this field to manage the subscription
  StreamSubscription<dynamic>? _editorSub;

  // For global search
  List<_SearchResult> _globalSearchResults = [];
  bool _globalSearchLoading = false;

  // Cached files/folders for global search
  late Future<List<_SearchResult>> _cachedFilesFuture;

  // Synchronous cache for all files/folders for search
  List<_SearchResult> _allFilesCache = [];

  // Always fetch editor emails before checking roles
  Future<void> fetchEditorEmails() async {
    try {
      final response = await Supabase.instance.client
          .from('Editors')
          .select('Editor_Email');
      if (response is List) {
        editor_Emails = response
            .map((e) => e['Editor_Email']?.toString().toLowerCase())
            .where((email) => email != null)
            .cast<String>()
            .toList();
        editorsFetched = true;
      } else {
        print('Unexpected response format: $response');
      }
    } catch (e) {
      print('Error fetching editor emails: $e');
      editorsFetched = false;
    }
  }

  Future<bool> get isAdmin async {
    await fetchEditorEmails();
    return FirebaseAuth.instance.currentUser?.email?.toLowerCase() == adminEmail;
  }

  Future<bool> get isEditor async {
    await fetchEditorEmails();
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    // Ensure editor_Emails is always a list, never null
    return email == adminEmail || (email != null && (editor_Emails).contains(email));
  }

  String get displayPath {
    if (currentPath.isEmpty) return 'Past Papers';
    final parts = currentPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .map((p) => p.replaceAll('_folder', ''))
        .toList();
    return parts.join(' / ');
  }

  @override
  void initState() {
    super.initState();
    fetchEditorEmails().then((_) {
      _loadFolder('');
    });
    // Populate the synchronous cache at app start
    _cachedFilesFuture = _fetchAllFilesAndFolders('', 0, 4, 2000);
    _cachedFilesFuture.then((list) {
      setState(() {
        _allFilesCache = list;
      });
    });
    // Listen for real-time changes in Editors table
    _editorSub = Supabase.instance.client
        .from('Editors')
        .stream(primaryKey: ['Editor_Email'])
        .listen((data) {
      final emails = data
          .map((e) => e['Editor_Email']?.toString().toLowerCase())
          .where((email) => email != null)
          .cast<String>()
          .toList();
      setState(() {
        editor_Emails = emails;
        editorsFetched = true;
      });
      print('Realtime update: editor emails = $editor_Emails');
    });
  }

  @override
  void dispose() {
    _editorSub?.cancel();
    _searchController.dispose();
    _searchTimeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
          (route) => false,
    );
  }

  Future<void> _loadFolder(String path) async {
    setState(() {
      loading = true;
      error = null;
      items = [];
      searchQuery = '';
      _searchController.clear();
      _folderCounts.clear();
    });

    await fetchEditorEmails();

    try {
      final response =
      await Supabase.instance.client.storage.from('pastpapers').list(path: path);
      setState(() {
        currentPath = path;
        items = response;
        loading = false;
      });
      // Log folder open event
      if (path.isNotEmpty) {
        logUserEvent('Opened Folder', details: path);
      } else {
        logUserEvent('Opened Root Folder');
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load folder: $e';
        loading = false;
      });
      logUserEvent('Load Folder Failed', details: '$path | $e');
    }
  }

  void _onTapItem(FileObject file) async {
    if (_selectionMode && await isAdmin) {
      _toggleSelection(file);
      logUserEvent('Toggled Selection', details: file.name);
      return;
    }
    if (_isFolder(file)) {
      final nextPath = currentPath.isEmpty
          ? file.name
          : currentPath + (currentPath.endsWith('/') ? '' : '/') + file.name;
      logUserEvent('Opened Folder', details: nextPath);
      _loadFolder(nextPath);
    } else if (_isImage(file.name)) {
      final filePath =
      currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
      final url = Supabase.instance.client.storage
          .from('pastpapers')
          .getPublicUrl(filePath);
      logUserEvent('Viewed Image', details: filePath);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImageViewer(url: url, name: file.name),
        ),
      );
    } else if (_isPdf(file.name)) {
      final filePath =
      currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
      final url = Supabase.instance.client.storage
          .from('pastpapers')
          .getPublicUrl(filePath);
      logUserEvent('Viewed PDF', details: filePath);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(url: url, name: file.name),
        ),
      );
    } else if (_isPptx(file.name) || _isDocx(file.name) || _isXlsx(file.name) || _isTxt(file.name)) {
      final filePath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
      final url = Supabase.instance.client.storage
          .from('pastpapers')
          .getPublicUrl(filePath);
      logUserEvent('Viewed Other File', details: filePath);
      // Use push, not pushAndRemoveUntil, so back returns to last folder
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherViewer(url: url, name: file.name),
        ),
      );
    }
  }

  void _onLongPressItem(FileObject file) async {
    if (await isAdmin) {
      logUserEvent('Long Pressed Item', details: file.name);
      showModalBottomSheet(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(context);
                  await _showRenameDialog(file);
                  logUserEvent('Rename Dialog Opened', details: file.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(file, isFolder: _isFolder(file));
                  logUserEvent('Delete Dialog Opened', details: file.name);
                },
              ),
              ListTile(
                leading: const Icon(Icons.select_all),
                title: const Text('Select'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectionMode = true;
                    _selectedItems.add(file);
                  });
                  logUserEvent('Selection Mode Started', details: file.name);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _showRenameDialog(FileObject file) async {
    final isFolder = _isFolder(file);
    final oldName = isFolder
        ? file.name.replaceAll('_folder', '')
        : file.name;
    final controller = TextEditingController(text: oldName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Rename ${isFolder ? "Folder" : "File"}'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: isFolder ? 'Folder name' : 'File name',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result != oldName) {
      await _renameItem(file, result, isFolder: isFolder);
    }
  }

  Future<void> _renameItem(FileObject file, String newName, {required bool isFolder}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (isFolder) {
        // Ensure _folder suffix
        final newFolderName = newName.endsWith('_folder') ? newName : '${newName}_folder';
        final oldPath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
        final newPath = currentPath.isEmpty ? newFolderName : '$currentPath/$newFolderName';
        await _moveFolderRecursively(oldPath, newPath);
        logUserEvent('Renamed Folder', details: '$oldPath -> $newPath');
      } else {
        final oldPath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
        final newPath = currentPath.isEmpty ? newName : '$currentPath/$newName';
        await Supabase.instance.client.storage
            .from('pastpapers')
            .move(oldPath, newPath);
        logUserEvent('Renamed File', details: '$oldPath -> $newPath');
      }
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after rename
    } catch (e) {
      setState(() {
        error = 'Failed to rename: $e';
        loading = false;
      });
      logUserEvent('Rename Failed', details: '${file.name} | $e');
    }
  }

  Future<void> _moveFolderRecursively(String oldPath, String newPath) async {
    final contents = await Supabase.instance.client.storage
        .from('pastpapers')
        .list(path: oldPath);
    for (final item in contents) {
      final oldItemPath = '$oldPath/${item.name}';
      final newItemPath = '$newPath/${item.name}';
      if (_isFolder(item)) {
        await _moveFolderRecursively(oldItemPath, newItemPath);
      } else {
        await Supabase.instance.client.storage
            .from('pastpapers')
            .move(oldItemPath, newItemPath);
      }
    }
    // Optionally, remove the old folder's .keep file if present
    try {
      await Supabase.instance.client.storage
          .from('pastpapers')
          .remove(['$oldPath/.keep']);
    } catch (_) {}
  }

  Future<void> _deleteSelectedItems() async {
    print('DEBUG: Starting deleteSelectedItems with ${_selectedItems.length} items');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Items'),
        content: Text('Are you sure you want to delete ${_selectedItems.length} selected item(s)? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        loading = true;
        error = null;
      });
      try {
        for (final file in _selectedItems) {
          print('DEBUG: Processing ${file.name}');
          if (_isFolder(file)) {
            final folderPath = currentPath.isEmpty
                ? file.name
                : '$currentPath/${file.name}';
            print('DEBUG: Deleting folder recursively: $folderPath');
            await _deleteFolderRecursively(folderPath);
            logUserEvent('Deleted Folder', details: folderPath);
          } else {
            final filePath = currentPath.isEmpty
                ? file.name
                : '$currentPath/${file.name}';
            print('DEBUG: Deleting file: $filePath');
            await Supabase.instance.client.storage
                .from('pastpapers')
                .remove([filePath]);
            logUserEvent('Deleted File', details: filePath);
          }
        }
        print('DEBUG: Finished deleting selected items');
        _clearSelection();
        _folderCounts.clear(); // Clear cache before refresh
        await _loadFolder(currentPath); // Ensure refresh after multi-delete
      } catch (e) {
        print('DEBUG: Error during deletion: $e');
        setState(() {
          error = 'Failed to delete: $e';
          loading = false;
        });
        logUserEvent('Delete Selected Failed', details: '$e');
      }
    }
  }

  // Recursively delete all files and subfolders in a folder
  Future<void> _deleteFolderRecursively(String folderPath) async {
    print('DEBUG: Entering _deleteFolderRecursively for $folderPath');
    final contents = await Supabase.instance.client.storage
        .from('pastpapers')
        .list(path: folderPath);
    print('DEBUG: $folderPath contents: ${contents.map((e) => e.name).toList()}');
    for (final item in contents) {
      final itemPath = '$folderPath/${item.name}';
      if (item.name.endsWith('_folder')) {
        print('DEBUG: Recursing into subfolder: $itemPath');
        await _deleteFolderRecursively(itemPath);
      } else {
        print('DEBUG: Deleting file in folder: $itemPath');
        await Supabase.instance.client.storage
            .from('pastpapers')
            .remove([itemPath]);
        logUserEvent('Deleted File', details: itemPath);
      }
    }
    // Optionally, remove the .keep file if present
    final keepPath = '$folderPath/.keep';
    try {
      print('DEBUG: Attempting to remove .keep file: $keepPath');
      await Supabase.instance.client.storage
          .from('pastpapers')
          .remove([keepPath]);
      logUserEvent('Deleted .keep File', details: keepPath);
    } catch (e) {
      print('DEBUG: Could not remove .keep file: $e');
      logUserEvent('Delete .keep Failed', details: '$keepPath | $e');
    }
  }

  bool _isFolder(FileObject file) {
    return file.name.endsWith('_folder');
  }

  bool _isImage(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.jpg') ||
        ext.endsWith('.jpeg') ||
        ext.endsWith('.png') ||
        ext.endsWith('.gif');
  }

  bool _isPdf(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.pdf');
  }

  bool _isPptx(String name) => name.toLowerCase().endsWith('.pptx');
  bool _isDocx(String name) => name.toLowerCase().endsWith('.docx');
  bool _isXlsx(String name) => name.toLowerCase().endsWith('.xlsx');
  bool _isTxt(String name) => name.toLowerCase().endsWith('.txt');

  // Add this method to get the number of items in a folder (with cache)
  Future<int> _getFolderItemCount(String folderPath) async {
    if (_folderCounts.containsKey(folderPath)) {
      return _folderCounts[folderPath]!;
    }
    try {
      final contents = await Supabase.instance.client.storage.from('pastpapers').list(path: folderPath);
      // Exclude .keep and .emptyFolderPlaceholder
      final count = contents.where((f) => f.name != '.keep' && f.name != '.emptyFolderPlaceholder').length;
      _folderCounts[folderPath] = count;
      return count;
    } catch (_) {
      return 0;
    }
  }

  // Recursively fetch all files/folders under a given path for global search
  // Add maxDepth and maxResults to speed up search and avoid excessive recursion
  Future<List<_SearchResult>> _fetchAllFilesAndFolders(
    [String path = '',
    int depth = 0,
    int maxDepth = 4,
    int maxResults = 2000,
    List<_SearchResult>? acc]
  ) async {
    acc ??= [];
    if (depth > maxDepth || acc.length > maxResults) return acc;
    final items = await Supabase.instance.client.storage.from('pastpapers').list(path: path);
    for (final item in items) {
      final itemPath = path.isEmpty ? item.name : '$path/${item.name}';
      acc.add(_SearchResult(item, itemPath));
      if (_isFolder(item)) {
        if (acc.length > maxResults) break;
        await _fetchAllFilesAndFolders(itemPath, depth + 1, maxDepth, maxResults, acc);
        if (acc.length > maxResults) break;
      }
    }
    return acc;
  }

  // Improved card decoration for modern look
  BoxDecoration _cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.blue.withOpacity(0.08), width: 1),
      );

  // Improved search bar using synchronous cache for instant search
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.10),
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '🔍 Search files or folders...',
            prefixIcon: const Icon(Icons.search, color: Color(0xFF1976D2)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
          style: const TextStyle(fontSize: 16),
          onChanged: (value) {
            final query = value.trim().toLowerCase();
            setState(() {
              searchQuery = query;
              _globalSearchLoading = query.isNotEmpty;
              _searchTimedOut = false;
            });

            // Cancel any previous timer
            _searchTimeoutTimer?.cancel();

            // Start timer if searching
            if (query.isNotEmpty) {
              _searchTimeoutTimer = Timer(const Duration(seconds: 10), () {
                if (mounted && _globalSearchLoading && _globalSearchResults.isEmpty) {
                  setState(() {
                    _searchTimedOut = true;
                  });
                }
              });
            }

            // Only search if cache is loaded
            if (query.isNotEmpty && _allFilesCache.isNotEmpty) {
              final result = _allFilesCache.where((f) =>
                f.file.name.toLowerCase().contains(query)
              ).toList();

              setState(() {
                _globalSearchResults = result;
                _globalSearchLoading = false;
                _searchTimedOut = false;
              });
              _searchTimeoutTimer?.cancel();
            } else if (query.isEmpty) {
              setState(() {
                _globalSearchResults = [];
                _globalSearchLoading = false;
                _searchTimedOut = false;
              });
              _searchTimeoutTimer?.cancel();
            }
            // If cache is not loaded, do not set _globalSearchResults yet
          },
        ),
      ),
    );
  }

  // Improved list view with more spacing and hover effect
  Widget _buildList() {
    if (_globalSearchLoading) {
      // Show timeout message if search takes too long
      if (_searchTimedOut) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.refresh, color: Colors.orange, size: 40),
                SizedBox(height: 12),
                Text(
                  'Search is taking too long.\nYou should refresh.',
                  style: TextStyle(fontSize: 18, color: Colors.orange, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }
    if (searchQuery.isNotEmpty) {
      // Show loading if cache is not ready yet
      if (_allFilesCache.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      // If searchQuery is not empty and cache is loaded but _globalSearchResults is empty,
      // re-run the search to ensure results are up-to-date (fixes "no result found" bug)
      if (_globalSearchResults.isEmpty && _allFilesCache.isNotEmpty) {
        final result = _allFilesCache.where((f) =>
          f.file.name.toLowerCase().contains(searchQuery)
        ).toList();
        // Do not show loading if there are no results, just show "No results found"
        if (result.isNotEmpty) {
          // Updateresults and rebuild
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _globalSearchResults = result;
            });
          });
          // Show nothing while updating (prevents infinite loading)
          return const SizedBox.shrink();
        }
      }
      final folders = _globalSearchResults.where((r) => _isFolder(r.file)).toList();
      final files = _globalSearchResults.where((r) => !_isFolder(r.file)).toList();
      if (folders.isEmpty && files.isEmpty) {
        return const Center(
          child: Padding(
            padding: EdgeInsets.only(top: 40),
            child: Text('No results found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
          ),
        );
      }
      return ListView(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        children: [
          ...folders.map((r) => FutureBuilder<int>(
            future: _getFolderItemCount(r.fullPath),
            builder: (context, countSnapshot) {
              final count = countSnapshot.data;
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: _cardDecoration(color: Colors.teal.withOpacity(0.10)),
                child: ListTile(
                  leading: Container(
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.folder, color: Colors.amber, size: 32),
                  ),
                  title: Text(
                    r.file.name.replaceAll('/', '').replaceAll('_folder', ''),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20, color: Colors.black87, letterSpacing: 0.2),
                  ),
                  // Show path as subtitle when searching
                  subtitle: Text(
                    r.fullPath.replaceAll('_folder', ''),
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (count == null)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Color(0xFF1976D2),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                  selected: _selectedItems.contains(r.file),
                  onTap: () => _onTapItem(r.file),
                  onLongPress: () => _onLongPressItem(r.file),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  hoverColor: Colors.amber.withOpacity(0.13),
                ),
              );
            },
          )),
          ...files.map((r) => Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: _cardDecoration(),
            child: ListTile(
              leading: Container(
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(6),
                child: _isImage(r.file.name)
                    ? const Icon(Icons.image, color: Colors.blue, size: 28)
                    : _isPdf(r.file.name)
                        ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28)
                        : _isPptx(r.file.name)
                            ? const Icon(Icons.slideshow, color: Colors.orange, size: 28)
                            : _isDocx(r.file.name)
                                ? const Icon(Icons.description, color: Colors.indigo, size: 28)
                                : _isXlsx(r.file.name)
                                    ? const Icon(Icons.table_chart, color: Colors.green, size: 28)
                                    : _isTxt(r.file.name)
                                        ? const Icon(Icons.text_snippet, color: Colors.grey, size: 28)
                                        : const Icon(Icons.insert_drive_file, color: Colors.grey, size: 28),
              ),
              title: Text(
                r.file.name,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 18, color: Colors.black87),
              ),
              // Show path as subtitle when searching
              subtitle: Text(
                r.fullPath.replaceAll('_folder', ''),
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
              selected: _selectedItems.contains(r.file),
              onTap: () => _onTapItem(r.file),
              onLongPress: () => _onLongPressItem(r.file),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              hoverColor: Colors.blue.withOpacity(0.07),
              trailing: IconButton(
                icon: const Icon(Icons.download_rounded, color: Color(0xFF1976D2), size: 26),
                tooltip: 'Download',
                onPressed: () {
                  _downloadFile(currentPath.isEmpty ? r.file.name : '$currentPath/${r.file.name}', r.file.name);
                },
              ),
            ),
          )),
        ],
      );
    }

    // Show loading indicator while loading, instead of showing "empty" immediately
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 16)));
    }

    // Exclude .emptyFolderPlaceholder from folders and files
    final folders = items
        .where(_isFolder)
        .where((f) => f.name != '.emptyFolderPlaceholder')
        .toList();
    final files = items
        .where((f) => !_isFolder(f) && f.name != '.keep' && f.name != '.emptyFolderPlaceholder')
        .toList();

    // Only show "empty" if not loading and after items are fetched
    if (folders.isEmpty && files.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text('This folder is empty.', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ),
      );
    }

    final filteredFolders = searchQuery.isEmpty
        ? folders
        : folders.where((f) => f.name.toLowerCase().contains(searchQuery)).toList();
    final filteredFiles = searchQuery.isEmpty
        ? files
        : files.where((f) => f.name.toLowerCase().contains(searchQuery)).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      children: [
        ...filteredFolders.map((f) => FutureBuilder<bool>(
          future: isAdmin,
          builder: (context, snapshot) {
            final admin = snapshot.data ?? false;
            final folderPath = currentPath.isEmpty ? f.name : '$currentPath/${f.name}';
            return FutureBuilder<int>(
              future: _getFolderItemCount(folderPath),
              builder: (context, countSnapshot) {
                final count = countSnapshot.data;
                // --- Check if this is a second-level folder (folder/subfolder) ---
                final isSecondLevel = currentPath.split('/').where((e) => e.isNotEmpty).length == 1;
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: _cardDecoration(color: Colors.teal.withOpacity(0.10)),
                  child: ListTile(
                    leading: Container(
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: const Icon(Icons.folder, color: Colors.amber, size: 32),
                    ),
                    title: Text(
                      f.name.replaceAll('/', '').replaceAll('_folder', ''),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.black87,
                          letterSpacing: 0.2),
                    ),
                    // Do NOT show subtitle (path) when browsing
                    subtitle: null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (count == null)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            child: Text(
                              '$count',
                              style: const TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        // --- Upload Here button removed ---
                        // if (isSecondLevel)
                        //   Padding(
                        //     padding: const EdgeInsets.only(left: 8.0),
                        //     child: IconButton(
                        //       icon: const Icon(Icons.upload_file, color: Color(0xFF1976D2)),
                        //       tooltip: 'Upload Here',
                        //       onPressed: () => _uploadFileToPath(folderPath),
                        //     ),
                        //   ),
                      ],
                    ),
                    selected: _selectedItems.contains(f),
                    onTap: () => _onTapItem(f),
                    onLongPress: () => _onLongPressItem(f),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    hoverColor: Colors.amber.withOpacity(0.10),
                  ),
                );
              },
            );
          },
        )),
        // --- FIX: Remove FutureBuilder for files, use direct mapping ---
        ...filteredFiles.map((f) => Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          decoration: _cardDecoration(),
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(6),
              child: _isImage(f.name)
                  ? const Icon(Icons.image, color: Colors.blue, size: 28)
                  : _isPdf(f.name)
                      ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28)
                      : _isPptx(f.name)
                          ? const Icon(Icons.slideshow, color: Colors.orange, size: 28)
                          : _isDocx(f.name)
                              ? const Icon(Icons.description, color: Colors.indigo, size: 28)
                              : _isXlsx(f.name)
                                  ? const Icon(Icons.table_chart, color: Colors.green, size: 28)
                                  : _isTxt(f.name)
                                      ? const Icon(Icons.text_snippet, color: Colors.grey, size: 28)
                                      : const Icon(Icons.insert_drive_file, color: Colors.grey, size: 28),
            ),
            title: Text(
              f.name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                  color: Colors.black87),
            ),
            // Do NOT show subtitle (path) when browsing
            subtitle: null,
            selected: _selectedItems.contains(f),
            onTap: () => _onTapItem(f),
            onLongPress: () => _onLongPressItem(f),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            hoverColor: Colors.blue.withOpacity(0.07),
            trailing: IconButton(
              icon: const Icon(Icons.download_rounded, color: Color(0xFF1976D2), size: 26),
              tooltip: 'Download',
              onPressed: () {
                _downloadFile(currentPath.isEmpty ? f.name : '$currentPath/${f.name}', f.name);
              },
            ),
          ),
        )),
      ],
    );
  }

  // Download progress state
  bool _downloading = false;
  double _downloadProgress = 0.0;
  String? _downloadError;
  String? _downloadSavePath;
  String? _downloadFileName;

  // Download file to local storage (Downloads directory or best available)
  Future<void> _downloadFile(String filePath, String fileName) async {
    setState(() {
      _downloading = true;
      _downloadProgress = 0.0;
      _downloadError = null;
      _downloadSavePath = null;
      _downloadFileName = fileName;
    });

    Future.microtask(() async {
      try {
        final url = Supabase.instance.client.storage.from('pastpapers').getPublicUrl(filePath);
        final request = http.Request('GET', Uri.parse(url));
        final response = await request.send();

        if (response.statusCode != 200) {
          throw Exception('Download failed: Server responded with status ${response.statusCode}. Please check your internet connection or try again later.');
        }

        Directory? saveDir;
        if (Platform.isAndroid) {
          final downloads = Directory('/storage/emulated/0/Download');
          if (await downloads.exists()) {
            saveDir = downloads;
          } else {
            saveDir = await getExternalStorageDirectory();
          }
        } else if (Platform.isIOS) {
          saveDir = await getApplicationDocumentsDirectory();
        } else {
          saveDir = await getDownloadsDirectory();
        }
        if (saveDir == null) throw Exception('Download failed: Unable to access device storage.');

        await saveDir.create(recursive: true);
        final savePath = '${saveDir.path}/$fileName';
        final file = File(savePath);

        final sink = file.openWrite();
        int received = 0;
        final total = response.contentLength ?? 0;

        // Throttle UI updates to every 100ms
        var lastUpdate = DateTime.now();
        double lastProgress = 0.0;

        await for (final chunk in response.stream) {
          received += chunk.length;
          final progress = total > 0 ? received / total : 0.0;
          final now = DateTime.now();
          if (progress - lastProgress > 0.01 || now.difference(lastUpdate).inMilliseconds > 100) {
            lastProgress = progress;
            lastUpdate = now;
            if (mounted) {
              setState(() {
                _downloadProgress = progress;
              });
            }
          }
          sink.add(chunk);
        }
        await sink.close();

        if (mounted) {
          setState(() {
            _downloading = false;
            _downloadProgress = 1.0;
            _downloadSavePath = savePath;
            _downloadError = null;
          });
        }
        logUserEvent('Downloaded File', details: filePath);
      } catch (e) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _downloadError = e is SocketException
                ? 'Download failed: No internet connection. Please check your network and try again.'
                : e.toString().contains('storage')
                    ? 'Download failed: Unable to access device storage. Please check permissions.'
                    : 'Download failed: ${e.toString().replaceAll('Exception: ', '')}';
            _downloadProgress = 0.0;
            _downloadSavePath = null;
          });
        }
      }
    });
  }

  Future<void> _confirmDelete(FileObject file, {required bool isFolder}) async {
    final name = isFolder
        ? file.name.replaceAll('_folder', '')
        : file.name;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${isFolder ? "Folder" : "File"}'),
        content: Text('Are you sure you want to delete "$name"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteItem(file, isFolder: isFolder);
    }
  }

  Future<void> _deleteItem(FileObject file, {required bool isFolder}) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (isFolder) {
        // Use recursive delete for folders
        final folderPath = currentPath.isEmpty
            ? file.name
            : '$currentPath/${file.name}';
        await _deleteFolderRecursively(folderPath);
        logUserEvent('Deleted Folder', details: folderPath);
      } else {
        final filePath = currentPath.isEmpty
            ? file.name
            : '$currentPath/${file.name}';
        await Supabase.instance.client.storage
            .from('pastpapers')
            .remove([filePath]);
        logUserEvent('Deleted File', details: filePath);
      }
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after delete
    } catch (e) {
      setState(() {
        error = 'Failed to delete: $e';
        loading = false;
      });
      logUserEvent('Delete Failed', details: '${file.name} | $e');
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final safeName = result.endsWith('_folder') ? result : result + '_folder';
      final folderPath = currentPath.isEmpty
          ? safeName
          : currentPath + (currentPath.endsWith('/') ? '' : '/') + safeName;
      final tempFile = await File('${Directory.systemTemp.path}/.keep').create();
      await tempFile.writeAsBytes([]);
      await Supabase.instance.client
          .storage
          .from('pastpapers')
          .upload('$folderPath/.keep', tempFile,
          fileOptions: const FileOptions(upsert: false));
      await tempFile.delete();
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after folder creation
      logUserEvent('Created Folder', details: folderPath);
      // --- Log edit event for folder creation ---
      final email = FirebaseAuth.instance.currentUser?.email ?? 'anonymous';
      await logEditEvent(email, '$folderPath was created');
    }
  }

  Future<void> _uploadFile() async {
    // Prevent guest users from uploading
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to do this action'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final type = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Add instruction text here ---
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'If you are adding a solution make sure that the name is like year mid/final solution',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Icon(Icons.cloud_upload, size: 48, color: Color(0xFF1976D2)),
              const SizedBox(height: 16),
              const Text(
                'Upload File',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose the type of file you want to upload.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text('Image', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () => Navigator.pop(context, 'image'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text('PDF', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () => Navigator.pop(context, 'pdf'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null) return;

    if (type == 'image') {
      // --- Ask for gallery or camera ---
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose where to pick the image from.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (source == null) return;
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;
      final file = File(picked.path);
      final fileName = picked.name;
      final uploadPath =
          currentPath.isEmpty ? fileName : '$currentPath/$fileName';
      await Supabase.instance.client
          .storage
          .from('pastpapers')
          .upload(uploadPath, file,
              fileOptions: const FileOptions(upsert: true));
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after upload
      logUserEvent('Uploaded Image', details: uploadPath);
      // --- Log edit event for file creation (image) ---
      final email = FirebaseAuth.instance.currentUser?.email ?? 'anonymous';
      await logEditEvent(email, '$uploadPath was created');
    } else if (type == 'pdf') {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final uploadPath = currentPath.isEmpty ? fileName : '$currentPath/$fileName';
      await Supabase.instance.client
          .storage
          .from('pastpapers')
          .upload(uploadPath, file, fileOptions: const FileOptions(upsert: true));
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after upload
      logUserEvent('Uploaded PDF', details: uploadPath);
      // --- Log edit event for file creation (pdf) ---
      final email = FirebaseAuth.instance.currentUser?.email ?? 'anonymous';
      await logEditEvent(email, '$uploadPath was created');
    }
  }

  // Add this method to upload a file to a specific path (for subfolder upload)
  Future<void> _uploadFileToPath(String targetPath) async {
    // Prevent guest users from uploading
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You must be signed in to do this action'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    final type = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Add instruction text here ---
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'If you are adding a solution make sure that the name is like year mid/final solution',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Icon(Icons.cloud_upload, size: 48, color: Color(0xFF1976D2)),
              const SizedBox(height: 16),
              const Text(
                'Upload File',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Choose the type of file you want to upload.',
                style: TextStyle(fontSize: 15, color: Colors.black87),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.image, color: Colors.white),
                      label: const Text('Image', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () => Navigator.pop(context, 'image'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text('PDF', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      onPressed: () => Navigator.pop(context, 'pdf'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
    if (type == null) return;

    if (type == 'image') {
      // --- Ask for gallery or camera ---
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Image Source'),
          content: const Text('Choose where to pick the image from.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text('Gallery'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text('Camera'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
      if (source == null) return;
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source);
      if (picked == null) return;
      final file = File(picked.path);
      final fileName = picked.name;
      final uploadPath = targetPath.isEmpty ? fileName : '$targetPath/$fileName';
      await Supabase.instance.client
          .storage
          .from('pastpapers')
          .upload(uploadPath, file,
              fileOptions: const FileOptions(upsert: true));
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after upload
      logUserEvent('Uploaded Image', details: uploadPath);
      // --- Log edit event for file creation (image) ---
      final email = FirebaseAuth.instance.currentUser?.email ?? 'anonymous';
      await logEditEvent(email, '$uploadPath was created');
    } else if (type == 'pdf') {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      final fileName = result.files.single.name;
      final uploadPath = targetPath.isEmpty ? fileName : '$targetPath/$fileName';
      await Supabase.instance.client
          .storage
          .from('pastpapers')
          .upload(uploadPath, file, fileOptions: const FileOptions(upsert: true));
      _folderCounts.clear(); // Clear cache before refresh
      await _loadFolder(currentPath); // Ensure refresh after upload
      logUserEvent('Uploaded PDF', details: uploadPath);
      // --- Log edit event for file creation (pdf) ---
      final email = FirebaseAuth.instance.currentUser?.email ?? 'anonymous';
      await logEditEvent(email, '$uploadPath was created');
    }
  }

  // Selection state for admin multi-delete
  final Set<FileObject> _selectedItems = {};
  bool _selectionMode = false;

  // Add this method to toggle selection of an item
  void _toggleSelection(FileObject file) {
    setState(() {
      if (_selectedItems.contains(file)) {
        _selectedItems.remove(file);
        if (_selectedItems.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedItems.add(file);
        _selectionMode = true;
      }
    });
  }

  // Add this method to clear all selections and exit selection mode
  void _clearSelection() {
    setState(() {
      _selectedItems.clear();
      _selectionMode = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isEditor,
      builder: (context, editorSnapshot) {
        final editor = editorSnapshot.data ?? false;

        // --- Only show upload button if in a 2-level folder (folder/subfolder) for regular users ---
        final pathSegments = currentPath.split('/').where((e) => e.isNotEmpty).toList();
        final showUploadButtonForUser = pathSegments.length == 2;

        return WillPopScope(
          onWillPop: () async {
            // Only handle back navigation in folder/file list, not in preview screens
            if (currentPath.isNotEmpty) {
              var path = currentPath.endsWith('/')
                  ? currentPath.substring(0, currentPath.length - 1)
                  : currentPath;
              final parts = path.split('/');
              if (parts.isNotEmpty) parts.removeLast();
              final parentPath = parts.isEmpty ? '' : parts.join('/');
              await _loadFolder(parentPath);
              return false; // Prevent default pop (don't exit app)
            }
            return true; // Allow app exit at root
          },
          child: Scaffold(
            extendBodyBehindAppBar: false,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(80),
              child: FutureBuilder<bool>(
                future: isAdmin,
                builder: (context, adminSnapshot) {
                  final admin = adminSnapshot.data ?? false;
                  return Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                      boxShadow: [
                        BoxShadow(color: Colors.blue.withOpacity(0.10), blurRadius: 16, offset: Offset(0, 4))
                      ],
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        child: Row(
                          children: [
                            if (_selectionMode && admin)
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                                onPressed: _clearSelection,
                            ),
                            if (!_selectionMode && currentPath.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                                onPressed: () {
                                  var path = currentPath.endsWith('/')
                                      ? currentPath.substring(0, currentPath.length - 1)
                                      : currentPath;
                                  final parts = path.split('/');
                                  if (parts.isNotEmpty) parts.removeLast();
                                  final parentPath =
                                      parts.isEmpty ? '' : parts.join('/') + '/';
                                  _loadFolder(parentPath);
                                },
                            ),
                            if (!_selectionMode && currentPath.isEmpty) const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                _selectionMode && admin
                                    ? '${_selectedItems.length} selected'
                                    : displayPath,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 24,
                                  letterSpacing: 1.1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_selectionMode && admin)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white, size: 28),
                                tooltip: 'Delete Selected',
                                onPressed: _selectedItems.isEmpty ? null : _deleteSelectedItems,
                            ),
                            if (!_selectionMode) ...[
                              // --- REMOVE: Direct Feedback and Logout buttons ---
                              // if (!admin) ...[
                              //   IconButton(
                              //     icon: const Icon(Icons.feedback_outlined,
                              //         color: Colors.white, size: 28),
                              //     onPressed: () async {
                              //       // ...existing code...
                              //     },
                              //   ),
                              //   IconButton(
                              //     icon: const Icon(Icons.logout,
                              //         color: Colors.white, size: 28),
                              //     onPressed: () => _logout(context),
                              //   ),
                              // ],
                              // --- Popup menu for everyone ---
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.white),
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                onSelected: (value) async {
                                  if (value == 'editors') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const EditorHandlingScreen(),
                                      ),
                                    );
                                  } else if (value == 'logs') {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const ViewLogsScreen(),
                                      ),
                                    );
                                  } else if (value == 'make_folder') {
                                    await _showCreateFolderDialog();
                                  } else if (value == 'upload') {
                                    await _uploadFile();
                                  } else if (value == 'feedback') {
                                    final user = FirebaseAuth.instance.currentUser;
                                    if (user == null || user.isAnonymous) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('You must be signed in to do this action'),
                                            backgroundColor: Colors.red,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                    showAdminFeedbackScreen(context);
                                  } else if (value == 'logout') {
                                    _logout(context);
                                  }
                                },
                                itemBuilder: (context) {
                                  final admin = adminSnapshot.data ?? false;
                                  return [
                                    if (admin)
                                      PopupMenuItem(
                                        value: 'editors',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.manage_accounts, color: Color(0xFF1976D2)),
                                            SizedBox(width: 10),
                                            Text('Manage Editors'),
                                          ],
                                        ),
                                      ),
                                    if (admin)
                                      PopupMenuItem(
                                        value: 'logs',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.list_alt, color: Color(0xFF1976D2)),
                                            SizedBox(width: 10),
                                            Text('View Logs'),
                                          ],
                                        ),
                                      ),
                                    if (admin)
                                      PopupMenuItem(
                                        value: 'make_folder',
                                        child: Row(
                                          children: const [
                                            Icon(Icons.create_new_folder, color: Color(0xFF1976D2)),
                                            SizedBox(width: 10),
                                            Text('Make Folder'),
                                          ],
                                        ),
                                      ),
                                    const PopupMenuDivider(),
                                    PopupMenuItem(
                                      value: 'upload',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.upload_file, color: Color(0xFF1976D2)),
                                          SizedBox(width: 10),
                                          Text('Upload'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'feedback',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.feedback_outlined, color: Color(0xFF1976D2)),
                                          SizedBox(width: 10),
                                          Text('Feedback'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'logout',
                                      child: Row(
                                        children: const [
                                          Icon(Icons.logout, color: Color(0xFF1976D2)),
                                          SizedBox(width: 10),
                                          Text('Logout'),
                                        ],
                                      ),
                                    ),
                                  ];
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            body: Stack(
              children: [
                AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 400),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFE3F2FD), Color(0xFFF7FAF9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
                      child: Column(
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Container(
                                color: Colors.white.withOpacity(0.10),
                                child: NotificationListener<OverscrollIndicatorNotification>(
                                  onNotification: (overscroll) {
                                    overscroll.disallowIndicator();
                                    return false;
                                  },
                                  child: RefreshIndicator(
                                    onRefresh: () async {
                                      await _loadFolder(currentPath);
                                    },
                                    child: GestureDetector(
                                      onVerticalDragEnd: (details) async {
                                        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
                                          await _loadFolder(currentPath);
                                        }
                                      },
                                      child: _buildList(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // --- Download progress bar at bottom ---
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  left: 0,
                  right: 0,
                  bottom: (_downloading || _downloadError != null || _downloadSavePath != null) ? 0 : -120,
                  child: Material(
                    elevation: 12,
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_downloading)
                            Column(
                              children: [
                                Text(
                                  'Downloading ${_downloadFileName ?? ''}...',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                                const SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: _downloadProgress,
                                  minHeight: 8,
                                  backgroundColor: Colors.blue.shade100,
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                const SizedBox(height: 8),
                                Text('${(_downloadProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 16)),
                              ],
                            ),
                          if (!_downloading && _downloadError != null)
                            Column(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 32),
                                const SizedBox(height: 10),
                                Text(_downloadError!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _downloadError = null;
                                      _downloadSavePath = null;
                                      _downloadFileName = null;
                                    });
                                  },
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          if (!_downloading && _downloadError == null && _downloadSavePath != null)
                            Column(
                              children: [
                                const Icon(Icons.check_circle, color: Colors.green, size: 32),
                                const SizedBox(height: 10),
                                Text('Downloaded to $_downloadSavePath', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _downloadSavePath = null;
                                      _downloadFileName = null;
                                    });
                                  },
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
