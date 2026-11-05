import 'dart:math';

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/constants/colors.dart';
import 'package:immich_mobile/extensions/duration_extensions.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/widgets/asset_viewer/animated_play_pause.dart';

class VideoControls extends ConsumerStatefulWidget {
  final String videoPlayerName;

  static const List<Shadow> _controlShadows = [Shadow(color: Colors.black87, blurRadius: 6, offset: Offset(0, 1))];

  const VideoControls({super.key, required this.videoPlayerName});

  @override
  ConsumerState<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends ConsumerState<VideoControls> {
  late final RestartableTimer _hideTimer;

  AutoDisposeStateNotifierProvider<VideoPlayerNotifier, VideoPlayerState> get _provider =>
      videoPlayerProvider(widget.videoPlayerName);

  @override
  void initState() {
    super.initState();
    _hideTimer = RestartableTimer(const Duration(seconds: 5), _onHideTimer);
  }

  @override
  void didUpdateWidget(covariant VideoControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoPlayerName != widget.videoPlayerName) {
      _hideTimer.reset();
    }
  }

  @override
  void dispose() {
    _hideTimer.cancel();
    super.dispose();
  }

  void _onHideTimer() {
    if (!mounted) {
      return;
    }
    if (ref.read(_provider).status == VideoPlaybackStatus.playing) {
      ref.read(assetViewerProvider.notifier).setControls(false);
    }
  }

  void _toggle(bool isCasting) {
    if (isCasting) {
      ref.read(castProvider.notifier).toggle();
      return;
    }

    ref.read(_provider.notifier).toggle();
  }

  @override
  Widget build(BuildContext context) {
    final cast = ref.watch(castProvider);
    final isCasting = cast.isCasting;

    final progress = ref.watch(_videoProgressProvider(widget.videoPlayerName));
    final videoStatus = ref.watch(_provider.select((v) => v.status));
    final isPlaying = isCasting
        ? cast.castState == CastState.playing
        : videoStatus == VideoPlaybackStatus.playing || videoStatus == VideoPlaybackStatus.buffering;
    final isFinished = !isCasting && videoStatus == VideoPlaybackStatus.completed;

    ref.listen(assetViewerProvider.select((v) => v.showingControls), (prev, showing) {
      if (showing && prev != showing) {
        _hideTimer.reset();
      }
    });
    ref.listen(_provider.select((v) => v.status), (_, _) => _hideTimer.reset());

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
      child: Column(
        spacing: 4,
        children: [
          Row(
            children: [
              IconButton(
                iconSize: 32,
                padding: const EdgeInsets.all(12),
                constraints: const BoxConstraints(),
                icon: isFinished
                    ? const Icon(Icons.replay, color: Colors.white, shadows: VideoControls._controlShadows)
                    : AnimatedPlayPause(
                        color: Colors.white,
                        playing: isPlaying,
                        shadows: VideoControls._controlShadows,
                      ),
                onPressed: () => _toggle(isCasting),
              ),
              const Spacer(),
              IgnorePointer(
                child: Text(
                  "${progress.position.format()} / ${progress.duration.format()}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontFeatures: [FontFeature.tabularFigures()],
                    shadows: VideoControls._controlShadows,
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          VideoSeekBar(videoPlayerName: widget.videoPlayerName),
        ],
      ),
    );
  }
}

final _videoProgressProvider = Provider.autoDispose
    .family<({Duration position, Duration duration, bool casting}), String>((ref, name) {
      final casting = ref.watch(castProvider.select((c) => c.isCasting));
      final (position, duration) = casting
          ? ref.watch(castProvider.select((c) => (c.currentTime, c.duration)))
          : ref.watch(videoPlayerProvider(name).select((v) => (v.position, v.duration)));
      return (position: position, duration: duration, casting: casting);
    });

class VideoSeekBar extends ConsumerWidget {
  const VideoSeekBar({super.key, required this.videoPlayerName});

  final String videoPlayerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(_videoProgressProvider(videoPlayerName));
    final notifier = ref.watch(videoPlayerProvider(videoPlayerName).notifier);
    final duration = progress.duration.inMicroseconds.toDouble();
    return Slider(
      value: min(progress.position.inMicroseconds.toDouble(), duration),
      max: max(duration, 1),
      thumbColor: Colors.white,
      activeColor: Colors.white,
      inactiveColor: whiteOpacity75,
      padding: EdgeInsets.zero,
      onChangeStart: (_) => notifier.hold(),
      onChangeEnd: (_) => notifier.release(),
      onChanged: duration == 0
          ? null
          : (value) {
              final position = Duration(microseconds: value.toInt());
              if (progress.casting) {
                ref.read(castProvider.notifier).seekTo(position);
              } else {
                notifier.seekTo(position);
              }
            },
    );
  }
}
