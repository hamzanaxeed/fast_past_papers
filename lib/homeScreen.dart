import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'getfiles.dart';
import 'other_Viewers.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'feedback.dart';
import 'log.dart';
import 'message_File.dart';
import 'options_Screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentications.dart';
import 'view_Logs.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class PastPaperHomeScreen extends StatefulWidget {
  const PastPaperHomeScreen({Key? key}) : super(key: key);

  @override
  State<PastPaperHomeScreen> createState() => _PastPaperHomeScreenState();
}

class _PastPaperHomeScreenState extends State<PastPaperHomeScreen> {
  final ValueNotifier<String> _folderPath = ValueNotifier<String>('');
  final ValueNotifier<String?> _bucket = ValueNotifier<String?>(null);
  final ValueNotifier<String> _title = ValueNotifier<String>('Past Papers');
  final List<_FolderNavState> _navStack = [ _FolderNavState('', 'Past Papers', null) ];

  final TextEditingController _searchController = TextEditingController();
  List<FolderFile> _searchResults = [];
  bool _isSearching = false;

  Future<bool> _isAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    final response = await Supabase.instance.client
        .from('Admins')
        .select('admin_Email')
        .eq('admin_Email', user.email!.toLowerCase())
        .maybeSingle();
    return response != null;
  }

  Future<bool> _canUpload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
    // Check admin or editor
    final email = user.email?.toLowerCase();
    if (email == null) return false;
    final admin = await Supabase.instance.client
        .from('Admins')
        .select('admin_Email')
        .eq('admin_Email', email)
        .maybeSingle();
    if (admin != null) return true;
    final editor = await Supabase.instance.client
        .from('Editors')
        .select('editor_Email')
        .eq('editor_Email', email)
        .maybeSingle();
    return editor != null;
  }

  Future<bool> _canCreateFolder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;
    final email = user.email!.toLowerCase();
    final admin = await Supabase.instance.client
        .from('Admins')
        .select('admin_Email')
        .eq('admin_Email', email)
        .maybeSingle();
    if (admin != null) return true;
    final editor = await Supabase.instance.client
        .from('Editors')
        .select('editor_Email')
        .eq('editor_Email', email)
        .maybeSingle();
    return editor != null;
  }

  void _handleMenu(BuildContext context, String value, bool canCreateFolder) async {
    if (value == 'feedback') {
      if (canCreateFolder) {
        showAdminFeedbackScreen(context);
      } else {
        showFeedbackDialog(context);
      }
    } else if (value == 'log' && canCreateFolder) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewLogsScreen()));
    } else if (value == 'message' && canCreateFolder) {
      showManageMessagesDialog(context);
    } else if (value == 'upload_file') {
      final canUpload = await _canUpload();
      if (!canUpload) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Only logged-in user can upload files.'), backgroundColor: Colors.red),
        );
        return;
      }
      showUploadFileDialog(
        context: context,
        folderPath: _folderPath.value,
        bucket: _bucket.value ?? 'pastpapers',
        onUploaded: () {
          if (mounted) setState(() {});
        },
      );
    } else if (value == 'create_folder' && canCreateFolder) {
      await createFolder(
        context: context,
        folderPath: _folderPath.value,
        bucket: _bucket.value ?? 'pastpapers',
        onCreated: () {
          if (mounted) setState(() {});
        },
      );
    } else if (value == 'logout') {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
        (route) => false,
      );
    }
  }

  void _navigateToFolder(String folderPath, String title, String? bucket) {
    _navStack.add(_FolderNavState(folderPath, title, bucket));
    _folderPath.value = folderPath;
    _title.value = title;
    _bucket.value = bucket;
  }

  Future<bool> _onWillPop() async {
    if (_navStack.length > 1) {
      _navStack.removeLast();
      final prev = _navStack.last;
      _folderPath.value = prev.folderPath;
      _title.value = prev.title;
      _bucket.value = prev.bucket;
      return false; // Don't pop the route, just update folder
    }
    return true; // At root, allow pop to OptionsScreen
  }

  void _performSearch(String query) {
    final provider = Provider.of<PastPaperProvider>(context, listen: false);
    final List<FolderFile> allItems = [];
    for (final bucket in provider.cache.values) {
      for (final folderItems in bucket.values) {
        allItems.addAll(folderItems);
      }
    }
    setState(() {
      _searchResults = allItems
          .where((item) => item.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
      _isSearching = query.isNotEmpty;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults.clear();
      _isSearching = false;
    });
  }

  void _navigateToSearchedItem(FolderFile item) {
    if (item.isFolder) {
      _navStack.add(_FolderNavState(item.fullPath, item.name, item.bucket));
      _folderPath.value = item.fullPath;
      _title.value = item.name;
      _bucket.value = item.bucket;
      _clearSearch();
    } else {
      final fileUrl = buildFileUrl(item.bucket, item.fullPath);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtherViewer(url: fileUrl, name: item.name),
        ),
      );
      _clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canCreateFolder(),
      builder: (context, snapshot) {
        final canCreateFolder = snapshot.data ?? false;
        return WillPopScope(
          onWillPop: _onWillPop,
          child: Scaffold(
            extendBodyBehindAppBar: false,
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text(
                'Past Papers',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
              ),
              centerTitle: true,
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              elevation: 4,
              actions: [
                ValueListenableBuilder<String>(
                  valueListenable: _folderPath,
                  builder: (context, folderPath, _) {
                    return PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (value) => _handleMenu(context, value, canCreateFolder),
                      itemBuilder: (context) => [
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
                        if (canCreateFolder)
                          PopupMenuItem(
                            value: 'log',
                            child: Row(
                              children: const [
                                Icon(Icons.list_alt, color: Color(0xFF1976D2)),
                                SizedBox(width: 10),
                                Text('View Logs'),
                              ],
                            ),
                          ),
                        if (canCreateFolder)
                          PopupMenuItem(
                            value: 'message',
                            child: Row(
                              children: const [
                                Icon(Icons.message, color: Color(0xFF1976D2)),
                                SizedBox(width: 10),
                                Text('Manage Messages'),
                              ],
                            ),
                          ),
                        if (folderPath.isNotEmpty)
                          PopupMenuItem(
                            value: 'upload_file',
                            child: Row(
                              children: const [
                                Icon(Icons.upload_file, color: Color(0xFF1976D2)),
                                SizedBox(width: 10),
                                Text('Upload File'),
                              ],
                            ),
                          ),
                        // Remove the upload_folder button here
                        // Show "Create Folder" for admins and editors (canCreateFolder) and not at root
                        if (canCreateFolder && folderPath.isNotEmpty)
                          PopupMenuItem(
                            value: 'create_folder',
                            child: Row(
                              children: const [
                                Icon(Icons.create_new_folder, color: Colors.deepPurple),
                                SizedBox(width: 10),
                                Text('Create Folder'),
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
                      ],
                    );
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // Gradient background for search bar area
                Container(
                  width: double.infinity,
                  color: Colors.deepPurple,

                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search files or folders...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _isSearching
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: _performSearch,
                    ),
                  ),
                ),
                Expanded(
                  child: _isSearching
                      ? Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Consumer<PastPaperProvider>(
                            builder: (context, provider, _) {
                              if (_searchResults.isEmpty) {
                                return const Center(
                                  child: Text('No results found.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                                );
                              }
                              return ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                                itemCount: _searchResults.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, idx) {
                                  final item = _searchResults[idx];
                                  final selected = false;
                                  // Use the same tile UI as normal navigation
                                  if (item.isFolder) {
                                    return FutureBuilder<int>(
                                      future: getFolderItemCount(context, item),
                                      builder: (context, snapshot) {
                                        final count = snapshot.hasData ? snapshot.data! : null;
                                        return Container(
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple.withOpacity(0.08),
                                            borderRadius: BorderRadius.circular(18),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.deepPurple.withOpacity(0.10),
                                                blurRadius: 14,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                            border: Border.all(
                                              color: Colors.deepPurple.withOpacity(0.08),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: ListTile(
                                            leading: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.deepPurple.withOpacity(0.40),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              child: const Icon(Icons.folder, color: Colors.white, size: 32),
                                            ),
                                            title: Text(
                                              item.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                                color: Colors.white,
                                                letterSpacing: 0.2,
                                              ),
                                            ),
                                            trailing: (count != null
                                                ? AnimatedContainer(
                                                    duration: const Duration(milliseconds: 250),
                                                    curve: Curves.easeOut,
                                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [Colors.blue.shade200, Colors.blue.shade400],
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                      ),
                                                      borderRadius: BorderRadius.circular(16),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.blue.withOpacity(0.18),
                                                          blurRadius: 8,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '$count',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                : const SizedBox(
                                                    width: 29,
                                                    height: 28,
                                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                                                  )),
                                            onTap: () => _navigateToSearchedItem(item),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                            hoverColor: Colors.deepPurple.withOpacity(0.13),
                                          ),
                                        );
                                      },
                                    );
                                  } else {
                                    return Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.deepPurple.withOpacity(0.10),
                                            blurRadius: 14,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.deepPurple.withOpacity(0.08),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        leading: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.deepPurple.withOpacity(0.40),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.all(6),
                                          child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
                                        ),
                                        title: Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 18,
                                            color: Colors.deepPurple,
                                          ),
                                        ),
                                        trailing: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(24),
                                            onTap: () => downloadFile(context, item),
                                            child: Tooltip(
                                              message: 'Download',
                                              child: Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(24),
                                                ),
                                                child: const Icon(
                                                  Icons.download_for_offline_rounded,
                                                  color: Colors.green,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        onTap: () => _navigateToSearchedItem(item),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        hoverColor: Colors.deepPurple.withOpacity(0.07),
                                      ),
                                    );
                                  }
                                },
                              );
                            },
                          ),
                        )
                      : ValueListenableBuilder<String>(
                          valueListenable: _folderPath,
                          builder: (context, folderPath, _) {
                            return ValueListenableBuilder<String?>(
                              valueListenable: _bucket,
                              builder: (context, bucket, _) {
                                return ValueListenableBuilder<String>(
                                  valueListenable: _title,
                                  builder: (context, title, _) {
                                    return FolderScreen(
                                      folderPath: folderPath,
                                      title: title,
                                      bucket: bucket,
                                      onFolderTap: (newPath, newTitle, newBucket) {
                                        _navigateToFolder(newPath, newTitle, newBucket);
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
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

// Helper class for navigation stack
class _FolderNavState {
  final String folderPath;
  final String title;
  final String? bucket;
  _FolderNavState(this.folderPath, this.title, this.bucket);
}

// Update FolderScreen to accept onFolderTap callback
class FolderScreen extends StatefulWidget {
  final String folderPath;
  final String title;
  final String? bucket;
  final void Function(String folderPath, String title, String? bucket)? onFolderTap;

  const FolderScreen({
    Key? key,
    required this.folderPath,
    required this.title,
    this.bucket,
    this.onFolderTap,
  }) : super(key: key);

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> with AutomaticKeepAliveClientMixin {
  String? _lastLoadedPath;
  String? _lastLoadedBucket;
  PastPaperProvider? _provider;

  // --- Multi-select and delete state ---
  bool _selectionMode = false;
  Set<int> _selectedIndexes = {};
  bool _isAdmin = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchFolderUI(context, widget.folderPath, widget.bucket, force: true);
      _checkAdmin();
    });
  }

  Future<void> _checkAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return;
    final response = await Supabase.instance.client
        .from('Admins')
        .select('admin_Email')
        .eq('admin_Email', user.email!.toLowerCase())
        .maybeSingle();
    setState(() {
      _isAdmin = response != null;
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<PastPaperProvider>(context, listen: false);
  }

  @override
  void didUpdateWidget(covariant FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.folderPath != oldWidget.folderPath || widget.bucket != oldWidget.bucket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchFolderUI(context, widget.folderPath, widget.bucket, force: true);
      });
    }
  }

  void fetchFolderUI(BuildContext context, String folderPath, String? bucket, {bool force = false}) {
    fetchFolder(
      context: context,
      folderPath: folderPath,
      bucket: bucket,
      force: force,
    );
    _lastLoadedPath = folderPath;
    _lastLoadedBucket = bucket;
  }

  void _fetchParentFolder() {
    String parentPath;
    if (widget.folderPath.isEmpty) {
      parentPath = '';
    } else {
      final parts = widget.folderPath.split('/');
      if (parts.isNotEmpty) parts.removeLast();
      parentPath = parts.isEmpty ? '' : parts.join('/');
    }
    fetchFolderUI(context, parentPath, widget.bucket, force: true);
  }

  void _onLongPressItem(int idx) async {
    if (!_isAdmin) return;
    final provider = Provider.of<PastPaperProvider>(context, listen: false);
    final item = provider.items[idx];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline, color: Colors.deepPurple),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(ctx);
                  String? newName;
                  if (item.isFolder) {
                    newName = await promptForFolderName(context);
                    if (newName == null || newName.trim().isEmpty) return;
                    newName = '${newName}_folder';
                  } else {
                    newName = await promptForFileName(context, item.name);
                    if (newName == null || newName.trim().isEmpty) return;
                  }
                  await renameItem(context: context, item: item, newName: newName);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _selectionMode = true;
                    _selectedIndexes.add(idx);
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }


  Future<void> _renameItem(dynamic item) async {
    final provider = Provider.of<PastPaperProvider>(context, listen: false);
    String? newName;
    if (item.isFolder) {
      newName = await promptForFolderName(context);
      if (newName == null || newName.trim().isEmpty) return;
      newName = '${newName}_folder';
    } else {
      newName = await promptForFileName(context, item.name);
      if (newName == null || newName.trim().isEmpty) return;
    }
    final bucket = item.bucket;
    final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
    final parentPath = item.fullPath.contains('/') ? item.fullPath.substring(0, item.fullPath.lastIndexOf('/')) : '';
    final newFullPath = parentPath.isEmpty ? newName : '$parentPath/$newName';

    try {
      if (item.isFolder) {
        // Copy all contents to new folder, then delete old folder
        final contents = await client.storage.from(bucket).list(path: item.fullPath);
        for (final subItem in contents) {
          final oldSubPath = '${item.fullPath}/${subItem.name}';
          final newSubPath = '$newFullPath/${subItem.name}';
          final fileBytes = await client.storage.from(bucket).download(oldSubPath);
          await client.storage.from(bucket).upload(newSubPath, File.fromRawPath(fileBytes), fileOptions: const FileOptions(upsert: true));
        }
        // Create empty folder file for new folder
        final tempDir = Directory.systemTemp;
        final tempFile = await File('${tempDir.path}/empty_folder_placeholder').create();
        await tempFile.writeAsBytes([]);
        await client.storage.from(bucket).upload(
          newFullPath,
          tempFile,
          fileOptions: const FileOptions(upsert: false, contentType: 'application/x-empty'),
        );
        await tempFile.delete();
        // Delete old folder and its contents
        for (final subItem in contents) {
          await client.storage.from(bucket).remove(['${item.fullPath}/${subItem.name}']);
        }
        await client.storage.from(bucket).remove([item.fullPath]);
      } else {
        // File: copy to new name, delete old
        final fileBytes = await client.storage.from(bucket).download(item.fullPath);
        await client.storage.from(bucket).upload(newFullPath, File.fromRawPath(fileBytes), fileOptions: const FileOptions(upsert: true));
        await client.storage.from(bucket).remove([item.fullPath]);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Renamed successfully!'), backgroundColor: Colors.green),
      );
      fetchFolderUI(context, widget.folderPath, widget.bucket, force: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rename failed: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  void _onTapItem(int idx, PastPaperProvider provider, dynamic item) {
    if (_selectionMode) {
      setState(() {
        if (_selectedIndexes.contains(idx)) {
          _selectedIndexes.remove(idx);
          if (_selectedIndexes.isEmpty) _selectionMode = false;
        } else {
          _selectedIndexes.add(idx);
        }
      });
    } else {
      if (item.isFolder) {
        if (widget.onFolderTap != null) {
          widget.onFolderTap!(
            item.fullPath,
            item.name,
            item.bucket,
          );
        }
      } else {
        final fileUrl = buildFileUrl(item.bucket, item.fullPath);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherViewer(url: fileUrl, name: item.name),
          ),
        );
      }
    }
  }

  void _clearSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIndexes.clear();
    });
  }

  Future<void> _deleteSelected(PastPaperProvider provider) async {
    final itemsToDelete = _selectedIndexes.map((idx) => provider.items[idx]).toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Selected'),
        content: Text('Are you sure you want to delete ${itemsToDelete.length} item(s)?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      for (final item in itemsToDelete) {
        await _deleteItem(item);
      }
      _clearSelection();
      fetchFolderUI(context, widget.folderPath, widget.bucket, force: true);
    }
  }

  Future<void> _deleteItem(dynamic item) async {
    try {
      final bucket = item.bucket;
      final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;

      if (item.isFolder) {
        final List<dynamic> allItems = await client.storage.from(bucket).list(path: item.fullPath);
        for (final subItem in allItems) {
          final subPath = '${item.fullPath}/${subItem.name}';
          final isSubFolder = subItem.name.endsWith('_folder');
          if (isSubFolder) {
            await _deleteItem(
              FolderFile(
                name: subItem.name,
                isFolder: true,
                bucket: bucket,
                fullPath: subPath,
              ),
            );
          } else {
            await client.storage.from(bucket).remove([subPath]);
          }
        }
        await client.storage.from(bucket).remove([item.fullPath]);
      } else {
        await client.storage.from(bucket).remove([item.fullPath]);
      }
      // Refresh after deletion with force
      if (mounted) {
        final provider = Provider.of<PastPaperProvider>(context, listen: false);
        if (provider.currentPath.isEmpty) {
          provider.fetchRootFoldersAndFiles(force: true);
        } else {
          provider.fetchFolderContents(provider.currentBucket, provider.currentPath, force: true);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg;
        if (e.toString().contains('SocketException') ||
            e.toString().toLowerCase().contains('network')) {
          errorMsg = 'Network error: Please check your internet connection and try again.';
        } else {
          errorMsg = 'Delete failed: ${e.toString().replaceAll('Exception: ', '')}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  BoxDecoration _cardDecoration({Color? color, bool selected = false}) => BoxDecoration(
    color: selected
        ? Colors.red.withOpacity(0.18)
        : (color ?? Colors.white),
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.deepPurple.withOpacity(0.10),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
    border: Border.all(
      color: selected
          ? Colors.red.withOpacity(0.35)
          : Colors.deepPurple.withOpacity(0.08),
      width: 1.5,
    ),
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: _selectionMode
          ? AppBar(
              backgroundColor: Colors.deepPurple,
              title: Text('${_selectedIndexes.length} selected'),
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              actions: [
                if (_selectedIndexes.length > 0)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: () {
                      final provider = Provider.of<PastPaperProvider>(context, listen: false);
                      _deleteSelected(provider);
                    },
                  ),
              ],
            )
          : null,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Consumer<PastPaperProvider>(
          builder: (context, provider, _) {
            if (provider.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(
                child: Text(
                  provider.error!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              );
            }
            if (provider.items.isEmpty) {
              return const Center(
                child: Text(
                  'No folders/files found.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              );
            }
            return Material(
              color: Colors.transparent,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                itemCount: provider.items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, idx) {
                  final item = provider.items[idx];
                  final selected = _selectedIndexes.contains(idx);
                  if (item.isFolder) {
                    return FutureBuilder<int>(
                      future: getFolderItemCount(context, item),
                      builder: (context, snapshot) {
                        final count = snapshot.hasData ? snapshot.data! : null;
                        return Container(
                          decoration: _cardDecoration(
                            color: Colors.deepPurple.withOpacity(0.08),
                            selected: selected,
                          ),
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                color: Colors.deepPurple.withOpacity(0.40),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.folder, color: Colors.white, size: 32),
                            ),
                            title: Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                            trailing: _selectionMode
                                ? Checkbox(
                                    value: selected,
                                    onChanged: (val) {
                                      _onTapItem(idx, provider, item);
                                    },
                                  )
                                : (count != null
                                    ? AnimatedContainer(
                                        duration: const Duration(milliseconds: 250),
                                        curve: Curves.easeOut,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [Colors.blue.shade200, Colors.blue.shade400],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.blue.withOpacity(0.18),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$count',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox(
                                        width: 29,
                                        height: 28,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
                                      )),
                            onTap: () => _onTapItem(idx, provider, item),
                            onLongPress: () => _onLongPressItem(idx),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            hoverColor: Colors.deepPurple.withOpacity(0.13),
                          ),
                        );
                      },
                    );
                  } else {
                    return Container(
                      decoration: _cardDecoration(selected: selected),
                      child: ListTile(
                        leading: Container(
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.withOpacity(0.40),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                            color: Colors.deepPurple,
                          ),
                        ),
                        trailing: _selectionMode
                            ? Checkbox(
                                value: selected,
                                onChanged: (val) {
                                  _onTapItem(idx, provider, item);
                                },
                              )
                            : Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(24),
                                  onTap: () => downloadFile(context, item),
                                  child: Tooltip(
                                    message: 'Download',
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: const Icon(
                                        Icons.download_for_offline_rounded,
                                        color: Colors.green,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                        onTap: () => _onTapItem(idx, provider, item),
                        onLongPress: () => _onLongPressItem(idx),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        hoverColor: Colors.deepPurple.withOpacity(0.07),
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
