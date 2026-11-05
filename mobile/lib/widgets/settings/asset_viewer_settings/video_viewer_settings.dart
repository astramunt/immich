import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/config/app_config.dart';
import 'package:immich_mobile/domain/models/settings_key.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_zone_frames.widget.dart';
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

        SwitchListTile(
          title: Text(context.t.setting_video_zone_frames_title),
          subtitle: Text(context.t.setting_video_zone_frames_subtitle),
          value: viewer.showVideoZoneFrames,
          onChanged: (value) => unawaited(ref.read(settingsProvider).write(.viewerShowVideoZoneFrames, value)),
        ),
        _VideoSizeTile(
          title: context.t.setting_video_pause_box_size_title,
          subtitle: context.t.setting_video_pause_box_size_subtitle,
          setting: SettingsKey.viewerPauseBoxSize,
        ),
        _VideoSizeTile(
          title: context.t.setting_video_seek_edge_width_title,
          subtitle: context.t.setting_video_seek_edge_width_subtitle,
          setting: SettingsKey.viewerSeekEdgeWidth,
        ),
        _VideoSizeTile(
          title: context.t.setting_video_seek_top_height_title,
          subtitle: context.t.setting_video_seek_top_height_subtitle,
          setting: SettingsKey.viewerSeekTopHeight,
        ),
        _VideoSizeTile(
          title: context.t.setting_video_seek_bar_width_title,
          subtitle: context.t.setting_video_seek_bar_width_subtitle,
          setting: SettingsKey.viewerSeekBarWidth,
        ),
        _VideoSizeTile(
          title: context.t.setting_video_seek_bar_height_title,
          subtitle: context.t.setting_video_seek_bar_height_subtitle,
          setting: SettingsKey.viewerSeekBarHeight,
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

String _dpNumber(double value) => value.toString().replaceFirst(RegExp(r'\.0$'), '');

class _VideoSizeTile extends ConsumerWidget {
  const _VideoSizeTile({required this.title, required this.subtitle, required this.setting});

  final String title;
  final String subtitle;
  final SettingsKey<double> setting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final value = config.read(setting);
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(value == 0 ? context.t.setting_video_zone_auto : '${_dpNumber(value)} dp'),
      onTap: () async {
        final selected = await showDialog<double>(
          context: context,
          builder: (_) => _VideoSizeDialog(title: title, config: config, setting: setting),
        );
        if (selected != null && context.mounted) {
          await ref.read(settingsProvider).write(setting, selected);
        }
      },
    );
  }
}

class _VideoSizeDialog extends HookWidget {
  const _VideoSizeDialog({required this.title, required this.config, required this.setting});

  final String title;
  final AppConfig config;
  final SettingsKey<double> setting;

  @override
  Widget build(BuildContext context) {
    final current = config.read(setting);
    final controller = useTextEditingController(text: current > 0 ? _dpNumber(current) : '');
    final input = useValueListenable(controller).text.trim();
    final parsed = input.isEmpty ? defaultConfig.read(setting) : double.tryParse(input.replaceAll(',', '.'));
    final valid = parsed != null && parsed.isFinite && (input.isEmpty || parsed > 0);
    final screen = MediaQuery.sizeOf(context);
    final viewer = valid ? config.write(setting, parsed).viewer : config.viewer;
    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (viewer.showVideoZoneFrames)
            SizedBox(
              height: 164,
              width: 240,
              child: FittedBox(
                child: SizedBox.fromSize(
                  size: screen,
                  child: ColoredBox(
                    color: Colors.black87,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        VideoZoneFrames(zones: VideoGestureZones(screen, viewer)),
                        Padding(
                          padding: EdgeInsets.only(
                            top: MediaQuery.viewPaddingOf(context).top + kToolbarHeight + 12,
                            bottom: MediaQuery.viewPaddingOf(context).bottom + kBottomNavigationBarHeight + 12,
                          ),
                          child: VideoSideZoneLayout(viewer: viewer, child: const SizedBox.expand()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              suffixText: 'dp',
              helperText: context.t.setting_video_zone_empty,
              errorText: valid ? null : context.t.setting_video_zone_invalid,
            ),
            onSubmitted: (_) {
              if (valid) {
                Navigator.pop(context, parsed);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.t.cancel)),
        TextButton(onPressed: valid ? () => Navigator.pop(context, parsed) : null, child: Text(context.t.save)),
      ],
    );
  }
}
