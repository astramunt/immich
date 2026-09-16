import 'dart:async';

import 'package:logging/logging.dart';
import 'package:native_video_player/native_video_player.dart';

/// Temporary fast playback. Reverse uses seeks because Android requires a positive rate.
class VideoHoldPlayback {
  static final _log = Logger('VideoHoldPlayback');
  static const speeds = [2, 5, 10];

  final NativeVideoPlayerController controller;
  final void Function(int speed) onSpeedChanged;
  final DateTime Function() _now;
  Future<void> _pending = Future.value();
  Timer? _timer;
  int _generation = 0;
  int _speed = 0;
  bool _disposed = false;

  VideoHoldPlayback(this.controller, {required this.onSpeedChanged, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  bool get isActive => _speed != 0;
  bool get isReversing => _speed < 0;

  Future<void> _enqueue(Future<void> Function() action) {
    return _pending = _pending.then((_) => action()).catchError((Object error, StackTrace stack) {
      _log.warning('Error changing temporary video playback', error, stack);
    });
  }

  Future<void> start({required bool reverse, required int speed}) {
    if (_disposed || isActive || controller.playbackInfo?.status != PlaybackStatus.playing) {
      return Future.value();
    }
    final multiplier = speeds.contains(speed) ? speed : 2;
    final generation = ++_generation;
    _speed = reverse ? -multiplier : multiplier;
    onSpeedChanged(_speed);
    return _enqueue(() async {
      if (_disposed || generation != _generation) {
        return;
      }
      try {
        if (!reverse) {
          await controller.setPlaybackSpeed(multiplier.toDouble());
          return;
        }
        await controller.pause();
        if (_disposed || generation != _generation) {
          return;
        }
        final origin = controller.playbackInfo!.position;
        final startedAt = _now();
        void scheduleSeek() {
          _timer = Timer(const Duration(milliseconds: 100), () {
            unawaited(
              _enqueue(() async {
                if (_disposed || generation != _generation) {
                  return;
                }
                final elapsed = _now().difference(startedAt).inMilliseconds;
                final position = (origin - elapsed * multiplier).clamp(0, origin);
                try {
                  await controller.seekTo(position);
                } catch (_) {
                  unawaited(stop());
                  rethrow;
                }
                if (!_disposed && generation == _generation && position > 0) {
                  scheduleSeek();
                }
              }),
            );
          });
        }

        scheduleSeek();
      } catch (_) {
        unawaited(stop());
        rethrow;
      }
    });
  }

  /// Cancels immediately; native operations finish in order, including an in-flight seek.
  Future<void> stop({bool resume = true}) {
    final reverse = isReversing;
    final active = isActive;
    final generation = ++_generation;
    _timer?.cancel();
    _speed = 0;
    if (active && !_disposed) {
      onSpeedChanged(0);
    }
    return _enqueue(() async {
      if (!active) {
        return;
      }
      await controller.setPlaybackSpeed(1);
      if (reverse && resume && !_disposed && generation == _generation) {
        await controller.play();
      }
    });
  }

  void dispose() {
    _disposed = true;
    unawaited(stop(resume: false));
  }
}
