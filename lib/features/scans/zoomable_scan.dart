import 'package:flutter/material.dart';

/// Pinch-zoom scan. Decodes at roughly screen size until the user zooms in,
/// then at full resolution: a full-size film scan is tens of MB of RGBA.
class ZoomableScan extends StatefulWidget {
  const ZoomableScan({super.key, required this.url, this.loading, this.error});
  final String url;
  final Widget? loading, error;

  @override
  State<ZoomableScan> createState() => _ZoomableScanState();
}

class _ZoomableScanState extends State<ZoomableScan> {
  static const _zoomThreshold = 1.5;
  final _controller = TransformationController();
  bool _fullRes = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    if (!_fullRes && _controller.value.getMaxScaleOnAxis() > _zoomThreshold) {
      setState(() => _fullRes = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final fitWidth = (mq.size.width * mq.devicePixelRatio).round();
    return InteractiveViewer(
      transformationController: _controller,
      maxScale: 6,
      onInteractionEnd: _onInteractionEnd,
      child: Center(
        child: Image.network(
          widget.url,
          cacheWidth: _fullRes ? null : fitWidth,
          gaplessPlayback: true,
          loadingBuilder: (c, child, p) => p == null
              ? child
              : widget.loading ??
                    const Center(child: CircularProgressIndicator()),
          errorBuilder: (_, _, _) =>
              widget.error ??
              const Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      ),
    );
  }
}
