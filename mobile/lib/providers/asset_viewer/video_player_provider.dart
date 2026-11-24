import 'dart:async';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/services/video_hold_playback.dart';
import 'package:logging/logging.dart';
import 'package:native_video_player/native_video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'video_player_provider.freezed.dart';

enum VideoPlaybackStatus { paused, playing, buffering, completed }

@freezed
abstract class VideoPlayerState with _$VideoPlayerState {
  const factory VideoPlayerState({
    required Duration position,
    required Duration duration,
    required VideoPlaybackStatus status,
    @Default(0) int holdSpeed,
  }) = _VideoPlayerState;
}

const _defaultState = VideoPlayerState(
  position: Duration.zero,
  duration: Duration.zero,
  status: VideoPlaybackStatus.paused,
);

class _VideoScrub {
  _VideoScrub(this.controller, {required this.resumePlayback});

  final NativeVideoPlayerController controller;
  bool resumePlayback;
  late final Future<void> ready;
  Future<void>? pending;
  bool finishing = false;
  bool previewing = false;
  ({Duration position, bool exact})? next;
}

final videoPlayerProvider = StateNotifierProvider.autoDispose.family<VideoPlayerNotifier, VideoPlayerState, String>((
  ref,
  name,
) {
  return VideoPlayerNotifier();
});

class VideoPlayerNotifier extends StateNotifier<VideoPlayerState> {
  static final _log = Logger('VideoPlayerNotifier');

  VideoPlayerNotifier() : super(_defaultState);

  NativeVideoPlayerController? _controller;
  Timer? _bufferingTimer;
  Timer? _seekTimer;
  Future<void>? _pendingSeek;
  Future<bool>? _pendingFrameStep;
  _VideoScrub? _scrub;
  VideoPlaybackStatus? _holdStatus;
  VideoHoldPlayback? _holdPlayback;

  @override
  void dispose() {
    _holdPlayback?.dispose();
    _bufferingTimer?.cancel();
    _seekTimer?.cancel();
    _scrub = null;
    unawaited(WakelockPlus.disable());
    _controller = null;

    super.dispose();
  }

  void attachController(NativeVideoPlayerController controller) {
    _holdPlayback?.dispose();
    _scrub = null;
    _controller = controller;
    _holdPlayback = VideoHoldPlayback(
      controller,
      onSpeedChanged: (speed) {
        scheduleMicrotask(() {
          if (mounted) {
            state = state.copyWith(holdSpeed: speed);
          }
        });
      },
    );
  }

  Future<void> startHoldPlayback({required int speed}) async {
    if (state.duration == Duration.zero ||
        state.status != VideoPlaybackStatus.playing ||
        (_seekTimer?.isActive ?? false) ||
        _scrub != null) {
      return;
    }
    await _holdPlayback?.start(speed: speed);
  }

  Future<void> stopHoldPlayback() async {
    await _holdPlayback?.stop();
  }

  Future<void> load(VideoSource source) async {
    _startBufferingTimer();
    try {
      await _controller?.loadVideoSource(source);
    } catch (e) {
      _log.severe('Error loading video source: $e');
    }
  }

  Future<void> pause() async {
    _scrub?.resumePlayback = false;
    await stopHoldPlayback();
    if (_controller == null) {
      return;
    }

    _bufferingTimer?.cancel();

    try {
      await _controller!.pause();
      await _flushSeek();
    } catch (e) {
      _log.severe('Error pausing video: $e');
    }
  }

  Future<void> play() async {
    final scrub = _scrub;
    if (scrub != null) {
      if (!scrub.finishing) {
        return;
      }
      await scrub.pending;
    }
    await _pendingFrameStep;
    await stopHoldPlayback();
    if (_controller == null || _scrub != null) {
      return;
    }

    try {
      await _flushSeek();
      await _controller!.play();
    } catch (e) {
      _log.severe('Error playing video: $e');
    }

    _startBufferingTimer();
  }

  Future<void> _flushSeek() async {
    final timer = _seekTimer;
    if (timer != null && timer.isActive) {
      timer.cancel();
      await _seekToNative();
    } else {
      await _pendingSeek;
    }
  }

  Future<void> _seekToNative() async {
    try {
      await _controller?.seekTo(state.position.inMilliseconds);
    } catch (error, stack) {
      _log.warning('Error seeking video', error, stack);
    }
  }

  void beginScrub() {
    final controller = _controller;
    final previous = _scrub;
    if (controller == null || state.duration <= Duration.zero || previous?.finishing == false) {
      return;
    }

    final wasPlaying = state.status == VideoPlaybackStatus.playing || state.status == VideoPlaybackStatus.buffering;
    final scrub = _VideoScrub(controller, resumePlayback: previous?.resumePlayback ?? wasPlaying);
    _scrub = scrub;
    _seekTimer?.cancel();
    scrub.ready = _prepareScrub(scrub, previous?.pending, _pendingFrameStep);
  }

  Future<void> _prepareScrub(_VideoScrub scrub, Future<void>? previous, Future<bool>? frameStep) async {
    await previous;
    await frameStep;
    await _pendingSeek;
    await stopHoldPlayback();
    if (!identical(_scrub, scrub)) {
      return;
    }

    _bufferingTimer?.cancel();
    try {
      await scrub.controller.pause();
    } catch (error, stack) {
      _log.warning('Error pausing video for scrubbing', error, stack);
    }
  }

  void previewScrub(Duration position) {
    final scrub = _scrub;
    if (scrub == null || scrub.finishing || state.position == position) {
      return;
    }
    _queueScrub(scrub, position, exact: false);
  }

  Future<void> finishScrub(Duration position) async {
    final scrub = _scrub;
    if (scrub == null || scrub.finishing) {
      return;
    }
    scrub.finishing = true;
    _queueScrub(scrub, position, exact: true);
    if (scrub.previewing) {
      // Supersede the last approximate request once, when the finger lifts.
      try {
        await scrub.controller.cancelPendingPreview();
      } catch (error, stack) {
        _log.warning('Error canceling scrub preview', error, stack);
      }
    }
    await scrub.pending;
  }

  void _queueScrub(_VideoScrub scrub, Duration position, {required bool exact}) {
    state = state.copyWith(position: position);
    // Keep only the latest thumb position while the native decoder works.
    scrub.next = (position: position, exact: exact);
    scrub.pending ??= _drainScrub(scrub);
  }

  Future<void> _drainScrub(_VideoScrub scrub) async {
    try {
      await scrub.ready;
      while (identical(_scrub, scrub) && scrub.next != null) {
        final target = scrub.next!;
        scrub.next = null;
        final milliseconds = target.position.inMilliseconds;
        if (target.exact) {
          await scrub.controller.seekTo(milliseconds);
          if (identical(_scrub, scrub) && scrub.resumePlayback) {
            await scrub.controller.play();
          }
        } else {
          scrub.previewing = true;
          try {
            await scrub.controller.seekPreview(milliseconds);
          } catch (error, stack) {
            _log.warning('Error previewing scrub position', error, stack);
          } finally {
            scrub.previewing = false;
          }
        }
      }
    } catch (error, stack) {
      _log.warning('Error settling video after scrubbing', error, stack);
    } finally {
      scrub.pending = null;
      if (identical(_scrub, scrub) && scrub.finishing) {
        _scrub = null;
        onNativePositionChanged();
      }
    }
  }

  Future<bool> stepFrame({required bool forward}) {
    final controller = _controller;
    final scrub = _scrub;
    if (controller == null || state.duration == Duration.zero || scrub?.finishing == false) {
      return Future.value(true);
    }

    scrub?.resumePlayback = false;
    return _pendingFrameStep = _stepFrame(
      controller,
      after: _pendingFrameStep,
      scrub: scrub?.pending,
      forward: forward,
    );
  }

  Future<bool> _stepFrame(
    NativeVideoPlayerController controller, {
    required Future<bool>? after,
    required Future<void>? scrub,
    required bool forward,
  }) async {
    await after;
    await scrub;
    if (!mounted || _controller != controller || _scrub != null) {
      return true;
    }

    _holdStatus = null;
    try {
      await pause();
      if (!mounted || _controller != controller) {
        return true;
      }
      return await controller.stepFrame(forward: forward);
    } catch (error, stack) {
      _log.warning('Error stepping through video', error, stack);
      return false;
    }
  }

  void seekTo(Duration position) {
    if (_controller == null || state.position == position || _scrub != null) {
      return;
    }

    state = state.copyWith(position: position);

    if (_seekTimer?.isActive ?? false) {
      return;
    }

    _seekTimer = Timer(const Duration(milliseconds: 150), () {
      _pendingSeek = _seekToNative();
    });
  }

  void seekBy(Duration offset) {
    if (state.duration == Duration.zero) {
      return;
    }
    final target = state.position + offset;
    seekTo(
      target < Duration.zero
          ? Duration.zero
          : target > state.duration
          ? state.duration
          : target,
    );
  }

  void toggle() {
    if (_scrub != null) {
      return;
    }
    _holdStatus = null;

    switch (state.status) {
      case VideoPlaybackStatus.paused:
        unawaited(play());
      case VideoPlaybackStatus.playing || VideoPlaybackStatus.buffering:
        unawaited(pause());
      case VideoPlaybackStatus.completed:
        unawaited(restart());
    }
  }

  /// Pauses playback and preserves the current status for later restoration.
  void hold() {
    if (_holdStatus != null) {
      return;
    }

    _holdStatus = _holdPlayback?.isActive == true ? VideoPlaybackStatus.playing : state.status;
    unawaited(pause());
  }

  /// Restores playback to the status before [hold] was called.
  void release() {
    final status = _holdStatus;
    _holdStatus = null;

    switch (status) {
      case VideoPlaybackStatus.playing || VideoPlaybackStatus.buffering:
        unawaited(play());
      default:
    }
  }

  Future<void> restart() async {
    seekTo(Duration.zero);
    await play();
  }

  Future<void> setVolume(double volume) async {
    try {
      await _controller?.setVolume(volume);
    } catch (e) {
      _log.severe('Error setting volume: $e');
    }
  }

  Future<void> setLoop(bool loop) async {
    try {
      await _controller?.setLoop(loop);
    } catch (e) {
      _log.severe('Error setting loop: $e');
    }
  }

  void onNativePlaybackReady() {
    if (!mounted) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    final videoInfo = _controller?.videoInfo;

    if (playbackInfo == null || videoInfo == null) {
      return;
    }

    var status = _mapStatus(playbackInfo.status);
    if (playbackInfo.status == PlaybackStatus.stopped && state.status != VideoPlaybackStatus.completed) {
      // Never played yet, not completed = we show the resume button instead of the replay button
      status = VideoPlaybackStatus.paused;
    }

    if (status != VideoPlaybackStatus.playing) {
      // No playback = no loading indicator needed
      _bufferingTimer?.cancel();
    }

    state = state.copyWith(
      position: _scrub == null ? Duration(milliseconds: playbackInfo.position) : state.position,
      duration: Duration(milliseconds: videoInfo.duration),
      status: status,
    );
  }

  void onNativePositionChanged() {
    if (!mounted || (_seekTimer?.isActive ?? false) || _scrub != null) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo == null) {
      return;
    }

    final position = Duration(milliseconds: playbackInfo.position);
    if (state.position == position) {
      return;
    }

    if (state.status == VideoPlaybackStatus.playing) {
      _startBufferingTimer();
    }

    state = state.copyWith(
      position: position,
      status: state.status == VideoPlaybackStatus.buffering ? VideoPlaybackStatus.playing : state.status,
    );
  }

  void onNativeStatusChanged() {
    if (!mounted) {
      return;
    }

    final playbackInfo = _controller?.playbackInfo;
    if (playbackInfo == null) {
      return;
    }

    final newStatus = _mapStatus(playbackInfo.status);
    if (newStatus == VideoPlaybackStatus.completed) {
      unawaited(stopHoldPlayback());
    }
    switch (newStatus) {
      case VideoPlaybackStatus.playing:
        unawaited(WakelockPlus.enable());
        _startBufferingTimer();
      default:
        onNativePlaybackEnded();
    }

    if (state.status != newStatus) {
      state = state.copyWith(status: newStatus);
    }
  }

  void onNativePlaybackEnded() {
    unawaited(WakelockPlus.disable());
    _bufferingTimer?.cancel();
  }

  void _startBufferingTimer() {
    _bufferingTimer?.cancel();
    _bufferingTimer = Timer(const Duration(seconds: 1), () {
      if (mounted && state.status != VideoPlaybackStatus.completed) {
        state = state.copyWith(status: VideoPlaybackStatus.buffering);
      }
    });
  }

  static VideoPlaybackStatus _mapStatus(PlaybackStatus status) => switch (status) {
    PlaybackStatus.playing => VideoPlaybackStatus.playing,
    PlaybackStatus.paused => VideoPlaybackStatus.paused,
    PlaybackStatus.stopped => VideoPlaybackStatus.completed,
  };
}
