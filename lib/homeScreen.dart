import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'getfiles.dart';
import 'other_Viewers.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import 'feedback.dart';
import 'log.dart'; // <-- Add this import
import 'message_File.dart';
import 'options_Screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'authentications.dart';
import 'view_Logs.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import 'editor_Handling.dart';
import 'package:fast_past_papers/contact_Us.dart';

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

  // Selection mode state
  bool _selectionMode = false;
  Set<String> _selectedItems = {};

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
    // Allow any logged-in user to upload files
    return true;
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
        .select('Editor_Email')
        .eq('Editor_Email', email)
        .maybeSingle();
    return editor != null;
  }

  Future<bool> _canEdit() async {
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
        .select('Editor_Email')
        .eq('Editor_Email', email)
        .maybeSingle();
    return editor != null;
  }

  void _handleMenu(BuildContext context, String value, bool canCreateFolder, bool isAdmin) async {
    if (value == 'editors') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const EditorHandlingScreen()),
      );
      return;
    }
    if (value == 'feedback') {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only loged in users can send feedback'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (isAdmin) {
        showAdminFeedbackScreen(context);
      } else {
        showFeedbackDialog(context);
      }
    } else if (value == 'log' && isAdmin) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ViewLogsScreen()));
    } else if (value == 'message' && isAdmin) {
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
      // Fetch folder contents
      fetchFolder(
        context: context,
        folderPath: folderPath,
        bucket: bucket ?? 'pastpapers',
        force: true,
      );
      return;
    }
    _navStack.add(_FolderNavState(folderPath, title, bucket ?? 'pastpapers'));
    _folderPath.value = folderPath;
    _title.value = title;
    _bucket.value = bucket ?? 'pastpapers';
    // Fetch folder contents
    fetchFolder(
      context: context,
      folderPath: folderPath,
      bucket: bucket ?? 'pastpapers',
      force: true,
    );
  }

  Future<bool> _onWillPop() async {
    if (_navStack.length > 1) {
      _navStack.removeLast();
      final prev = _navStack.last;
      _folderPath.value = prev.folderPath;
      _title.value = prev.title;
      _bucket.value = prev.bucket;
      // Fetch previous folder contents
      fetchFolder(
        context: context,
        folderPath: prev.folderPath,
        bucket: prev.bucket,
        force: true,
      );
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
      future: _canEdit(),
      builder: (context, snapshot) {
        final canEdit = snapshot.data ?? false;
        return FutureBuilder<bool>(
          future: _isAdmin(),
          builder: (context, adminSnapshot) {
            final isAdmin = adminSnapshot.data ?? false;
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
                  onWillPop: () async {
                    if (_selectionMode) {
                      setState(() {
                        _selectionMode = false;
                        _selectedItems.clear();
                      });
                      return false;
                    }
                    return await _onWillPop();
                  },
                  child: Scaffold(
                    extendBodyBehindAppBar: true,
                    backgroundColor: Colors.transparent,
                    appBar: AppBar(
                      backgroundColor: Colors.deepPurple,
                      elevation: 0,
                      title: ValueListenableBuilder<String>(
                        valueListenable: _title,
                        builder: (context, title, _) => Text(
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
                      leading: IconButton(
                        icon: Icon(
                          (_navStack.length == 1) ? Icons.arrow_back : Icons.arrow_back_ios,
                          color: Colors.white,
                        ),
                        onPressed: () async {
                          if (_selectionMode) {
                            setState(() {
                              _selectionMode = false;
                              _selectedItems.clear();
                            });
                          } else if (_navStack.length == 1) {
                            Navigator.of(context).pop();
                          } else {
                            await _onWillPop();
                          }
                        },
                      ),
                      actions: [

                        if (!_selectionMode)
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            onSelected: (value) {
                              if (value == 'about_us') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ContactUsScreen()),
                                );
                              } else {
                                _handleMenu(context, value, canEdit, isAdmin);
                              }
                            },
                            itemBuilder: (context) => [
                              if (isAdmin)
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
                              if (isAdmin)
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
                              if (isAdmin)
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
                              if (canEdit && _folderPath.value.isNotEmpty)
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
                              PopupMenuItem(
                                value: 'about_us',
                                child: Row(
                                  children: const [
                                    Icon(Icons.contact_mail, color: Color(0xFF1976D2)),
                                    SizedBox(width: 10),
                                    Text('About Us'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        if (_selectionMode)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.white),
                            tooltip: 'Delete Selected',
                            onPressed: _selectedItems.isEmpty
                                ? null
                                : () async {
                                    final provider = Provider.of<PastPaperProvider>(context, listen: false);
                                    final items = provider.items.where((item) => _selectedItems.contains(item.fullPath)).toList();
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx2) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        backgroundColor: Colors.white,
                                        title: Row(
                                          children: const [
                                            Icon(Icons.delete, color: Colors.red, size: 28),
                                            SizedBox(width: 10),
                                            Text('Delete Selected', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                        content: Text(
                                          'Are you sure you want to delete ${items.length} selected item(s)?',
                                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                                        ),
                                        actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        actions: [
                                          OutlinedButton(
                                            onPressed: () => Navigator.pop(ctx2, false),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.deepPurple,
                                              side: const BorderSide(color: Colors.deepPurple),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            onPressed: () => Navigator.pop(ctx2, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      final client = Supabase.instance.client;
                                      for (final item in items) {
                                        try {
                                          if (item.isFolder) {
                                            await _deleteFolderRecursive(client, item.bucket, item.fullPath);
                                            // --- Add edit log ---
                                            await logEditEvent('Deleted folder "${item.fullPath}" in bucket "${item.bucket}"');
                                          } else {
                                            await client.storage.from(item.bucket).remove([item.fullPath]);
                                            // --- Add edit log ---
                                            await logEditEvent('Deleted file "${item.fullPath}" in bucket "${item.bucket}"');
                                          }
                                        } catch (_) {}
                                      }
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Deleted ${items.length} item(s)!'), backgroundColor: Colors.green),
                                      );
                                      setState(() {
                                        _selectionMode = false;
                                        _selectedItems.clear();
                                      });
                                      refreshCurrentFolder(context);
                                    }
                                  },
                          ),
                      ],
                    ),
                    body: SafeArea(
                      child: Column(
                        children: [
                          // --- Search bar UI ---
                          Padding(
                            padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
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
            return FutureBuilder<bool>(
              future: _canEdit(), // <-- Use _canEdit for permissions
              builder: (context, adminSnapshot) {
                final canEdit = adminSnapshot.data ?? false;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final item = items[idx];
                    final isFolder = item.isFolder;
                    final selected = _selectedItems.contains(item.fullPath);
                    return GestureDetector(
                      onLongPress: canEdit // <-- Allow both admin/editor
                          ? () async {
                              if (_selectionMode) return;
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
                                          leading: const Icon(Icons.select_all, color: Colors.deepPurple),
                                          title: const Text('Select More'),
                                          onTap: () {
                                            Navigator.pop(ctx);
                                            setState(() {
                                              _selectionMode = true;
                                              _selectedItems = {item.fullPath};
                                            });
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.delete, color: Colors.red),
                                          title: const Text('Delete'),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (ctx2) => AlertDialog(
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(18),
                                                ),
                                                backgroundColor: Colors.white,
                                                title: Row(
                                                  children: const [
                                                    Icon(Icons.delete, color: Colors.red, size: 28),
                                                    SizedBox(width: 10),
                                                    Text('Delete', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                                                  ],
                                                ),
                                                content: Text(
                                                  'Are you sure you want to delete "${item.name}"?',
                                                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                                                ),
                                                actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                actions: [
                                                  OutlinedButton(
                                                    onPressed: () => Navigator.pop(ctx2, false),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor: Colors.deepPurple,
                                                      side: const BorderSide(color: Colors.deepPurple),
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    child: const Text('Cancel'),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(ctx2, true),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.red,
                                                      foregroundColor: Colors.white,
                                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                    ),
                                                    child: const Text('Delete'),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              try {
                                                final client = Supabase.instance.client;
                                                if (isFolder) {
                                                  await _deleteFolderRecursively(item.fullPath, item.bucket);
                                                  // --- Add edit log ---
                                                  await logEditEvent('Deleted folder "${item.fullPath}" in bucket "${item.bucket}"');
                                                } else {
                                                  await client.storage.from(item.bucket).remove([item.fullPath]);
                                                  // --- Add edit log ---
                                                  await logEditEvent( 'Deleted file "${item.fullPath}" in bucket "${item.bucket}"');
                                                }
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Deleted "${item.name}"'), backgroundColor: Colors.green),
                                                );
                                                setState(() {});
                                                refreshCurrentFolder(context);
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                        ListTile(
                                          leading: const Icon(Icons.drive_file_rename_outline, color: Colors.deepPurple),
                                          title: const Text('Rename'),
                                          onTap: () async {
                                            Navigator.pop(ctx);
                                            await _showRenameDialog(item);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            }
                          : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        decoration: _cardDecoration(
                          color: isFolder ? Colors.deepPurple.withOpacity(0.08) : null,
                          selected: selected,
                        ),
                        child: ListTile(
                          leading: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.40),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              isFolder ? Icons.folder : Icons.insert_drive_file,
                              color: Colors.white,
                              size: isFolder ? 32 : 28,
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 16,
                              color: isFolder ? Colors.white : Colors.deepPurple,
                              letterSpacing: 0.2,
                            ),
                            softWrap: true,
                            maxLines: null,
                          ),
                          onTap: _selectionMode
                              ? () {
                                  setState(() {
                                    if (_selectedItems.contains(item.fullPath)) {
                                      _selectedItems.remove(item.fullPath);
                                    } else {
                                      _selectedItems.add(item.fullPath);
                                    }
                                  });
                                }
                              : (isFolder
                                  ? () => _navigateToFolder(item.fullPath, item.name, item.bucket)
                                  : () {
                                      final fileUrl = buildFileUrl(item.bucket, item.fullPath);
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => OtherViewer(url: fileUrl, name: item.name),
                                        ),
                                      );
                                    }),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isFolder)
                                FutureBuilder<int>(
                                  future: getFolderItemCount(context, item),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const SizedBox(
                                        width: 28,
                                        height: 22,
                                        child: Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                                      );
                                    }
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple,
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        '${snapshot.data}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              // Add download button for files (same position as folder count)
                              if (!isFolder)
                                Material(
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
                              if (_selectionMode)
                                Checkbox(
                                  value: selected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _selectedItems.add(item.fullPath);
                                      } else {
                                        _selectedItems.remove(item.fullPath);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          hoverColor: Colors.deepPurple.withOpacity(0.07),
                        ),
                      ),
                    );
                  },
                );
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
        // Only add new unique results
        if (snapshot.hasData) {
          final item = snapshot.data!;
          if (!_searchResults.any((e) => e.fullPath == item.fullPath)) {
            _searchResults.add(item);
          }
        }
        if (_searchResults.isEmpty && !_isSearchLoading) {
          return const Center(
            child: Text(
              'No results found.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          );
        }

        return FutureBuilder<bool>(
          future: _canEdit(),
          builder: (context, adminSnapshot) {
            final canEdit = adminSnapshot.data ?? false;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              itemCount: _searchResults.length,
              itemBuilder: (context, idx) {
                final item = _searchResults[idx];
                final isFolder = item.isFolder;
                final selected = _selectedItems.contains(item.fullPath);
                return GestureDetector(
                  onLongPress: canEdit
                      ? () async {
                          if (_selectionMode) return;
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
                                      leading: const Icon(Icons.select_all, color: Colors.deepPurple),
                                      title: const Text('Select More'),
                                      onTap: () {
                                        Navigator.pop(ctx);
                                        setState(() {
                                          _selectionMode = true;
                                          _selectedItems = {item.fullPath};
                                        });
                                      },
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.delete, color: Colors.red),
                                      title: const Text('Delete'),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx2) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(18),
                                            ),
                                            backgroundColor: Colors.white,
                                            title: Row(
                                              children: const [
                                                Icon(Icons.delete, color: Colors.red, size: 28),
                                                SizedBox(width: 10),
                                                Text('Delete', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                            content: Text(
                                              'Are you sure you want to delete "${item.name}"?',
                                              style: const TextStyle(fontSize: 16, color: Colors.black87),
                                            ),
                                            actionsPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            actions: [
                                              OutlinedButton(
                                                onPressed: () => Navigator.pop(ctx2, false),
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: Colors.deepPurple,
                                                  side: const BorderSide(color: Colors.deepPurple),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(ctx2, true),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                ),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            final client = Supabase.instance.client;
                                            if (isFolder) {
                                              await _deleteFolderRecursively(item.fullPath, item.bucket);
                                              // --- Add edit log ---
                                              await logEditEvent( 'Deleted folder "${item.fullPath}" in bucket "${item.bucket}"');
                                            } else {
                                              await client.storage.from(item.bucket).remove([item.fullPath]);
                                              // --- Add edit log ---
                                              await logEditEvent( 'Deleted file "${item.fullPath}" in bucket "${item.bucket}"');
                                            }
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Deleted "${item.name}"'), backgroundColor: Colors.green),
                                            );
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
                                    ListTile(
                                      leading: const Icon(Icons.drive_file_rename_outline, color: Colors.deepPurple),
                                      title: const Text('Rename'),
                                      onTap: () async {
                                        Navigator.pop(ctx);
                                        await _showRenameDialog(item);
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        }
                      : null,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: _cardDecoration(
                      color: isFolder ? Colors.deepPurple.withOpacity(0.08) : null,
                      selected: selected,
                    ),
                    child: ListTile(
                      leading: Container(
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          isFolder ? Icons.folder : Icons.insert_drive_file,
                          color: Colors.white,
                          size: isFolder ? 32 : 28,
                        ),
                      ),
                      title: Text(
                        item.name,
                        style: TextStyle(
                          fontSize: 16,
                          color: isFolder ? Colors.white : Colors.deepPurple,
                          letterSpacing: 0.2,
                        ),
                        softWrap: true,
                        maxLines: null,
                      ),
                      onTap: _selectionMode
                          ? () {
                              setState(() {
                                if (_selectedItems.contains(item.fullPath)) {
                                  _selectedItems.remove(item.fullPath);
                                } else {
                                  _selectedItems.add(item.fullPath);
                                }
                              });
                            }
                          : (isFolder
                              ? () {
                                  _clearSearch();
                                  _navigateToFolder(item.fullPath, item.name, item.bucket);
                                }
                              : () {
                                  final fileUrl = buildFileUrl(item.bucket, item.fullPath);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => OtherViewer(url: fileUrl, name: item.name),
                                    ),
                                  );
                                }),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isFolder)
                            FutureBuilder<int>(
                              future: getFolderItemCount(context, item),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    width: 28,
                                    height: 22,
                                    child: Center(
                                      child: SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.deepPurple,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '${snapshot.data}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                );
                              },
                            ),
                          // Add download button for files (same position as folder count)
                          if (!isFolder)
                            Material(
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
                          if (_selectionMode)
                            Checkbox(
                              value: selected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedItems.add(item.fullPath);
                                  } else {
                                    _selectedItems.remove(item.fullPath);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      hoverColor: Colors.deepPurple.withOpacity(0.07),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // --- Replace the rename dialog and logic with the provided version ---
  Future<void> _showRenameDialog(FolderFile file) async {
    final isFolder = file.isFolder;
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

  Future<void> _renameItem(FolderFile file, String newName, {required bool isFolder}) async {
    setState(() {
      // Optionally show loading indicator
    });
    try {
      if (isFolder) {
        // Ensure _folder suffix
        final newFolderName = newName.endsWith('_folder') ? newName : '${newName}_folder';
        final oldPath = file.fullPath;
        final parentPath = oldPath.contains('/') ? oldPath.substring(0, oldPath.lastIndexOf('/')) : '';
        final newPath = parentPath.isEmpty ? newFolderName : '$parentPath/$newFolderName';
        await _moveFolderRecursively(oldPath, newPath, file.bucket);
        // --- Add edit log ---
        await logEditEvent('Renamed folder "$oldPath" to "$newPath" in bucket "${file.bucket}"');
      } else {
        final oldPath = file.fullPath;
        final parentPath = oldPath.contains('/') ? oldPath.substring(0, oldPath.lastIndexOf('/')) : '';
        final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
        await Supabase.instance.client.storage
            .from(file.bucket)
            .move(oldPath, newPath);
        // --- Add edit log ---
        await logEditEvent( 'Renamed file "$oldPath" to "$newPath" in bucket "${file.bucket}"');
      }
      refreshCurrentFolder(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renamed successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _moveFolderRecursively(String oldPath, String newPath, String bucket) async {
    final contents = await Supabase.instance.client.storage
        .from(bucket)
        .list(path: oldPath);
    for (final item in contents) {
      final oldItemPath = '$oldPath/${item.name}';
      final newItemPath = '$newPath/${item.name}';
      if (item.name.endsWith('_folder')) {
        await _moveFolderRecursively(oldItemPath, newItemPath, bucket);
      } else {
        await Supabase.instance.client.storage
            .from(bucket)
            .move(oldItemPath, newItemPath);
      }
    }
    // Optionally, remove the old folder's .keep file if present
    try {
      await Supabase.instance.client.storage
          .from(bucket)
          .remove(['$oldPath/.keep']);
    } catch (_) {}
  }

  // --- Replace the recursive delete logic for folders ---
  Future<void> _deleteFolderRecursively(String folderPath, String bucket) async {
    final contents = await Supabase.instance.client.storage
        .from(bucket)
        .list(path: folderPath);
    for (final item in contents) {
      final itemPath = '$folderPath/${item.name}';
      if (item.name.endsWith('_folder')) {
        await _deleteFolderRecursively(itemPath, bucket);
        // Delete the subfolder marker itself
        await Supabase.instance.client.storage.from(bucket).remove([itemPath]);
      } else {
        await Supabase.instance.client.storage
            .from(bucket)
            .remove([itemPath]);
      }
    }
    // Remove the folder marker itself
    await Supabase.instance.client.storage.from(bucket).remove([folderPath]);
    // Optionally, remove the .keep file if present
    final keepPath = '$folderPath/.keep';
    try {
      await Supabase.instance.client.storage
          .from(bucket)
          .remove([keepPath]);
    } catch (_) {}
  }

  // Add this helper for recursive folder deletion (matching the signature used in the code)
  Future<void> _deleteFolderRecursive(
    SupabaseClient client,
    String bucket,
    String folderPath,
  ) async {
    final items = await client.storage.from(bucket).list(path: folderPath);
    for (final item in items) {
      final itemPath = '$folderPath/${item.name}';
      final isFolder = item.name.endsWith('_folder');
      if (isFolder) {
        await _deleteFolderRecursive(client, bucket, itemPath);
        await client.storage.from(bucket).remove([itemPath]);
      } else {
        await client.storage.from(bucket).remove([itemPath]);
      }
    }
    // Remove the folder marker itself
    await client.storage.from(bucket).remove([folderPath]);
    // --- Add edit log ---
    await logEditEvent('Deleted folder "$folderPath" in bucket "$bucket"');
  }

  @override
  void dispose() {
    _searchStreamController?.close();
    super.dispose();
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
