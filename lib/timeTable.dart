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
import 'image_Viewer.dart';
import 'pdf_Viewer.dart';

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({Key? key}) : super(key: key);

  @override
  State<TimeTableScreen> createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> {
  List<FileObject> items = [];
  bool loading = true;
  String? error;
  String currentPath = '';

  // --- Admin logic start ---
  List<String> admin_Emails = [];
  bool adminsFetched = false;

  // Selection mode state
  bool _selectionMode = false;
  Set<String> _selectedItems = {};

  Future<void> fetchAdminEmails() async {
    try {
      final response = await Supabase.instance.client
          .from('Admins')
          .select('admin_Email');
      if (response is List) {
        admin_Emails = response
            .map((e) => e['admin_Email']?.toString().toLowerCase())
            .where((email) => email != null)
            .cast<String>()
            .toList();
        adminsFetched = true;
      }
    } catch (e) {
      adminsFetched = false;
    }
  }

  Future<bool> get isAdmin async {
    await fetchAdminEmails();
    final email = FirebaseAuth.instance.currentUser?.email?.toLowerCase();
    return email != null && admin_Emails.contains(email);
  }
  // --- Admin logic end ---

  @override
  void initState() {
    super.initState();
    _fetchItems('');
    fetchAdminEmails(); // Pre-fetch admin emails
  }

  Future<void> _fetchItems(String path) async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Supabase.instance.client.storage
          .from('timetable')
          .list(path: path);
      // Filter out .keep and .emptyFolderPlaceholder files
      final filtered = response.where((item) =>
        item.name != '.keep' && item.name != '.emptyFolderPlaceholder'
      ).toList();
      setState(() {
        currentPath = path;
        items = filtered;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = 'Failed to load timetable: $e';
        loading = false;
      });
    }
  }

  bool _isFolder(FileObject file) => file.name.endsWith('_folder');
  bool _isImage(String name) {
    final ext = name.toLowerCase();
    return ext.endsWith('.jpg') || ext.endsWith('.jpeg') || ext.endsWith('.png') || ext.endsWith('.gif');
  }
  bool _isPdf(String name) => name.toLowerCase().endsWith('.pdf');
  bool _isPptx(String name) => name.toLowerCase().endsWith('.pptx');
  bool _isDocx(String name) => name.toLowerCase().endsWith('.docx');
  bool _isXlsx(String name) => name.toLowerCase().endsWith('.xlsx');
  bool _isTxt(String name) => name.toLowerCase().endsWith('.txt');

  void _onTapItem(FileObject file) {
    if (_isFolder(file)) {
      final nextPath = currentPath.isEmpty
          ? file.name
          : '$currentPath/${file.name}';
      _fetchItems(nextPath);
    } else {
      final filePath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
      final url = Supabase.instance.client.storage.from('timetable').getPublicUrl(filePath);
      if (_isImage(file.name)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImageViewer(url: url, name: file.name),
          ),
        );
      } else if (_isPdf(file.name)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfViewerScreen(url: url, name: file.name),
          ),
        );
      } else if (_isPptx(file.name) ||
          _isDocx(file.name) ||
          _isXlsx(file.name) ||
          _isTxt(file.name)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherViewer(url: url, name: file.name),
          ),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtherViewer(url: url, name: file.name),
          ),
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (currentPath.isNotEmpty) {
      var path = currentPath.endsWith('/')
          ? currentPath.substring(0, currentPath.length - 1)
          : currentPath;
      final parts = path.split('/');
      if (parts.isNotEmpty) parts.removeLast();
      final parentPath = parts.isEmpty ? '' : parts.join('/');
      await _fetchItems(parentPath);
      return false;
    }
    return true;
  }

  String get displayPath {
    if (currentPath.isEmpty) return 'Time Table';
    final parts = currentPath
        .split('/')
        .where((part) => part.isNotEmpty)
        .map((p) => p.replaceAll('_folder', ''))
        .toList();
    return parts.join(' / ');
  }

  // Card decoration copied from welcome_Screen.dart
  BoxDecoration _cardDecoration({Color? color}) => BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.deepPurple.withOpacity(0.08), width: 1),
      );

  // --- Create Folder Dialog (admin only) ---
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
          : '$currentPath/$safeName';

      // Create a .keep file to represent the folder
      final tempFile = await File('${Directory.systemTemp.path}/.keep').create();
      await tempFile.writeAsBytes([]);
      await Supabase.instance.client
          .storage
          .from('timetable')
          .upload('$folderPath/.keep', tempFile,
              fileOptions: const FileOptions(upsert: false));
      await tempFile.delete();
      await _fetchItems(currentPath);
    }
  }

  // --- Upload File Dialog (admin only, improved) ---
  Future<void> _uploadFile() async {
    if (!await isAdmin) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only admins can upload files in Timetable section.'),
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

    String? uploadedFileName;
    String? uploadedFilePath;

    if (type == 'image') {
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

      // Ask for new file name before upload
      final ext = picked.name.contains('.') ? picked.name.substring(picked.name.lastIndexOf('.')) : '';
      final baseName = ext.isNotEmpty ? picked.name.substring(0, picked.name.length - ext.length) : picked.name;
      final nameController = TextEditingController(text: baseName);
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white,
          title: const Text('Rename Image', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'File name',
              suffixText: ext,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            autofocus: true,
          ),
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
                final name = nameController.text.trim();
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
      if (newName == null || newName.trim().isEmpty) return;

      uploadedFileName = newName;
      uploadedFilePath = currentPath.isEmpty ? uploadedFileName : '$currentPath/$uploadedFileName';
      final file = File(picked.path);

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
        await Supabase.instance.client
            .storage
            .from('timetable')
            .upload(uploadedFilePath, file, fileOptions: const FileOptions(upsert: true));
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
        await _fetchItems(currentPath);
      } catch (e) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } else if (type == 'pdf') {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.single.path == null) return;

      // Ask for new file name before upload
      final pickedName = result.files.single.name;
      final ext = pickedName.contains('.') ? pickedName.substring(pickedName.lastIndexOf('.')) : '';
      final baseName = ext.isNotEmpty ? pickedName.substring(0, pickedName.length - ext.length) : pickedName;
      final nameController = TextEditingController(text: baseName);
      final newName = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: Colors.white,
          title: const Text('Rename PDF', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(
              labelText: 'File name',
              suffixText: ext,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            autofocus: true,
          ),
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
                final name = nameController.text.trim();
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
      if (newName == null || newName.trim().isEmpty) return;

      uploadedFileName = newName;
      uploadedFilePath = currentPath.isEmpty ? uploadedFileName : '$currentPath/$uploadedFileName';
      final file = File(result.files.single.path!);

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
        await Supabase.instance.client
            .storage
            .from('timetable')
            .upload(uploadedFilePath, file, fileOptions: const FileOptions(upsert: true));
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
        await _fetchItems(currentPath);
      } catch (e) {
        scaffold.hideCurrentSnackBar();
        scaffold.showSnackBar(
          SnackBar(
            content: Text('Upload failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // --- Delete logic for admin (long press) ---
  Future<void> _deleteFileOrFolder(FileObject file) async {
    final isFolder = _isFolder(file);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete'),
        content: Text('Are you sure you want to delete "${file.name.replaceAll('_folder', '')}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      if (isFolder) {
        final folderPath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
        await _deleteFolderRecursively(folderPath);
      } else {
        final filePath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
        await Supabase.instance.client.storage.from('timetable').remove([filePath]);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted "${file.name.replaceAll('_folder', '')}"'), backgroundColor: Colors.green),
      );
      await _fetchItems(currentPath);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Fix: Accept folderPath as a String, not FileObject
  Future<void> _deleteFolderRecursively(String folderPath) async {
    final contents = await Supabase.instance.client.storage
        .from('timetable')
        .list(path: folderPath);
    for (final item in contents) {
      final itemPath = '$folderPath/${item.name}';
      if (_isFolder(item)) {
        await _deleteFolderRecursively(itemPath);
        await Supabase.instance.client.storage.from('timetable').remove([itemPath]);
      } else {
        await Supabase.instance.client.storage.from('timetable').remove([itemPath]);
      }
    }
    await Supabase.instance.client.storage.from('timetable').remove([folderPath]);
  }

  // --- Rename logic ---
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
        final parentPath = oldPath.contains('/') ? oldPath.substring(0, oldPath.lastIndexOf('/')) : '';
        final newPath = parentPath.isEmpty ? newFolderName : '$parentPath/$newFolderName';

        // Recursively copy all contents to new folder path
        await _copyFolderRecursively(oldPath, newPath);

        // DO NOT upload an empty marker file for the new folder (fixes duplicate/copy issue)

        // Recursively delete old folder and its contents
        await _deleteFolderRecursively(oldPath);

      } else {
        final oldPath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
        final parentPath = oldPath.contains('/') ? oldPath.substring(0, oldPath.lastIndexOf('/')) : '';
        final newPath = parentPath.isEmpty ? newName : '$parentPath/$newName';
        await Supabase.instance.client.storage
            .from('timetable')
            .move(oldPath, newPath);
      }
      await _fetchItems(currentPath);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renamed successfully!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() {
        error = 'Failed to rename: $e';
        loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to rename: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Recursively copy all files/folders from oldPath to newPath
  Future<void> _copyFolderRecursively(String oldPath, String newPath) async {
    final contents = await Supabase.instance.client.storage
        .from('timetable')
        .list(path: oldPath);
    for (final item in contents) {
      final oldItemPath = '$oldPath/${item.name}';
      final newItemPath = '$newPath/${item.name}';
      if (_isFolder(item)) {
        await _copyFolderRecursively(oldItemPath, newItemPath);
        // DO NOT upload an empty marker file for subfolder (fixes duplicate/copy issue)
      } else {
        // Copy file
        final fileBytes = await Supabase.instance.client.storage.from('timetable').download(oldItemPath);
        final tempDir = Directory.systemTemp;
        final tempFile = await File('${tempDir.path}/temp_rename_file').create();
        await tempFile.writeAsBytes(fileBytes);
        await Supabase.instance.client.storage.from('timetable').upload(
          newItemPath,
          tempFile,
          fileOptions: const FileOptions(upsert: true),
        );
        await tempFile.delete();
      }
    }
  }

  // --- 3-dot menu for admin and user actions (same as homeScreen) ---
  void _handleMenu(BuildContext context, String value, bool isAdmin) async {
    if (value == 'feedback') {
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
      await _uploadFile();
    } else if (value == 'create_folder' && isAdmin) {
      await _showCreateFolderDialog();
    } else if (value == 'logout') {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isAdmin,
      builder: (context, adminSnapshot) {
        final admin = adminSnapshot.data ?? false;
        return WillPopScope(
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
            appBar: AppBar(
              title: Text(
                displayPath,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  letterSpacing: 1.1,
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
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              leading: currentPath.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () async {
                        await _onWillPop();
                      },
                    )
                  : null,
              actions: [
                if (admin && _selectionMode)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    tooltip: 'Delete Selected',
                    onPressed: _selectedItems.isEmpty
                        ? null
                        : () async {
                            final selectedFiles = items.where((item) => _selectedItems.contains(item.name)).toList();
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx2) => AlertDialog(
                                title: const Text('Delete Selected'),
                                content: Text('Are you sure you want to delete ${selectedFiles.length} selected item(s)?'),
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
                              for (final file in selectedFiles) {
                                try {
                                  if (_isFolder(file)) {
                                    final folderPath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
                                    await _deleteFolderRecursively(folderPath);
                                  } else {
                                    final filePath = currentPath.isEmpty ? file.name : '$currentPath/${file.name}';
                                    await Supabase.instance.client.storage.from('timetable').remove([filePath]);
                                  }
                                } catch (_) {}
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Deleted ${selectedFiles.length} item(s)!'), backgroundColor: Colors.green),
                              );
                              setState(() {
                                _selectionMode = false;
                                _selectedItems.clear();
                              });
                              await _fetchItems(currentPath);
                            }
                          },
                  ),
                if (!_selectionMode)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    onSelected: (value) => _handleMenu(context, value, admin),
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
                      if (admin)
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
                      if (admin)
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
                      if (admin)
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
            body: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7F7FD5), Color(0xFF86A8E7), Color(0xFF91EAE4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                      : items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.folder_open, color: Colors.white54, size: 64),
                                  SizedBox(height: 16),
                                  Text(
                                    'Nothing to show',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                              itemCount: items.length,
                              itemBuilder: (context, index) {
                                final file = items[index];
                                final isFolder = _isFolder(file);
                                final selected = _selectedItems.contains(file.name);
                                return GestureDetector(
                                  onLongPress: admin
                                      ? () async {
                                          if (_selectionMode) return;
                                          showModalBottomSheet(
                                            context: context,
                                            shape: const RoundedRectangleBorder(
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                                            ),
                                            builder: (ctx) => SafeArea(
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
                                                        _selectedItems = {file.name};
                                                      });
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(Icons.delete, color: Colors.red),
                                                    title: const Text('Delete'),
                                                    onTap: () async {
                                                      Navigator.pop(ctx);
                                                      await _deleteFileOrFolder(file);
                                                    },
                                                  ),
                                                  ListTile(
                                                    leading: const Icon(Icons.drive_file_rename_outline, color: Colors.deepPurple),
                                                    title: const Text('Rename'),
                                                    onTap: () async {
                                                      Navigator.pop(ctx);
                                                      await _showRenameDialog(file);
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                  child: Container(
                                    margin: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: _cardDecoration(
                                      color: isFolder ? Colors.deepPurple.withOpacity(0.08) : null,
                                    ),
                                    child: ListTile(
                                      leading: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.deepPurple.withOpacity(0.40),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.all(6),
                                        child: isFolder
                                            ? const Icon(Icons.folder, color: Colors.white, size: 32)
                                            : _isImage(file.name)
                                                ? const Icon(Icons.image, color: Colors.white, size: 28)
                                                : _isPdf(file.name)
                                                    ? const Icon(Icons.picture_as_pdf, color: Colors.white, size: 28)
                                                    : _isPptx(file.name)
                                                        ? const Icon(Icons.slideshow, color: Colors.white, size: 28)
                                                        : _isDocx(file.name)
                                                            ? const Icon(Icons.description, color: Colors.white, size: 28)
                                                            : _isXlsx(file.name)
                                                                ? const Icon(Icons.table_chart, color: Colors.white, size: 28)
                                                                : _isTxt(file.name)
                                                                    ? const Icon(Icons.text_snippet, color: Colors.white, size: 28)
                                                                    : const Icon(Icons.insert_drive_file, color: Colors.white, size: 28),
                                      ),
                                      title: Text(
                                        isFolder ? file.name.replaceAll('_folder', '') : file.name,
                                        style: TextStyle(
                                          fontWeight: isFolder ? FontWeight.bold : FontWeight.w600,
                                          fontSize: isFolder ? 20 : 18,
                                          color: isFolder ? Colors.white : Colors.deepPurple,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      onTap: _selectionMode
                                          ? () {
                                              setState(() {
                                                if (_selectedItems.contains(file.name)) {
                                                  _selectedItems.remove(file.name);
                                                } else {
                                                  _selectedItems.add(file.name);
                                                }
                                              });
                                            }
                                          : () => _onTapItem(file),
                                      trailing: _selectionMode
                                          ? Checkbox(
                                              value: selected,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedItems.add(file.name);
                                                  } else {
                                                    _selectedItems.remove(file.name);
                                                  }
                                                });
                                              },
                                            )
                                          : null,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      hoverColor: Colors.deepPurple.withOpacity(0.13),
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ),
        );
      },
    );
  }
}
