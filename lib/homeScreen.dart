import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'getfiles.dart';
import 'other_Viewers.dart';
import 'main.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

class PastPaperHomeScreen extends StatelessWidget {
  const PastPaperHomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const FolderScreen(folderPath: '', title: 'Past Papers');
  }
}

class FolderScreen extends StatefulWidget {
  final String folderPath;
  final String title;
  final String? bucket;
  const FolderScreen({Key? key, required this.folderPath, required this.title, this.bucket}) : super(key: key);

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> with AutomaticKeepAliveClientMixin {
  String? _lastLoadedPath;
  String? _lastLoadedBucket;
  PastPaperProvider? _provider;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchFolderUI(context, widget.folderPath, widget.bucket, force: true);
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // Only build the title and contents, avoid rebuilding the whole UI or using Stack
    return Scaffold(
      extendBodyBehindAppBar: false,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          widget.title,
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
        ),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
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
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              itemCount: provider.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, idx) {
                final item = provider.items[idx];
                if (item.isFolder) {
                  return FutureBuilder<int>(
                    future: getFolderItemCount(context, item),
                    builder: (context, snapshot) {
                      final count = snapshot.hasData ? snapshot.data! : null;
                      return Container(
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
                          trailing: count != null
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
                                    //  const Icon(Icons.folder_open, color: Colors.white, size: 18),
                                     // const SizedBox(width: 2),
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
                                ),
                          onTap: () {
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => FolderScreen(
                                  folderPath: item.fullPath,
                                  title: item.name,
                                  bucket: item.bucket,
                                ),
                                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                transitionDuration: const Duration(milliseconds: 250),
                              ),
                            ).then((_) {
                              _fetchParentFolder();
                            });
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          hoverColor: Colors.deepPurple.withOpacity(0.13),
                        ),
                      );
                    },
                  );
                } else {
                  return Container(
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
        ),
      ),
    );
  }
}
