import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/services/video_hold_playback.dart';
import 'package:immich_ui/immich_ui.dart';

class VideoViewerSettings extends HookConsumerWidget {
  const VideoViewerSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewer = ref.watch(appConfigProvider).viewer;
    final useAutoPlayVideo = useState(viewer.autoPlayVideo);
    final useLoopVideo = useState(viewer.loopVideo);
    final useOriginalVideo = useState(viewer.loadOriginalVideo);

    useValueChanged<bool, void>(useAutoPlayVideo.value, (_, _) {
      unawaited(ref.read(settingsProvider).write(.viewerAutoPlayVideo, useAutoPlayVideo.value));
    });
    useValueChanged<bool, void>(useLoopVideo.value, (_, _) {
      unawaited(ref.read(settingsProvider).write(.viewerLoopVideo, useLoopVideo.value));
    });
    useValueChanged<bool, void>(useOriginalVideo.value, (_, _) {
      unawaited(ref.read(settingsProvider).write(.viewerLoadOriginalVideo, useOriginalVideo.value));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingGroupTitle(title: context.t.videos, icon: Icons.video_camera_back_outlined),
        SettingsSwitchListTile(
          valueNotifier: useAutoPlayVideo,
          title: context.t.setting_video_viewer_auto_play_title,
          subtitle: context.t.setting_video_viewer_auto_play_subtitle,
        ),
        SettingsSwitchListTile(
          valueNotifier: useLoopVideo,
          title: context.t.setting_video_viewer_looping_title,
          subtitle: context.t.loop_videos_description,
        ),
        _VideoOptionDropdown(
          title: context.t.setting_video_hold_speed_title,
          subtitle: context.t.setting_video_hold_speed_subtitle,
          value: viewer.holdSpeed,
          values: VideoHoldPlayback.speeds,
          label: (value) => '×$value',
          onChanged: (speed) => unawaited(ref.read(settingsProvider).write(.viewerHoldSpeed, speed)),
        ),
        _VideoOptionDropdown(
          title: context.t.setting_video_double_tap_seek_title,
          subtitle: context.t.setting_video_double_tap_seek_subtitle,
          value: viewer.doubleTapSeekSeconds,
          values: const [5, 10, 20],
          label: (value) => '$value s',
          onChanged: (seconds) => unawaited(ref.read(settingsProvider).write(.viewerDoubleTapSeekSeconds, seconds)),
        ),
        SettingsSwitchListTile(
          valueNotifier: useOriginalVideo,
          title: context.t.setting_video_viewer_original_video_title,
          subtitle: context.t.setting_video_viewer_original_video_subtitle,
        ),
      ],
    );
  }
}

class _VideoOptionDropdown extends StatelessWidget {
  final String title;
  final String subtitle;
  final int value;
  final List<int> values;
  final String Function(int value) label;
  final ValueChanged<int> onChanged;

  const _VideoOptionDropdown({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          items: values.map((value) => DropdownMenuItem(value: value, child: Text(label(value)))).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}
