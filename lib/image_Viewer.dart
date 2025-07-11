import 'package:flutter/material.dart';

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

  bool get _isZoomedIn {
    final matrix = _transformationController.value;
    return matrix.storage[0] > 1.0; // Check the scale (zoom level)
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        onVerticalDragEnd: (_) {
          if (!_isZoomedIn) {
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
                    child: Image.network(
                      widget.url,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
                        );
                      },
                      errorBuilder: (_, __, ___) => const Center(
                        child: Icon(Icons.broken_image, color: Colors.red, size: 60),
                      ),
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
                      icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), // Consistent with appbar
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.name,
                        style: const TextStyle(
                          color: Colors.white, // Consistent with appbar
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
