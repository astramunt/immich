import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_zone_frames.widget.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/viewer_bottom_app_bar.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/widgets/asset_viewer/video_controls.dart';

class VideoSideSeekBars extends ConsumerWidget {
  const VideoSideSeekBars({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetViewerProvider.select((s) => s.currentAsset));
    final details = ref.watch(assetViewerProvider.select((s) => s.showingDetails));
    if (asset == null || !asset.isVideo) {
      return const SizedBox.shrink();
    }

    final viewer = ref.watch(appConfigProvider.select((config) => config.viewer));
    return ViewerControlsVisibility(
      child: SafeArea(
        key: ValueKey(asset.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: AnimatedSwitcher(
            duration: Durations.short4,
            child: details
                ? const SizedBox.shrink()
                : VideoSideZoneLayout(
                    viewer: viewer,
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Directionality(
                        textDirection: TextDirection.ltr,
                        child: VideoSeekBar(videoPlayerName: asset.id),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
