import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/widgets/photo_view/photo_view.dart';

/// Routes video taps across the viewport, including letterboxing.
class VideoHoldGesture extends ConsumerStatefulWidget {
  final String assetId;
  final bool enabled;
  final ValueChanged<TapUpDetails> onSingleTap;
  final Widget Function(PhotoViewScaleStateController) builder;

  const VideoHoldGesture({
    super.key,
    required this.assetId,
    required this.enabled,
    required this.onSingleTap,
    required this.builder,
  });

  @override
  ConsumerState<VideoHoldGesture> createState() => _VideoHoldGestureState();
}

class _VideoHoldGestureState extends ConsumerState<VideoHoldGesture> {
  static const _pauseSize = 96.0;
  static const _edgeFraction = 0.25;
  static const _feedbackDuration = Duration(milliseconds: 700);

  final _zoom = PhotoViewScaleStateController();
  Offset _doubleTapPosition = Offset.zero;
  late VideoPlayerNotifier _player;
  Timer? _feedbackTimer;
  _VideoGestureFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _player = ref.read(videoPlayerProvider(widget.assetId).notifier);
  }

  @override
  void didUpdateWidget(VideoHoldGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      unawaited(_player.stopHoldPlayback());
      _player = ref.read(videoPlayerProvider(widget.assetId).notifier);
    } else if (oldWidget.enabled && !widget.enabled) {
      unawaited(_player.stopHoldPlayback());
    }
  }

  @override
  void dispose() {
    _zoom.dispose();
    _feedbackTimer?.cancel();
    unawaited(_player.stopHoldPlayback());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(videoPlayerProvider(widget.assetId));
    final casting = ref.watch(castProvider.select((state) => state.isCasting));
    final details = ref.watch(assetViewerProvider.select((state) => state.showingDetails));
    ref.listen(castProvider.select((state) => state.isCasting), (_, casting) {
      if (casting) {
        unawaited(_player.stopHoldPlayback());
      }
    });
    final enabled = widget.enabled && !casting && !details;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final edgeWidth = size.width * _edgeFraction;
        final pauseBox = Rect.fromCenter(center: size.center(Offset.zero), width: _pauseSize, height: _pauseSize);
        final holdSpeed = state.holdSpeed;
        final feedback = holdSpeed != 0
            ? _VideoGestureFeedback(icon: Icons.fast_forward, label: '×$holdSpeed')
            : _feedback;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPressStart: enabled
              ? (_) {
                  unawaited(_player.startHoldPlayback(speed: ref.read(appConfigProvider).viewer.holdSpeed));
                }
              : null,
          onLongPressEnd: enabled ? (_) => unawaited(_player.stopHoldPlayback()) : null,
          onLongPressCancel: enabled ? () => unawaited(_player.stopHoldPlayback()) : null,
          onDoubleTapDown: enabled ? (details) => _doubleTapPosition = details.localPosition : null,
          onDoubleTap: enabled
              ? () {
                  final position = _doubleTapPosition;
                  if (pauseBox.contains(position)) {
                    return;
                  }
                  final left = position.dx < edgeWidth;
                  final right = position.dx > size.width - edgeWidth;
                  if (!left && !right) {
                    _zoom.scaleState = _zoom.scaleState == PhotoViewScaleState.initial
                        ? PhotoViewScaleState.videoZoom
                        : PhotoViewScaleState.initial;
                    return;
                  }

                  final top = position.dy < size.height / 2;
                  final forward = left ? top : !top;
                  final seconds = ref.read(appConfigProvider).viewer.doubleTapSeekSeconds;
                  _player.seekBy(Duration(seconds: forward ? seconds : -seconds));
                  _showFeedback(forward ? Icons.fast_forward : Icons.fast_rewind, '${forward ? '+' : '-'}$seconds s');
                }
              : null,
          onTapUp: enabled
              ? (details) {
                  if (pauseBox.contains(details.localPosition)) {
                    final isPlaying =
                        state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering;
                    _player.toggle();
                    _showFeedback(isPlaying ? Icons.pause : Icons.play_arrow, '');
                  } else {
                    widget.onSingleTap(details);
                  }
                }
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.builder(_zoom),
              if (feedback != null)
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 72,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.94),
                          borderRadius: const BorderRadius.all(Radius.circular(24)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(feedback.icon, color: Colors.white),
                              if (feedback.label.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Text(feedback.label, style: const TextStyle(color: Colors.white)),
                              ],
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

  void _showFeedback(IconData icon, String label) {
    _feedbackTimer?.cancel();
    setState(() => _feedback = _VideoGestureFeedback(icon: icon, label: label));
    _feedbackTimer = Timer(_feedbackDuration, () {
      if (mounted) {
        setState(() => _feedback = null);
      }
    });
  }
}

class _VideoGestureFeedback {
  final IconData icon;
  final String label;

  const _VideoGestureFeedback({required this.icon, required this.label});
}
