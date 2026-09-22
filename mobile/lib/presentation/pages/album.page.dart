import 'dart:async';
import 'dart:math' as math;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/album/album.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/album/album_delete_dialog.widget.dart';
import 'package:immich_mobile/presentation/widgets/album/album_drag_selection.widget.dart';
import 'package:immich_mobile/presentation/widgets/album/album_selector.widget.dart';
import 'package:immich_mobile/providers/infrastructure/album.provider.dart';
import 'package:immich_mobile/providers/user.provider.dart';
import 'package:immich_mobile/routing/router.dart';
import 'package:immich_mobile/widgets/common/immich_sliver_app_bar.dart';
import 'package:immich_mobile/widgets/common/immich_toast.dart';

@RoutePage()
class AlbumsPage extends ConsumerStatefulWidget {
  const AlbumsPage({super.key});

  @override
  ConsumerState<AlbumsPage> createState() => _AlbumsPageState();
}

class _AlbumsPageState extends ConsumerState<AlbumsPage> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _selectedAlbumIds = {};
  final Set<String> _selectionBeforeDrag = {};
  List<RemoteAlbum> _shownAlbums = const [];
  int? _dragAnchorIndex;
  ScrollPhysics? _scrollPhysics;

  Future<void> onRefresh() async {
    await ref.read(remoteAlbumProvider.notifier).refresh();
  }

  bool _isOwned(RemoteAlbum album) => album.ownerId == ref.read(currentUserProvider)?.id;

  void _clearSelection() {
    setState(_selectedAlbumIds.clear);
  }

  void _toggleAlbum(RemoteAlbum album) {
    if (!_isOwned(album)) {
      return;
    }
    setState(() {
      if (!_selectedAlbumIds.add(album.id)) {
        _selectedAlbumIds.remove(album.id);
      }
    });
  }

  void _startDragSelection(int index) {
    if (index < 0 || index >= _shownAlbums.length || !_isOwned(_shownAlbums[index])) {
      return;
    }

    setState(() {
      _selectionBeforeDrag
        ..clear()
        ..addAll(_selectedAlbumIds);
      _dragAnchorIndex = index;
      _scrollPhysics = const ClampingScrollPhysics();
      _selectedAlbumIds.add(_shownAlbums[index].id);
    });
  }

  void _updateDragSelection(int index) {
    final anchor = _dragAnchorIndex;
    if (anchor == null || index < 0 || index >= _shownAlbums.length) {
      return;
    }

    final start = math.min(anchor, index);
    final end = math.max(anchor, index);
    final range = _shownAlbums.sublist(start, end + 1).where(_isOwned).map((album) => album.id);

    setState(() {
      _selectedAlbumIds
        ..clear()
        ..addAll(_selectionBeforeDrag)
        ..addAll(range);
    });
  }

  void _endDragSelection() {
    _dragAnchorIndex = null;
    _selectionBeforeDrag.clear();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _scrollPhysics = null);
      }
    });
  }

  void _scrollWhileSelecting(ScrollDirection direction) {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    final delta = direction == ScrollDirection.forward ? 175.0 : -175.0;
    final target = (_scrollController.offset + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    unawaited(_scrollController.animateTo(target, duration: const Duration(milliseconds: 125), curve: Curves.easeOut));
  }

  Future<void> _deleteSelectedAlbums() async {
    final albums = ref
        .read(remoteAlbumProvider)
        .albums
        .where((album) => _selectedAlbumIds.contains(album.id) && _isOwned(album))
        .toList(growable: false);
    if (albums.isEmpty) {
      return;
    }

    final action = await showAlbumDeleteDialog(context, albums);
    if (action == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(remoteAlbumProvider.notifier)
          .deleteAlbums(albums, trashContents: action == AlbumDeleteAction.albumAndContents);
      if (!mounted) {
        return;
      }
      _clearSelection();
      ImmichToast.show(
        context: context,
        msg: context.t.albums_deleted(count: albums.length),
        toastType: ToastType.success,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ImmichToast.show(
        context: context,
        msg: context.t.album_viewer_appbar_share_err_delete,
        toastType: ToastType.error,
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final albumCount = ref.watch(remoteAlbumProvider.select((state) => state.albums.length));
    final showScrollbar = albumCount > 20;
    final isSelecting = _selectedAlbumIds.isNotEmpty;

    final scrollView = CustomScrollView(
      controller: _scrollController,
      physics: _scrollPhysics ?? const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (isSelecting)
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _clearSelection),
            title: Text(context.t.selected_count(count: _selectedAlbumIds.length)),
            actions: [
              IconButton(
                tooltip: context.t.delete_album,
                onPressed: _deleteSelectedAlbums,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          )
        else
          ImmichSliverAppBar(
            snap: false,
            floating: false,
            pinned: true,
            actions: [
              IconButton(
                onPressed: () => context.pushRoute(const CreateAlbumRoute()),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
            showUploadButton: false,
          ),
        AlbumSelector(
          selectedAlbumIds: _selectedAlbumIds,
          onShownAlbumsChanged: (albums) => _shownAlbums = albums,
          onAlbumSelected: (album) {
            if (isSelecting) {
              _toggleAlbum(album);
            } else {
              unawaited(context.router.push(RemoteAlbumRoute(album: album)));
            }
          },
        ),
      ],
    );

    final selectableScrollView = AlbumDragSelectionRegion(
      onStart: _startDragSelection,
      onAlbumEnter: _updateDragSelection,
      onEnd: _endDragSelection,
      onScroll: _scrollWhileSelecting,
      child: scrollView,
    );

    final child = showScrollbar
        ? RawScrollbar(
            controller: _scrollController,
            interactive: true,
            thickness: 8,
            radius: const Radius.circular(4),
            thumbVisibility: false,
            thumbColor: context.colorScheme.primary,
            crossAxisMargin: 4,
            mainAxisMargin: 60,
            minThumbLength: 40,
            child: selectableScrollView,
          )
        : selectableScrollView;

    return PopScope(
      canPop: !isSelecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && isSelecting) {
          _clearSelection();
        }
      },
      child: RefreshIndicator(onRefresh: onRefresh, edgeOffset: 100, child: child),
    );
  }
}
