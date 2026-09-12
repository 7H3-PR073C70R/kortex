import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:kortex/src/core/extensions/theme_extension.dart';
import 'package:kortex/src/core/services/app_feedback_service.dart';
import 'package:kortex/src/features/decks/domain/entities/deck_entity.dart';
import 'package:kortex/src/shared/widgets/app_badge.dart';

/// Hierarchical tree node representing a folder, sub-deck, or tag hierarchy.
class DeckTreeNode {
  DeckTreeNode({
    required this.name,
    required this.path,
    this.deck,
    List<DeckTreeNode>? children,
  }) : children = children ?? [];

  final String name;
  final String path;
  final DeckEntity? deck;
  final List<DeckTreeNode> children;

  int get totalCards =>
      (deck?.totalCards ?? 0) +
      children.fold<int>(0, (sum, child) => sum + child.totalCards);

  bool get isLeaf => children.isEmpty && deck != null;
}

/// Visual tree selector for sub-decks, folders, and hierarchical tags in Kortex.
class SubdeckHierarchyTree extends HookWidget {
  const SubdeckHierarchyTree({
    super.key,
    required this.decks,
    this.selectedDeckId,
    this.onDeckSelected,
    this.onTagSelected,
    this.initialExpanded = true,
  });

  final List<DeckEntity> decks;
  final String? selectedDeckId;
  final ValueChanged<DeckEntity>? onDeckSelected;
  final ValueChanged<String>? onTagSelected;
  final bool initialExpanded;

  /// Builds a tree structure from deck names/tags supporting `/` or `::` hierarchies.
  static List<DeckTreeNode> buildTree(List<DeckEntity> decks) {
    final rootNodes = <String, DeckTreeNode>{};

    for (final deck in decks) {
      final delimiter = deck.title.contains('::')
          ? '::'
          : deck.title.contains('/')
              ? '/'
              : null;

      if (delimiter == null) {
        rootNodes[deck.id] = DeckTreeNode(
          name: deck.title,
          path: deck.title,
          deck: deck,
        );
      } else {
        final segments = deck.title.split(delimiter);
        DeckTreeNode? currentParent;
        var currentPath = '';

        for (var i = 0; i < segments.length; i++) {
          final seg = segments[i].trim();
          currentPath = currentPath.isEmpty ? seg : '$currentPath$delimiter$seg';

          if (i == 0) {
            currentParent = rootNodes.putIfAbsent(
              seg,
              () => DeckTreeNode(name: seg, path: currentPath),
            );
          } else {
            var existingChild = currentParent!.children.firstWhere(
              (c) => c.name == seg,
              orElse: () {
                final newNode = DeckTreeNode(
                  name: seg,
                  path: currentPath,
                  deck: (i == segments.length - 1) ? deck : null,
                );
                currentParent!.children.add(newNode);
                return newNode;
              },
            );
            currentParent = existingChild;
          }
        }
      }
    }

    return rootNodes.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final typography = context.typography;
    final treeNodes = useMemoized(() => buildTree(decks), [decks]);
    final expandedPaths = useState<Set<String>>(
      initialExpanded ? treeNodes.map((n) => n.path).toSet() : <String>{},
    );
    final searchQuery = useState<String>('');

    if (decks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.folder_open_rounded, size: 48, color: colors.textSecondary.withOpacity(0.5)),
              const SizedBox(height: 12),
              Text(
                'No Decks or Sub-Decks Found',
                style: typography.body.medium.copyWith(color: colors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Filter
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onChanged: (val) => searchQuery.value = val.trim().toLowerCase(),
            decoration: InputDecoration(
              hintText: 'Search hierarchy & sub-decks...',
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: colors.textSecondary),
              filled: true,
              fillColor: colors.surfacePrimary,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.surfaceBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.surfaceBorder),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            itemCount: treeNodes.length,
            itemBuilder: (context, index) {
              return _buildTreeNode(
                context: context,
                node: treeNodes[index],
                level: 0,
                expandedPaths: expandedPaths,
                searchFilter: searchQuery.value,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTreeNode({
    required BuildContext context,
    required DeckTreeNode node,
    required int level,
    required ValueNotifier<Set<String>> expandedPaths,
    required String searchFilter,
  }) {
    final colors = context.colors;
    final typography = context.typography;
    final isExpanded = expandedPaths.value.contains(node.path);
    final hasChildren = node.children.isNotEmpty;
    final isSelected = node.deck?.id == selectedDeckId;

    if (searchFilter.isNotEmpty &&
        !node.path.toLowerCase().contains(searchFilter) &&
        !node.children.any((c) => c.path.toLowerCase().contains(searchFilter))) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: '${node.name}, ${node.totalCards} cards',
          button: true,
          selected: isSelected,
          child: InkWell(
            onTap: () {
              AppFeedback.selection();
              if (hasChildren) {
                final next = Set<String>.from(expandedPaths.value);
                if (isExpanded) {
                  next.remove(node.path);
                } else {
                  next.add(node.path);
                }
                expandedPaths.value = next;
              }
              if (node.deck != null) {
                onDeckSelected?.call(node.deck!);
              } else {
                onTagSelected?.call(node.path);
              }
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: EdgeInsets.only(
                left: 12.0 + (level * 20.0),
                right: 12.0,
                top: 8.0,
                bottom: 8.0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.primary.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: colors.primary.withOpacity(0.4))
                    : null,
              ),
              child: Row(
                children: [
                  if (hasChildren)
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 20,
                      color: colors.textSecondary,
                    )
                  else
                    Icon(
                      Icons.style_rounded,
                      size: 18,
                      color: isSelected ? colors.primary : colors.textSecondary,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      node.name,
                      style: typography.body.medium.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? colors.primary : colors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AppBadge(
                    label: '${node.totalCards}',
                    variant: isSelected ? AppBadgeVariant.primary : AppBadgeVariant.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && (isExpanded || searchFilter.isNotEmpty))
          ...node.children.map(
            (child) => _buildTreeNode(
              context: context,
              node: child,
              level: level + 1,
              expandedPaths: expandedPaths,
              searchFilter: searchFilter,
            ),
          ),
      ],
    );
  }
}
