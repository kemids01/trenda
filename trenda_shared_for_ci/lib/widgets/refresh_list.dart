// trenda_shared/lib/widgets/refresh_list.dart
// ============================================================================
// REFRESH LIST - Pull-to-refresh and infinite scroll widgets
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'shimmer_loading.dart';

// ============================================================================
// REFRESHABLE LIST
// Wraps content with pull-to-refresh functionality
// ============================================================================

class RefreshableList extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  final Color? indicatorColor;
  final double displacement;

  const RefreshableList({
    super.key,
    required this.child,
    required this.onRefresh,
    this.indicatorColor,
    this.displacement = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: indicatorColor ?? Theme.of(context).colorScheme.primary,
      displacement: displacement,
      child: child,
    );
  }
}

// ============================================================================
// PAGINATED LIST VIEW
// List with infinite scroll pagination
// ============================================================================

class PaginatedListView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onLoadMore;
  final Future<void> Function()? onRefresh;
  final bool hasMore;
  final bool isLoading;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final Widget? errorWidget;
  final Object? error;
  final VoidCallback? onRetry;
  final EdgeInsets padding;
  final double loadMoreThreshold;
  final Widget? separator;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.hasMore = true,
    this.isLoading = false,
    this.loadingWidget,
    this.emptyWidget,
    this.errorWidget,
    this.error,
    this.onRetry,
    this.padding = EdgeInsets.zero,
    this.loadMoreThreshold = 200,
    this.separator,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Error state
    if (widget.error != null && widget.items.isEmpty) {
      return widget.errorWidget ??
          _DefaultErrorWidget(error: widget.error!, onRetry: widget.onRetry);
    }

    // Loading state (initial)
    if (widget.isLoading && widget.items.isEmpty) {
      return widget.loadingWidget ?? const ShimmerList(itemCount: 5);
    }

    // Empty state
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const _DefaultEmptyWidget();
    }

    // List with items
    Widget listView = ListView.separated(
      controller: _scrollController,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      shrinkWrap: widget.shrinkWrap,
      padding: widget.padding,
      itemCount: widget.items.length + (widget.hasMore ? 1 : 0),
      separatorBuilder: (_, __) =>
          widget.separator ?? const SizedBox(height: 8),
      itemBuilder: (context, index) {
        // Load more indicator
        if (index == widget.items.length) {
          return _LoadMoreIndicator(isLoading: _isLoadingMore);
        }

        return widget.itemBuilder(context, widget.items[index], index);
      },
    );

    // Wrap with refresh if provided
    if (widget.onRefresh != null) {
      listView = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        child: listView,
      );
    }

    return listView;
  }
}

// ============================================================================
// PAGINATED GRID VIEW
// Grid with infinite scroll pagination
// ============================================================================

class PaginatedGridView<T> extends StatefulWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final Future<void> Function() onLoadMore;
  final Future<void> Function()? onRefresh;
  final bool hasMore;
  final bool isLoading;
  final Widget? loadingWidget;
  final Widget? emptyWidget;
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final EdgeInsets padding;
  final double loadMoreThreshold;
  final ScrollController? controller;

  const PaginatedGridView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    this.onRefresh,
    this.hasMore = true,
    this.isLoading = false,
    this.loadingWidget,
    this.emptyWidget,
    this.crossAxisCount = 2,
    this.crossAxisSpacing = 16,
    this.mainAxisSpacing = 16,
    this.childAspectRatio = 0.75,
    this.padding = const EdgeInsets.all(16),
    this.loadMoreThreshold = 200,
    this.controller,
  });

  @override
  State<PaginatedGridView<T>> createState() => _PaginatedGridViewState<T>();
}

class _PaginatedGridViewState<T> extends State<PaginatedGridView<T>> {
  late ScrollController _scrollController;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.controller ?? ScrollController();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _onScroll() {
    if (_isLoadingMore || !widget.hasMore) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;

    if (maxScroll - currentScroll <= widget.loadMoreThreshold) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);
    try {
      await widget.onLoadMore();
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state (initial)
    if (widget.isLoading && widget.items.isEmpty) {
      return widget.loadingWidget ??
          ShimmerGrid(
            crossAxisCount: widget.crossAxisCount,
            itemCount: 6,
            padding: widget.padding,
          );
    }

    // Empty state
    if (widget.items.isEmpty) {
      return widget.emptyWidget ?? const _DefaultEmptyWidget();
    }

    Widget content = CustomScrollView(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: widget.padding,
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: widget.crossAxisCount,
              crossAxisSpacing: widget.crossAxisSpacing,
              mainAxisSpacing: widget.mainAxisSpacing,
              childAspectRatio: widget.childAspectRatio,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) =>
                  widget.itemBuilder(context, widget.items[index], index),
              childCount: widget.items.length,
            ),
          ),
        ),
        if (widget.hasMore)
          SliverToBoxAdapter(
            child: _LoadMoreIndicator(isLoading: _isLoadingMore),
          ),
      ],
    );

    if (widget.onRefresh != null) {
      content = RefreshIndicator(onRefresh: widget.onRefresh!, child: content);
    }

    return content;
  }
}

// ============================================================================
// HELPER WIDGETS
// ============================================================================

class _LoadMoreIndicator extends StatelessWidget {
  final bool isLoading;

  const _LoadMoreIndicator({required this.isLoading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _DefaultEmptyWidget extends StatelessWidget {
  const _DefaultEmptyWidget();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No items yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultErrorWidget extends StatelessWidget {
  final Object error;
  final VoidCallback? onRetry;

  const _DefaultErrorWidget({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Something went wrong', style: theme.textTheme.titleMedium),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PAGINATION STATE
// Helper class to manage pagination state
// ============================================================================

class PaginationState<T> {
  final List<T> items;
  final int page;
  final int totalPages;
  final bool isLoading;
  final Object? error;

  const PaginationState({
    this.items = const [],
    this.page = 1,
    this.totalPages = 1,
    this.isLoading = false,
    this.error,
  });

  bool get hasMore => page < totalPages;
  bool get isEmpty => items.isEmpty && !isLoading;

  PaginationState<T> copyWith({
    List<T>? items,
    int? page,
    int? totalPages,
    bool? isLoading,
    Object? error,
  }) {
    return PaginationState<T>(
      items: items ?? this.items,
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Initial loading state
  factory PaginationState.loading() => const PaginationState(isLoading: true);

  /// Append items to existing list
  PaginationState<T> addItems(List<T> newItems, {int? totalPages}) {
    return copyWith(
      items: [...items, ...newItems],
      page: page + 1,
      totalPages: totalPages ?? this.totalPages,
      isLoading: false,
      error: null,
    );
  }

  /// Replace all items (for refresh)
  PaginationState<T> setItems(List<T> newItems, {int? totalPages}) {
    return copyWith(
      items: newItems,
      page: 1,
      totalPages: totalPages ?? 1,
      isLoading: false,
      error: null,
    );
  }

  /// Set error state
  PaginationState<T> setError(Object error) {
    return copyWith(error: error, isLoading: false);
  }
}
