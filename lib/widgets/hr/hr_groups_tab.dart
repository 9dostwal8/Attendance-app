import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';

class HrGroupsTab extends StatefulWidget {
  final String searchQuery;
  final Function(EmployeeGroup group)? onEdit;
  final Function(String id)? onDelete;

  const HrGroupsTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrGroupsTab> createState() => _HrGroupsTabState();
}

class _HrGroupsTabState extends State<HrGroupsTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final groups = provider.groups;

    if (groups.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? groups
        : groups
            .where((g) => g.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
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
            return _buildGroupCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildGroupCard(BuildContext context, EmployeeGroup group, AttendanceProvider provider) {
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
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.group_outlined,
                  color: Color(0xFFF59E0B),
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
                        widget.onEdit!(group);
                      } else {
                        showGroupDialog(context, group: group);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(group.id);
                      } else {
                        _showDeleteConfirm(context, group.id, provider);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            group.name,
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
            'Leave Addition: ${group.annualLeaveAdditionType}',
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
            Icons.group_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Employee Groups Found',
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
      title: 'Delete Group',
      subtitle: 'Remove employee classification group',
      icon: Icons.delete_outline,
      content: const Text('Are you sure you want to delete this employee group?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            provider.deleteGroup(id);
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showGroupDialog(BuildContext context, {EmployeeGroup? group}) {
  final nameController = TextEditingController(text: group?.name ?? '');
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showGlassDialog(
    context: context,
    title: group == null ? 'Add Group' : 'Edit Group',
    subtitle: group == null ? 'Create new group' : 'Update group settings',
    icon: Icons.group_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Group Name',
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
          final newGroup = EmployeeGroup(
            id: group?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameController.text.trim(),
            shiftId: group?.shiftId ?? '',
          );
          if (group == null) {
            provider.addGroup(newGroup);
          } else {
            provider.updateGroup(newGroup);
          }
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
