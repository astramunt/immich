import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/services/video_hold_playback.dart';
import 'package:mocktail/mocktail.dart';
import 'package:native_video_player/native_video_player.dart';

class MockVideoController extends Mock implements NativeVideoPlayerController {}

class MockPlaybackInfo extends Mock implements PlaybackInfo {}

void main() {
  late MockVideoController controller;
  late MockPlaybackInfo playback;
  late List<int> speeds;

  setUp(() {
    controller = MockVideoController();
    playback = MockPlaybackInfo();
    speeds = [];
    when(() => controller.playbackInfo).thenReturn(playback);
    when(() => playback.status).thenReturn(PlaybackStatus.playing);
    when(() => playback.position).thenReturn(10000);
    when(() => controller.setPlaybackSpeed(any())).thenAnswer((_) async {});
    when(() => controller.pause()).thenAnswer((_) async {});
    when(() => controller.play()).thenAnswer((_) async {});
    when(() => controller.seekTo(any())).thenAnswer((_) async {});
  });

  for (final speed in VideoHoldPlayback.speeds) {
    test('holding forward at ×$speed restores normal speed on release', () async {
      final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
      await hold.start(reverse: false, speed: speed);
      await hold.stop();
      verifyInOrder([() => controller.setPlaybackSpeed(speed.toDouble()), () => controller.setPlaybackSpeed(1)]);
      verifyNever(() => controller.pause());
      expect(speeds, [speed, 0]);
      hold.dispose();
    });

    test('rewinds at ×$speed and resumes from the new position on release', () {
      fakeAsync((async) {
        final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add, now: async.getClock(DateTime(2026)).now);
        unawaited(hold.start(reverse: true, speed: speed));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 300));
        verify(() => controller.seekTo(10000 - 300 * speed)).called(1);
        unawaited(hold.stop());
        async.flushMicrotasks();
        verifyInOrder([() => controller.pause(), () => controller.setPlaybackSpeed(1), () => controller.play()]);
        expect(speeds, [-speed, 0]);
        clearInteractions(controller);
        async.elapse(const Duration(seconds: 1));
        verifyNever(() => controller.seekTo(any()));
        hold.dispose();
        async.flushMicrotasks();
      });
    });
  }

  test('does not activate before playback starts', () async {
    when(() => playback.status).thenReturn(PlaybackStatus.paused);
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(reverse: true, speed: 2);
    expect(speeds, isEmpty);
    verifyNever(() => controller.pause());
    hold.dispose();
  });

  test('rewind clamps at zero and stays there until release', () {
    fakeAsync((async) {
      when(() => playback.position).thenReturn(50);
      final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add, now: async.getClock(DateTime(2026)).now);
      unawaited(hold.start(reverse: true, speed: 10));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      verify(() => controller.seekTo(0)).called(1);
      verifyNever(() => controller.play());
      unawaited(hold.stop());
      async.flushMicrotasks();
      verify(() => controller.play()).called(1);
      hold.dispose();
      async.flushMicrotasks();
    });
  });

  test('release during activation restores speed after the pending change', () async {
    final pending = Completer<void>();
    when(() => controller.setPlaybackSpeed(10)).thenAnswer((_) => pending.future);
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    final start = hold.start(reverse: false, speed: 10);
    await Future<void>.delayed(Duration.zero);
    final stop = hold.stop();
    pending.complete();
    await Future.wait([start, stop]);
    verifyInOrder([() => controller.setPlaybackSpeed(10), () => controller.setPlaybackSpeed(1)]);
    expect(hold.isActive, isFalse);
    hold.dispose();
  });

  test('a pending rewind seek finishes before resuming and never overlaps another seek', () {
    fakeAsync((async) {
      final pending = Completer<void>();
      when(() => controller.seekTo(any())).thenAnswer((_) => pending.future);
      final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add, now: async.getClock(DateTime(2026)).now);
      unawaited(hold.start(reverse: true, speed: 5));
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 1));
      verify(() => controller.seekTo(any())).called(1);
      unawaited(hold.stop());
      async.flushMicrotasks();
      verifyNever(() => controller.play());
      pending.complete();
      async.flushMicrotasks();
      verify(() => controller.play()).called(1);
      hold.dispose();
      async.flushMicrotasks();
    });
  });

  test('leaving the viewer cancels a pending release without resuming playback', () async {
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(reverse: true, speed: 2);
    final release = hold.stop();
    final cancel = hold.stop(resume: false);
    await Future.wait([release, cancel]);
    verifyNever(() => controller.play());
    hold.dispose();
  });

  test('disposal cancels reverse timers without resuming playback', () {
    fakeAsync((async) {
      final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
      unawaited(hold.start(reverse: true, speed: 2));
      async.flushMicrotasks();
      hold.dispose();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      verifyNever(() => controller.seekTo(any()));
      verifyNever(() => controller.play());
    });
  });

  test('invalid saved speed falls back to ×2', () async {
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(reverse: false, speed: -5);
    verify(() => controller.setPlaybackSpeed(2)).called(1);
    await hold.stop();
    hold.dispose();
  });

  test('failed speed change clears the indicator and restores normal speed', () async {
    when(() => controller.setPlaybackSpeed(5)).thenThrow(StateError('Playback unavailable'));
    final hold = VideoHoldPlayback(controller, onSpeedChanged: speeds.add);
    await hold.start(reverse: false, speed: 5);
    await hold.stop(resume: false);
    expect(speeds, [5, 0]);
    verify(() => controller.setPlaybackSpeed(1)).called(1);
    hold.dispose();
  });
}
