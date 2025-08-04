import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'getfiles.dart';
import 'other_Viewers.dart';
import 'main.dart'; // Import for SupabaseClient
import 'package:supabase_flutter/supabase_flutter.dart';

class PastPaperHomeScreen extends StatelessWidget {
  const PastPaperHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FolderScreen(folderPath: '', title: 'Past Papers');
  }
}

// Convert FolderScreen to StatefulWidget to fetch files in initState
class FolderScreen extends StatefulWidget {
  final String folderPath;
  final String title;
  final String? bucket;
  const FolderScreen({Key? key, required this.folderPath, required this.title, this.bucket}) : super(key: key);

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  String? _lastLoadedPath;
  String? _lastLoadedBucket;
  PastPaperProvider? _provider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFolder(force: true);
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
        _fetchFolder(force: true);
      });
    }
  }

  void _fetchFolder({bool force = false}) {
    final provider = _provider ?? Provider.of<PastPaperProvider>(context, listen: false);
    if (force || widget.folderPath != _lastLoadedPath || widget.bucket != _lastLoadedBucket) {
      if (widget.folderPath.isEmpty) {
        provider.fetchRootFoldersAndFiles();
      } else {
        provider.fetchFolderContents(widget.bucket ?? '', widget.folderPath);
      }
      _lastLoadedPath = widget.folderPath;
      _lastLoadedBucket = widget.bucket;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PastPaperProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
          body: provider.loading
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null
                  ? Center(child: Text(provider.error!, style: const TextStyle(color: Colors.red)))
                  : provider.items.isEmpty
                      ? const Center(child: Text('No folders/files found.'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          itemCount: provider.items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, idx) {
                            final item = provider.items[idx];
                            return Card(
                              elevation: 6,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              child: ListTile(
                                leading: Icon(
                                  item.isFolder ? Icons.folder : Icons.insert_drive_file,
                                  color: item.isFolder ? Colors.amber : Colors.blue,
                                  size: 32,
                                ),
                                title: Text(item.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                                onTap: () {
                                  if (item.isFolder) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FolderScreen(
                                          folderPath: item.fullPath,
                                          title: item.name,
                                          bucket: item.bucket,
                                        ),
                                      ),
                                    ).then((_) {
                                      // When returning from subfolder, reload current folder
                                      _fetchFolder(force: true);
                                    });
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
                              ),
                            );
                          },
                        ),
        );
      },
    );
  }
}

// Helper to build file URL using correct SupabaseClient and bucket
String buildFileUrl(String bucket, String filePath) {
  final client = bucket == 'pastpaper1' ? tempSupabaseClient : Supabase.instance.client;
  return client.storage.from(bucket).getPublicUrl(filePath);
}
