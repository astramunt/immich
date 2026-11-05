import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/viewer_bottom_app_bar.widget.dart';
import 'package:immich_mobile/providers/asset_viewer/asset_viewer.provider.dart';
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

    return ViewerControlsVisibility(
      child: SafeArea(
        key: ValueKey(asset.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: AnimatedSwitcher(
            duration: Durations.short4,
            child: details
                ? const SizedBox.shrink()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      for (var i = 0; i < 2; i++)
                        SizedBox(
                          width: kMinInteractiveDimension,
                          height: double.infinity,
                          child: RotatedBox(
                            quarterTurns: 3,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: VideoSeekBar(videoPlayerName: asset.id),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
