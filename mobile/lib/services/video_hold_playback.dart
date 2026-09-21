import 'dart:async';

import 'package:logging/logging.dart';
import 'package:native_video_player/native_video_player.dart';

/// Temporary fast playback while the video is held.
class VideoHoldPlayback {
  static final _log = Logger('VideoHoldPlayback');
  static const speeds = [2, 5, 10];

  final NativeVideoPlayerController controller;
  final void Function(int speed) onSpeedChanged;
  Future<void> _pending = Future.value();
  int _generation = 0;
  int _speed = 0;
  bool _disposed = false;

  VideoHoldPlayback(this.controller, {required this.onSpeedChanged});

  bool get isActive => _speed != 0;

  Future<void> _enqueue(Future<void> Function() action) {
    return _pending = _pending.then((_) => action()).catchError((Object error, StackTrace stack) {
      _log.warning('Error changing temporary video playback', error, stack);
    });
  }

  Future<void> start({required int speed}) {
    if (_disposed || isActive || controller.playbackInfo?.status != PlaybackStatus.playing) {
      return Future.value();
    }
    final multiplier = speeds.contains(speed) ? speed : 2;
    final generation = ++_generation;
    _speed = multiplier;
    onSpeedChanged(_speed);
    return _enqueue(() async {
      if (_disposed || generation != _generation) {
        return;
      }
      try {
        await controller.setPlaybackSpeed(multiplier.toDouble());
      } catch (_) {
        unawaited(stop());
        rethrow;
      }
    });
  }

  /// Cancels immediately while letting pending native speed changes finish in order.
  Future<void> stop() {
    final active = isActive;
    ++_generation;
    _speed = 0;
    if (active && !_disposed) {
      onSpeedChanged(0);
    }
    return _enqueue(() async {
      if (!active) {
        return;
      }
      await controller.setPlaybackSpeed(1);
    });
  }

  void dispose() {
    _disposed = true;
    unawaited(stop());
  }
}
