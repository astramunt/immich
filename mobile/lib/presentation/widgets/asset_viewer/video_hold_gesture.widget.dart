import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';

/// Covers the viewport, including letterboxing, without intercepting taps or swipes.
class VideoHoldGesture extends ConsumerStatefulWidget {
  final String assetId;
  final bool enabled;
  final Widget child;

  const VideoHoldGesture({super.key, required this.assetId, required this.enabled, required this.child});

  @override
  ConsumerState<VideoHoldGesture> createState() => _VideoHoldGestureState();
}

class _VideoHoldGestureState extends ConsumerState<VideoHoldGesture> {
  late VideoPlayerNotifier _player;

  @override
  void initState() {
    super.initState();
    _player = ref.read(videoPlayerProvider(widget.assetId).notifier);
  }

  @override
  void didUpdateWidget(VideoHoldGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      unawaited(_player.stopHoldPlayback(resume: false));
      _player = ref.read(videoPlayerProvider(widget.assetId).notifier);
    } else if (oldWidget.enabled && !widget.enabled) {
      unawaited(_player.stopHoldPlayback(resume: false));
    }
  }

  @override
  void dispose() {
    unawaited(_player.stopHoldPlayback(resume: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoPlayerProvider(widget.assetId));
    final casting = ref.watch(castProvider.select((state) => state.isCasting));
    final details = ref.watch(assetViewerProvider.select((state) => state.showingDetails));
    ref.listen(castProvider.select((state) => state.isCasting), (_, casting) {
      if (casting) {
        unawaited(_player.stopHoldPlayback(resume: false));
      }
    });
    final enabled = widget.enabled && !casting && !details;

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: enabled
              ? (details) {
                  unawaited(
                    _player.startHoldPlayback(
                      reverse: details.localPosition.dx < constraints.maxWidth / 2,
                      speed: ref.read(appConfigProvider).viewer.holdSpeed,
                    ),
                  );
                }
              : null,
          onLongPressEnd: enabled ? (_) => unawaited(_player.stopHoldPlayback()) : null,
          onLongPressCancel: enabled ? () => unawaited(_player.stopHoldPlayback()) : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (state.holdSpeed != 0)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 72,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(state.holdSpeed < 0 ? Icons.fast_rewind : Icons.fast_forward, color: Colors.white),
                              const SizedBox(width: 8),
                              Text('×${state.holdSpeed.abs()}', style: const TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
