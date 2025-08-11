import 'package:flutter/material.dart';
import 'log.dart';

class ImageViewer extends StatefulWidget {
  final String url;
  final String name;

  const ImageViewer({Key? key, required this.url, required this.name}) : super(key: key);

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  bool _showOverlay = true;
  TransformationController _transformationController = TransformationController();
  bool _loading = true;
  bool _error = false;

  bool get _isZoomedIn {
    final matrix = _transformationController.value;
    return matrix.storage[0] > 1.0; // Check the scale (zoom level)
  }

  @override
  void initState() {
    super.initState();
    logUserEvent('Image Viewer Opened', details: widget.name);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF9),
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () {
          setState(() => _showOverlay = !_showOverlay);
          logUserEvent('Image Viewer Overlay Toggled', details: _showOverlay ? 'Shown' : 'Hidden');
        },
        onVerticalDragEnd: (_) {
          if (!_isZoomedIn) {
            logUserEvent('Image Viewer Drag Close', details: widget.name);
            Navigator.of(context).maybePop();
          }
        },
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                transformationController: _transformationController,
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 4.0,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (_loading)
                          const SizedBox(
                            width: 80,
                            height: 80,
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                        AnimatedOpacity(
                          opacity: _loading ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          child: Image.network(
                            widget.url,
                            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) {
                                _loading = false;
                                return child;
                              }
                              if (frame == null) {
                                return const SizedBox.shrink();
                              } else {
                                if (_loading) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted) setState(() => _loading = false);
                                  });
                                }
                                return child;
                              }
                            },
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const SizedBox.shrink();
                            },
                            errorBuilder: (_, __, ___) {
                              if (!_error) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (mounted) setState(() {
                                    _error = true;
                                    _loading = false;
                                  });
                                });
                              }
                              return const Center(
                                child: Icon(Icons.broken_image, color: Colors.red, size: 60),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_showOverlay)
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                right: 10,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1976D2)),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          overflow: TextOverflow.ellipsis,
                        ),
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
}
