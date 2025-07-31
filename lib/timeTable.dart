import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'other_Viewers.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchItems('');
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(displayPath),
          backgroundColor: Colors.deepOrange,
          foregroundColor: Colors.white,
          leading: currentPath.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () async {
                    await _onWillPop();
                  },
                )
              : null,
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
                              border: Border.all(color: Colors.deepPurple.withOpacity(0.08), width: 1),
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
                              border: Border.all(color: Colors.deepPurple.withOpacity(0.08), width: 1),
                            ),
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
  }
}
