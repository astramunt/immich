import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/config/viewer_config.dart';

/// All coordinates are logical pixels in the video viewport, including its letterbox.
class VideoGestureZones {
  final Size size;
  final double edge;
  final double split;
  final Rect pause;

  VideoGestureZones(this.size, ViewerConfig viewer)
    : edge = _extent(viewer.seekEdgeWidth, size.width * viewer.seekEdgePercent / 100, size.width / 2),
      split = _extent(viewer.seekTopHeight, size.height * viewer.seekTopPercent / 100, size.height),
      pause = Rect.fromCenter(
        center: size.center(Offset.zero),
        width: viewer.pauseBoxSize.clamp(0.0, size.width),
        height: viewer.pauseBoxSize.clamp(0.0, size.height),
      );

  Rect quadrant({required bool left, required bool top}) =>
      Rect.fromLTRB(left ? 0 : size.width - edge, top ? 0 : split, left ? edge : size.width, top ? split : size.height);
}

double _extent(double exact, double automatic, double available) =>
    (exact > 0 ? exact : automatic).clamp(0.0, available);

class VideoZoneFrame extends StatelessWidget {
  const VideoZoneFrame({super.key, required this.color, this.icon, this.alignment = Alignment.center});

  final Color color;
  final IconData? icon;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        border: Border.all(color: color, width: 2),
      ),
      child: icon == null
          ? null
          : Align(
              alignment: alignment,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Icon(icon, size: 22, color: color),
              ),
            ),
    ),
  );
}

class VideoZoneFrames extends StatelessWidget {
  const VideoZoneFrames({super.key, required this.zones});

  final VideoGestureZones zones;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Stack(
      children: [
        Positioned.fromRect(
          rect: Rect.fromLTRB(zones.edge, 0, zones.size.width - zones.edge, zones.size.height),
          child: const VideoZoneFrame(
            color: Colors.lightBlueAccent,
            icon: Icons.zoom_in,
            alignment: Alignment(0, -0.48),
          ),
        ),
        for (final left in [true, false])
          for (final top in [true, false])
            Positioned.fromRect(
              rect: zones.quadrant(left: left, top: top),
              child: VideoZoneFrame(
                color: left == top ? Colors.tealAccent : Colors.orangeAccent,
                icon: left == top ? Icons.fast_forward : Icons.fast_rewind,
              ),
            ),
        Positioned.fromRect(
          rect: zones.pause,
          child: const VideoZoneFrame(color: Colors.yellowAccent, icon: Icons.pause),
        ),
      ],
    ),
  );
}

/// Positions the two sliders within the safe area between the top and bottom controls.
class VideoSideZoneLayout extends StatelessWidget {
  const VideoSideZoneLayout({super.key, required this.viewer, required this.child});

  final ViewerConfig viewer;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = viewer.seekBarWidth.clamp(0.0, constraints.maxWidth / 2);
      final height = _extent(
        viewer.seekBarHeight,
        constraints.maxHeight * viewer.seekBarHeightPercent / 100,
        constraints.maxHeight,
      );
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var side = 0; side < 2; side++)
            SizedBox(
              width: width,
              height: height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (viewer.showVideoZoneFrames) const VideoZoneFrame(color: Colors.purpleAccent),
                ],
              ),
            ),
        ],
      );
    },
  );
}
