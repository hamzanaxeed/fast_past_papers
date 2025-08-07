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
import 'dart:async';

class PastPaperHomeScreen extends StatefulWidget {
  const PastPaperHomeScreen({Key? key}) : super(key: key);

  @override
  State<PastPaperHomeScreen> createState() => _PastPaperHomeScreenState();
}

class _PastPaperHomeScreenState extends State<PastPaperHomeScreen> {
  final ValueNotifier<String> _folderPath = ValueNotifier<String>('');
  final ValueNotifier<String?> _bucket = ValueNotifier<String?>('pastpapers');
  final ValueNotifier<String> _title = ValueNotifier<String>('Past Papers');
  final List<_FolderNavState> _navStack = [ _FolderNavState('', 'Past Papers', 'pastpapers') ];

  // --- Search state ---
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSearchLoading = false;
  List<dynamic> _searchResults = [];
  StreamController<FolderFile>? _searchStreamController;

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
    // Prevent duplicate navigation stack entries
    if (_navStack.isNotEmpty &&
        _navStack.last.folderPath == folderPath &&
        _navStack.last.bucket == (bucket ?? 'pastpapers')) {
      // Already at this folder, just update UI
      _folderPath.value = folderPath;
      _title.value = title;
      _bucket.value = bucket ?? 'pastpapers';
      return;
    }
    _navStack.add(_FolderNavState(folderPath, title, bucket ?? 'pastpapers'));
    _folderPath.value = folderPath;
    _title.value = title;
    _bucket.value = bucket ?? 'pastpapers';
  }

  Future<bool> _onWillPop() async {
    if (_navStack.length > 1) {
      _navStack.removeLast();
      final prev = _navStack.last;
      _folderPath.value = prev.folderPath;
      _title.value = prev.title;
      _bucket.value = prev.bucket;
      return false;
    }
    return true;
  }

  void _performSearch(String query) async {
    final provider = Provider.of<PastPaperProvider>(context, listen: false);
    _searchStreamController?.close();
    _searchStreamController = StreamController<FolderFile>();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _isSearchLoading = false;
        _searchResults = [];
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _isSearchLoading = true;
      _searchResults = [];
    });
    // Start streaming search
    provider.searchAllRealtimeStream(query, _searchStreamController!).then((_) {
      if (mounted) {
        setState(() {
          _isSearchLoading = false;
        });
      }
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchStreamController?.close();
    setState(() {
      _isSearching = false;
      _isSearchLoading = false;
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canCreateFolder(),
      builder: (context, snapshot) {
        final canCreateFolder = snapshot.data ?? false;
        return Stack(
          children: [
            // Gradient background for the whole screen
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            WillPopScope(
              onWillPop: _onWillPop,
              child: Scaffold(
                extendBodyBehindAppBar: true,
                backgroundColor: Colors.transparent,
                // Remove the AppBar here
                body: SafeArea(
                  child: Column(
                    children: [
                      // --- Navigation header (like timetable) ---
                      ValueListenableBuilder<String>(
                        valueListenable: _title,
                        builder: (context, title, _) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            child: Row(
                              children: [
                                if (_navStack.length > 1)
                                  IconButton(
                                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                                    onPressed: () async {
                                      await _onWillPop();
                                    },
                                  ),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(
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
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                // 3-dot menu
                                PopupMenuButton<String>(
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
                                    if (_folderPath.value.isNotEmpty)
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
                                    if (canCreateFolder && _folderPath.value.isNotEmpty)
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
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      // --- Search bar UI ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(18),
                          color: Colors.white,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search files or folders...',
                              prefixIcon: const Icon(Icons.search, color: Colors.deepPurple),
                              suffixIcon: _isSearching
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: Colors.deepPurple),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            ),
                            style: const TextStyle(fontSize: 16, color: Colors.deepPurple),
                            onChanged: _performSearch,
                          ),
                        ),
                      ),
                      // --- Search results or normal folder view ---
                      Expanded(
                        child: _isSearching
                            ? _buildSearchResults()
                            : _buildFolderContentsAsTiles(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- Widget to show folder contents as tiles (like timetable) ---
  Widget _buildFolderContentsAsTiles() {
    return ValueListenableBuilder<String>(
      valueListenable: _folderPath,
      builder: (context, folderPath, _) {
        return ValueListenableBuilder<String?>(
          valueListenable: _bucket,
          builder: (context, bucket, _) {
            final provider = Provider.of<PastPaperProvider>(context, listen: true);
            final items = provider.items;
            if (provider.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (provider.error != null) {
              return Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)));
            }
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.folder_open, color: Colors.white54, size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'This folder is empty.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: items.length,
              itemBuilder: (context, idx) {
                final item = items[idx];
                if (item.isFolder) {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: _cardDecoration(color: Colors.deepPurple.withOpacity(0.08)),
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
                      onTap: () => _navigateToFolder(item.fullPath, item.name, item.bucket),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      hoverColor: Colors.deepPurple.withOpacity(0.13),
                    ),
                  );
                } else {
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: _cardDecoration(),
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
                      onTap: () {
                        final fileUrl = buildFileUrl(item.bucket, item.fullPath);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherViewer(url: fileUrl, name: item.name),
                          ),
                        );
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      hoverColor: Colors.deepPurple.withOpacity(0.07),
                    ),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  // --- Widget to show search results ---
  Widget _buildSearchResults() {
    if (_searchStreamController == null) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<FolderFile>(
      stream: _searchStreamController!.stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _searchResults.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasData) {
          _searchResults.add(snapshot.data!);
        }
        if (_searchResults.isEmpty && !_isSearchLoading) {
          return const Center(
            child: Text(
              'No results found.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          );
        }

        // Use Provider to get admin status for long-press actions
        return FutureBuilder<bool>(
          future: _isAdmin(),
          builder: (context, adminSnapshot) {
            final isAdmin = adminSnapshot.data ?? false;
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final item = _searchResults[idx];
                return Container(
                  decoration: _cardDecoration(
                    color: item.isFolder
                        ? Colors.deepPurple.withOpacity(0.08)
                        : Colors.white,
                    selected: false,
                  ),
                  child: ListTile(
                    leading: Container(
                      decoration: BoxDecoration(
                        color: Colors.deepPurple.withOpacity(0.40),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        item.isFolder ? Icons.folder : Icons.insert_drive_file,
                        color: Colors.white,
                        size: item.isFolder ? 32 : 28,
                      ),
                    ),
                    title: Text(
                      item.name,
                      style: TextStyle(
                        fontWeight: item.isFolder ? FontWeight.bold : FontWeight.w600,
                        fontSize: item.isFolder ? 20 : 18,
                        color: item.isFolder ? Colors.white : Colors.deepPurple,
                        letterSpacing: 0.2,
                      ),
                    ),
                    subtitle: Text(
                      item.fullPath,
                      style: TextStyle(
                        color: item.isFolder ? Colors.white70 : Colors.deepPurple,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: item.isFolder
                        ? null
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
                    onTap: () {
                      if (item.isFolder) {
                        _clearSearch();
                        _navigateToFolder(item.fullPath, item.name, item.bucket);
                      } else {
                        final fileUrl = buildFileUrl(item.bucket, item.fullPath);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OtherViewer(url: fileUrl, name: item.name),
                          ),
                        );
                      }
                    },
                    onLongPress: isAdmin
                        ? () async {
                            // Use the same admin actions as navigation
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
                                        leading: const Icon(
                                            Icons.drive_file_rename_outline, color: Colors.deepPurple),
                                        title: const Text('Rename'),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          String? newName;
                                          if (item.isFolder) {
                                            newName = await promptForFolderName(context);
                                            if (newName == null || newName.trim().isEmpty) return;
                                            if (!newName.endsWith('_folder')) {
                                              newName = '${newName}_folder';
                                            }
                                          } else {
                                            newName = await promptForFileName(context, item.name);
                                            if (newName == null || newName.trim().isEmpty) return;
                                          }
                                          await renameItem(
                                              context: context, item: item, newName: newName);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.delete, color: Colors.red),
                                        title: const Text('Delete'),
                                        onTap: () async {
                                          Navigator.pop(ctx);
                                          // Use the same delete logic as navigation
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx2) => AlertDialog(
                                              title: const Text('Delete'),
                                              content: Text('Are you sure you want to delete "${item.name}"?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx2, false),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () => Navigator.pop(ctx2, true),
                                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            // Use the same delete logic as navigation
                                            try {
                                              final bucket = item.bucket;
                                              final client = Supabase.instance.client;
                                              if (item.isFolder) {
                                                final List<dynamic> allItems = await client.storage.from(bucket).list(
                                                    path: item.fullPath);
                                                for (final subItem in allItems) {
                                                  final subPath = '${item.fullPath}/${subItem.name}';
                                                  final isSubFolder = subItem.name.endsWith('_folder');
                                                  if (isSubFolder) {
                                                    await client.storage.from(bucket).remove([subPath]);
                                                  } else {
                                                    await client.storage.from(bucket).remove([subPath]);
                                                  }
                                                }
                                                await client.storage.from(bucket).remove([item.fullPath]);
                                              } else {
                                                await client.storage.from(bucket).remove([item.fullPath]);
                                              }
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Deleted "${item.name}"'), backgroundColor: Colors.green),
                                              );
                                              // Remove from search results
                                              setState(() {
                                                _searchResults.removeAt(idx);
                                              });
                                            } catch (e) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          }
                        : null,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    hoverColor: Colors.deepPurple.withOpacity(0.07),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _searchStreamController?.close();
    super.dispose();
  }

  // --- Widget to show folder contents ---
  Widget _buildFolderContents() {
    return ValueListenableBuilder<String>(
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
    );
  }

  // Add this method to match navigation UI card style
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
      fetchFolderUI(context, widget.folderPath, widget.bucket ?? 'pastpapers',
          force: true);
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

  // Copied from parent for upload permission
  Future<bool> _canUpload() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return false;
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider = Provider.of<PastPaperProvider>(context, listen: false);
  }

  @override
  void didUpdateWidget(covariant FolderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.folderPath != oldWidget.folderPath ||
        widget.bucket != oldWidget.bucket) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchFolderUI(context, widget.folderPath, widget.bucket ?? 'pastpapers',
            force: true);
      });
    }
  }

  void fetchFolderUI(BuildContext context, String folderPath, String? bucket,
      {bool force = false}) {
    fetchFolder(
      context: context,
      folderPath: folderPath,
      bucket: bucket ?? 'pastpapers',
      force: force,
    );
    _lastLoadedPath = folderPath;
    _lastLoadedBucket = bucket ?? 'pastpapers';
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
                leading: const Icon(
                    Icons.drive_file_rename_outline, color: Colors.deepPurple),
                title: const Text('Rename'),
                onTap: () async {
                  Navigator.pop(ctx);
                  String? newName;
                  if (item.isFolder) {
                    newName = await promptForFolderName(context);
                    if (newName == null || newName.trim().isEmpty) return;
                    if (!newName.endsWith('_folder')) {
                      newName = '${newName}_folder';
                    }
                  } else {
                    newName = await promptForFileName(context, item.name);
                    if (newName == null || newName.trim().isEmpty) return;
                  }
                  await renameItem(
                      context: context, item: item, newName: newName);
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
      if (!newName.endsWith('_folder')) {
        newName = '${newName}_folder';
      }
    } else {
      newName = await promptForFileName(context, item.name);
      if (newName == null || newName.trim().isEmpty) return;
    }
    await renameItem(context: context, item: item, newName: newName);
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
    final itemsToDelete = _selectedIndexes
        .map((idx) => provider.items[idx])
        .toList();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text('Delete Selected'),
            content: Text('Are you sure you want to delete ${itemsToDelete
                .length} item(s)?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                      'Delete', style: TextStyle(color: Colors.red))),
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
      final client = Supabase.instance.client;

      if (item.isFolder) {
        final List<dynamic> allItems = await client.storage.from(bucket).list(
            path: item.fullPath);
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
          provider.fetchFolderContents(
              provider.currentBucket, provider.currentPath, force: true);
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMsg;
        if (e.toString().contains('SocketException') ||
            e.toString().toLowerCase().contains('network')) {
          errorMsg =
          'Network error: Please check your internet connection and try again.';
        } else {
          errorMsg =
          'Delete failed: ${e.toString().replaceAll('Exception: ', '')}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    }
  }

  // Copied from parent for card decoration
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
    super.build(context); // <-- Required by AutomaticKeepAliveClientMixin, ignore return value
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            // --- Folder title and back button ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (widget.folderPath.isEmpty) {
                        Navigator.of(context).pop();
                      } else {
                        _fetchParentFolder();
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
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
                  ),
                  // --- Upload and Create Folder buttons (Admin only) ---
                  if (_isAdmin && widget.folderPath.isNotEmpty)
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.upload_file, color: Colors.white),
                          onPressed: () async {
                            final canUpload = await _canUpload();
                            if (!canUpload) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Only logged-in user can upload files.'), backgroundColor: Colors.red),
                              );
                              return;
                            }
                            showUploadFileDialog(
                              context: context,
                              folderPath: widget.folderPath,
                              bucket: widget.bucket ?? 'pastpapers',
                              onUploaded: () {
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.create_new_folder, color: Colors.white),
                          onPressed: () async {
                            await createFolder(
                              context: context,
                              folderPath: widget.folderPath,
                              bucket: widget.bucket ?? 'pastpapers',
                              onCreated: () {
                                if (mounted) setState(() {});
                              },
                            );
                          },
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Divider(color: Colors.white24, thickness: 0.5),
            // --- Folder contents or empty state ---
            Expanded(
              child: _provider == null
                  ? const SizedBox.shrink()
                  : Builder(
                      builder: (context) {
                        final items = _provider!.items;
                        if (items.isEmpty) {
                          return _buildEmptyState();
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 1.2,
                          ),
                          itemCount: items.length,
                          itemBuilder: (context, idx) {
                            final item = items[idx];
                            return GestureDetector(
                              onTap: () => _onTapItem(idx, _provider!, item),
                              onLongPress: _isAdmin
                                  ? () {
                                      setState(() {
                                        _selectionMode = true;
                                        _selectedIndexes.add(idx);
                                      });
                                    }
                                  : null,
                              child: Container(
                                decoration: _cardDecoration(
                                  color: item.isFolder
                                      ? Colors.deepPurple.withOpacity(0.08)
                                      : Colors.white,
                                  selected: _selectionMode && _selectedIndexes.contains(idx),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.withOpacity(0.40),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        item.isFolder ? Icons.folder : Icons.insert_drive_file,
                                        color: Colors.white,
                                        size: item.isFolder ? 32 : 28,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.name,
                                      style: TextStyle(
                                        fontWeight: item.isFolder ? FontWeight.bold : FontWeight.w600,
                                        fontSize: item.isFolder ? 18 : 16,
                                        color: item.isFolder ? Colors.white : Colors.deepPurple,
                                        letterSpacing: 0.2,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            // --- Selection actions (Admin only) ---
            if (_selectionMode && _isAdmin)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      '${_selectedIndexes.length} item(s) selected',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () {
                        // Delete selected items
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Selected'),
                            content: Text('Are you sure you want to delete ${_selectedIndexes.length} item(s)?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(ctx);
                                  await _deleteSelected(_provider!);
                                },
                                child: const Text('Delete', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Delete Selected', style: TextStyle(color: Colors.red)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        backgroundColor: Colors.red.withOpacity(0.08),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  // --- Widget for empty state ---
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.folder_open,
            color: Colors.white54,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'This folder is empty.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () async {
              await createFolder(
                context: context,
                folderPath: widget.folderPath,
                bucket: widget.bucket ?? 'pastpapers',
                onCreated: () {
                  if (mounted) setState(() {});
                },
              );
            },
            icon: const Icon(Icons.create_new_folder, color: Colors.white),
            label: const Text('Create a new folder', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              backgroundColor: Colors.deepPurple,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}
