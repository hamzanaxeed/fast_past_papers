import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'other_Viewers.dart';
import 'image_Viewer.dart';
import 'pdf_Viewer.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

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
      setState(() {
        currentPath = path;
        items = response;
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

  // --- Upload File Dialog (admin only) ---
  Future<void> _uploadFile() async {
    // Only allow if admin
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
      final file = File(picked.path);
      uploadedFileName = picked.name;
      uploadedFilePath = currentPath.isEmpty ? uploadedFileName : '$currentPath/$uploadedFileName';
      await Supabase.instance.client
          .storage
          .from('timetable')
          .upload(uploadedFilePath, file,
              fileOptions: const FileOptions(upsert: true));
      await _fetchItems(currentPath);
    } else if (type == 'pdf') {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
      if (result == null || result.files.single.path == null) return;
      final file = File(result.files.single.path!);
      uploadedFileName = result.files.single.name;
      uploadedFilePath = currentPath.isEmpty ? uploadedFileName : '$currentPath/$uploadedFileName';
      await Supabase.instance.client
          .storage
          .from('timetable')
          .upload(uploadedFilePath, file, fileOptions: const FileOptions(upsert: true));
      await _fetchItems(currentPath);
    }

    // --- Prompt for rename after upload ---
    if (uploadedFileName != null && uploadedFilePath != null) {
      final controller = TextEditingController(text: uploadedFileName);
      final newName = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('File Uploaded'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Uploaded as: $uploadedFileName'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Edit file name (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Keep Name'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rename'),
            ),
          ],
        ),
      );
      if (newName != null &&
          newName.isNotEmpty &&
          newName != uploadedFileName) {
        final newPath = currentPath.isEmpty ? newName : '$currentPath/$newName';
        await Supabase.instance.client
            .storage
            .from('timetable')
            .move(uploadedFilePath, newPath);
        await _fetchItems(currentPath);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: isAdmin,
      builder: (context, adminSnapshot) {
        final admin = adminSnapshot.data ?? false;
        return WillPopScope(
          onWillPop: _onWillPop,
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
                if (admin) ...[
                  IconButton(
                    icon: const Icon(Icons.create_new_folder),
                    tooltip: 'Create Folder',
                    onPressed: _showCreateFolderDialog,
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_file),
                    tooltip: 'Upload File',
                    onPressed: _uploadFile,
                  ),
                ],
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
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            final file = items[index];
                            if (_isFolder(file)) {
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
                                    file.name.replaceAll('_folder', ''),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                  onTap: () => _onTapItem(file),
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
                                    child: _isImage(file.name)
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
                                    file.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      color: Colors.deepPurple,
                                    ),
                                  ),
                                  onTap: () => _onTapItem(file),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  hoverColor: Colors.deepPurple.withOpacity(0.07),
                                ),
                              );
                            }
                          },
                        ),
            ),
          ),
        );
      },
    );
  }
}
