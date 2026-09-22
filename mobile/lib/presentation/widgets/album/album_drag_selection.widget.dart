import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class AlbumDragSelectionRegion extends StatefulWidget {
  final Widget child;
  final ValueChanged<int> onStart;
  final ValueChanged<int> onAlbumEnter;
  final VoidCallback onEnd;
  final ValueChanged<ScrollDirection> onScroll;

  const AlbumDragSelectionRegion({
    super.key,
    required this.child,
    required this.onStart,
    required this.onAlbumEnter,
    required this.onEnd,
    required this.onScroll,
  });

  @override
  State<AlbumDragSelectionRegion> createState() => _AlbumDragSelectionRegionState();
}

class _AlbumDragSelectionRegionState extends State<AlbumDragSelectionRegion> {
  static const _scrollAreaFraction = 0.10;

  int? _albumUnderPointer;
  int? _anchorAlbum;
  double? _topScrollOffset;
  double? _bottomScrollOffset;
  Timer? _scrollTimer;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      gestures: {
        _AlbumLongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<_AlbumLongPressGestureRecognizer>(
          _AlbumLongPressGestureRecognizer.new,
          (recognizer) {
            recognizer
              ..onLongPressStart = _onLongPressStart
              ..onLongPressMoveUpdate = _onLongPressMove
              ..onLongPressUp = _onLongPressEnd
              ..onLongPressCancel = _onLongPressEnd;
          },
        ),
      },
      child: widget.child,
    );
  }

  int? _getAlbumIndexAt(Offset globalPosition) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return null;
    }

    final result = BoxHitTestResult();
    if (!box.hitTest(result, position: box.globalToLocal(globalPosition))) {
      return null;
    }

    return (result.path.firstWhereOrNull((entry) => entry.target is _AlbumIndexProxy)?.target as _AlbumIndexProxy?)
        ?.index;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final height = context.size?.height;
    if (height != null) {
      _topScrollOffset = height * _scrollAreaFraction;
      _bottomScrollOffset = height - _topScrollOffset!;
    }

    final index = _getAlbumIndexAt(details.globalPosition);
    _anchorAlbum = index;
    _albumUnderPointer = index;
    if (index != null) {
      widget.onStart(index);
    }
  }

  void _onLongPressMove(LongPressMoveUpdateDetails details) {
    if (_anchorAlbum == null || _topScrollOffset == null || _bottomScrollOffset == null) {
      return;
    }

    final dy = details.localPosition.dy;
    if (dy > _bottomScrollOffset!) {
      _startScrolling(ScrollDirection.forward);
    } else if (dy < _topScrollOffset!) {
      _startScrolling(ScrollDirection.reverse);
    } else {
      _stopScrolling();
    }

    final index = _getAlbumIndexAt(details.globalPosition);
    if (index != null && index != _albumUnderPointer) {
      _albumUnderPointer = index;
      widget.onAlbumEnter(index);
    }
  }

  void _startScrolling(ScrollDirection direction) {
    _scrollTimer ??= Timer.periodic(const Duration(milliseconds: 50), (_) => widget.onScroll(direction));
  }

  void _stopScrolling() {
    _scrollTimer?.cancel();
    _scrollTimer = null;
  }

  void _onLongPressEnd() {
    _stopScrolling();
    _anchorAlbum = null;
    _albumUnderPointer = null;
    widget.onEnd();
  }
}

class _AlbumLongPressGestureRecognizer extends LongPressGestureRecognizer {
  @override
  void rejectGesture(int pointer) => acceptGesture(pointer);
}

class AlbumIndexWrapper extends SingleChildRenderObjectWidget {
  final int index;

  const AlbumIndexWrapper({super.key, required this.index, required super.child});

  @override
  // ignore: library_private_types_in_public_api
  _AlbumIndexProxy createRenderObject(BuildContext context) => _AlbumIndexProxy(index);

  @override
  // ignore: library_private_types_in_public_api
  void updateRenderObject(BuildContext context, _AlbumIndexProxy renderObject) {
    renderObject.index = index;
  }
}

class _AlbumIndexProxy extends RenderProxyBox {
  int index;

  _AlbumIndexProxy(this.index);
}
