import 'package:flutter/foundation.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'viewer_config.freezed.dart';

@freezed
abstract class ViewerConfig with _$ViewerConfig {
  const factory ViewerConfig({
    @Default(true) bool loopVideo,
    @Default(false) bool loadOriginalVideo,
    @Default(true) bool autoPlayVideo,
    @Default(2) int holdSpeed,
    @Default(5) int doubleTapSeekSeconds,
    @Default(96.0) double pauseBoxSize,
    @Default(25) int seekEdgePercent,
    @Default(50) int seekTopPercent,
    @Default(48.0) double seekBarWidth,
    @Default(100) int seekBarHeightPercent,
    // Zero uses the responsive size (including any saved percentage).
    @Default(0.0) double seekEdgeWidth,
    @Default(0.0) double seekTopHeight,
    @Default(0.0) double seekBarHeight,
    @Default(false) bool showVideoZoneFrames,
    @Default(false) bool tapToNavigate,
  }) = _ViewerConfig;
}
