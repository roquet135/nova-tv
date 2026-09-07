import 'package:flutter/material.dart';
import '../theme/nova_theme.dart';

/// Une entree de la barre laterale.
class SideItem {
  final String id;
  final String label;
  final int count;

  const SideItem(this.id, this.label, this.count);
}

/// Barre laterale verticale des categories, facon Netflix / IPTV Smarters.
/// Recherche integree, compteur par categorie, defilement fluide.
class CategorySidebar extends StatelessWidget {
  final List<SideItem> items;
  final String selected;
  final ValueChanged<String> onSelect;
  final String title;
  final String query;
  final ValueChanged<String> onQuery;
  final double width;

  const CategorySidebar({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    required this.title,
    required this.query,
    required this.onQuery,
    this.width = 250,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: NovaColors.bg.withOpacity(0.55),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: NovaColors.cyan,
              ),
            ),
          ),

          // Recherche
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              onChanged: onQuery,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                hintStyle:
                    const TextStyle(color: NovaColors.textDim, fontSize: 12),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 34, minHeight: 34),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: NovaColors.surface.withOpacity(0.9),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide:
                      const BorderSide(color: NovaColors.cyan, width: 1.6),
                ),
              ),
            ),
          ),

          // Liste des categories
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                final sel = it.id == selected;
                return _SideTile(
                  item: it,
                  selected: sel,
                  onTap: () => onSelect(it.id),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SideTile extends StatefulWidget {
  final SideItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SideTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SideTile> createState() => _SideTileState();
}

class _SideTileState extends State<_SideTile> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return Focus(
      onFocusChange: (v) => setState(() => _f = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          margin: const EdgeInsets.only(bottom: 3),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
          decoration: BoxDecoration(
            gradient: sel ? NovaColors.brand : null,
            color: sel
                ? null
                : (_f ? NovaColors.surfaceHigh : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: sel ? NovaColors.cyan : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                    color: sel
                        ? Colors.white
                        : (_f ? NovaColors.cyan : NovaColors.text),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${widget.item.count}',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: sel
                      ? Colors.white.withOpacity(0.85)
                      : NovaColors.textDim,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
