import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';

class HrHolidaysTab extends StatefulWidget {
  final String searchQuery;
  final Function(Holiday holiday)? onEdit;
  final Function(String id)? onDelete;

  const HrHolidaysTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrHolidaysTab> createState() => _HrHolidaysTabState();
}

class _HrHolidaysTabState extends State<HrHolidaysTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final holidays = provider.holidays;

    if (holidays.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? holidays
        : holidays
            .where((h) => h.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 1.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildHolidayCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildHolidayCard(BuildContext context, Holiday holiday, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.beach_access_outlined,
                  color: Color(0xFFEC4899),
                  size: 24,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    color: isDark ? Colors.white70 : Colors.black54,
                    onPressed: () {
                      if (widget.onEdit != null) {
                        widget.onEdit!(holiday);
                      } else {
                        showHolidayDialog(context, holiday: holiday);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(holiday.id);
                      } else {
                        _showDeleteConfirm(context, holiday.id, provider);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            holiday.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            'From: ${holiday.fromDate} To: ${holiday.toDate}',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.beach_access_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Holidays Found',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context, String id, AttendanceProvider provider) {
    showGlassDialog(
      context: context,
      title: 'Delete Holiday',
      subtitle: 'Remove holiday configuration',
      icon: Icons.delete_outline,
      content: const Text('Are you sure you want to delete this official holiday?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            provider.deleteHoliday(id);
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showHolidayDialog(BuildContext context, {Holiday? holiday}) {
  final nameController = TextEditingController(text: holiday?.name ?? '');
  final fromController = TextEditingController(text: holiday?.fromDate ?? '');
  final toController = TextEditingController(text: holiday?.toDate ?? '');
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showGlassDialog(
    context: context,
    title: holiday == null ? 'Add Holiday' : 'Edit Holiday',
    subtitle: holiday == null ? 'Schedule company holiday' : 'Update holiday dates',
    icon: Icons.beach_access_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Holiday Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: fromController,
          decoration: const InputDecoration(
            labelText: 'From Date (yyyy-MM-dd)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: toController,
          decoration: const InputDecoration(
            labelText: 'To Date (yyyy-MM-dd)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          if (nameController.text.trim().isEmpty) return;
          final newHoliday = Holiday(
            id: holiday?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameController.text.trim(),
            fromDate: fromController.text.trim(),
            toDate: toController.text.trim(),
          );
          if (holiday == null) {
            provider.addHoliday(newHoliday);
          } else {
            provider.updateHoliday(newHoliday);
          }
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
