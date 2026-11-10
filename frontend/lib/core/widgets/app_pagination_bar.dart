import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppPaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;
  final Color activeColor;

  const AppPaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    this.pageSize = 10,
    required this.onPageChanged,
    this.activeColor = const Color(0xFF13246E),
  });

  @override
  Widget build(BuildContext context) {
    if (totalItems <= 0) return const SizedBox.shrink();

    final safeTotalPages = math.max(1, totalPages);
    final startItem = (currentPage - 1) * pageSize + 1;
    final endItem = math.min(currentPage * pageSize, totalItems);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        final infoText = Text(
          "Showing $startItem to $endItem of $totalItems entries",
          style: const TextStyle(
            fontSize: 12.5,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        );

        final controls = _buildControls(context, safeTotalPages);

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                infoText,
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: controls,
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              infoText,
              controls,
            ],
          ),
        );
      },
    );
  }

  Widget _buildControls(BuildContext context, int safeTotalPages) {
    final canPrev = currentPage > 1;
    final canNext = currentPage < safeTotalPages;

    final List<Widget> items = [];

    // Previous Button
    items.add(
      InkWell(
        onTap: canPrev ? () => onPageChanged(currentPage - 1) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: canPrev ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canPrev ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chevron_left_rounded,
                size: 18,
                color: canPrev ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 4),
              Text(
                "Previous",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: canPrev ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    items.add(const SizedBox(width: 6));

    // Page Numbers with smart window
    final List<int> pageNumbers = _calculatePageWindow(safeTotalPages);

    for (int i = 0; i < pageNumbers.length; i++) {
      final p = pageNumbers[i];

      // Insert ellipsis indicator
      if (i > 0 && p - pageNumbers[i - 1] > 1) {
        items.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              "...",
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }

      final isCurrent = p == currentPage;
      items.add(
        InkWell(
          onTap: isCurrent ? null : () => onPageChanged(p),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isCurrent ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrent ? activeColor : const Color(0xFFCBD5E1),
              ),
            ),
            child: Text(
              "$p",
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
                color: isCurrent ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ),
      );
      items.add(const SizedBox(width: 4));
    }

    if (items.isNotEmpty) {
      items.removeLast(); // remove extra spacing
    }
    items.add(const SizedBox(width: 6));

    // Next Button
    items.add(
      InkWell(
        onTap: canNext ? () => onPageChanged(currentPage + 1) : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: canNext ? Colors.white : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: canNext ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Next",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: canNext ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: canNext ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: items,
    );
  }

  List<int> _calculatePageWindow(int total) {
    if (total <= 7) {
      return List.generate(total, (i) => i + 1);
    }

    final Set<int> pages = {1, total, currentPage};
    pages.add(math.max(1, currentPage - 1));
    pages.add(math.min(total, currentPage + 1));
    pages.add(math.max(1, currentPage - 2));
    pages.add(math.min(total, currentPage + 2));

    final list = pages.where((p) => p >= 1 && p <= total).toList()..sort();
    return list;
  }
}
