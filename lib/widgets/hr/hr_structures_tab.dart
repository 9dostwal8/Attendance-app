import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';

class HrStructuresTab extends StatefulWidget {
  final String searchQuery;
  final Function(OrgStructure structure)? onEdit;
  final Function(String id)? onDelete;

  const HrStructuresTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrStructuresTab> createState() => _HrStructuresTabState();
}

class _HrStructuresTabState extends State<HrStructuresTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final structures = provider.structures;

    if (structures.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? structures
        : structures
            .where((s) => s.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
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
            childAspectRatio: 1.6,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            return _buildStructureCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildStructureCard(BuildContext context, OrgStructure structure, AttendanceProvider provider) {
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
                  color: const Color(0xFF2E65FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.account_tree_outlined,
                  color: Color(0xFF2E65FF),
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
                        widget.onEdit!(structure);
                      } else {
                        showStructureDialog(context, structure: structure);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(structure.id);
                      } else {
                        _showDeleteConfirm(context, structure.id, provider);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            structure.name,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'Location: ${structure.location.isEmpty ? "N/A" : structure.location} | Capacity: ${structure.capacity}',
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
            Icons.account_tree_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Organizational Structures Found',
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
      title: 'Delete Structure',
      subtitle: 'Remove organizational unit',
      icon: Icons.delete_outline,
      content: const Text('Are you sure you want to delete this organizational structure?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            provider.deleteStructure(id);
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showStructureDialog(BuildContext context, {OrgStructure? structure}) {
  final nameController = TextEditingController(text: structure?.name ?? '');
  final locationController = TextEditingController(text: structure?.location ?? '');
  final capacityController = TextEditingController(text: (structure?.capacity ?? 0).toString());
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showGlassDialog(
    context: context,
    title: structure == null ? 'Add Structure' : 'Edit Structure',
    subtitle: structure == null ? 'Create new department' : 'Update department settings',
    icon: Icons.account_tree_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Structure Name',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: capacityController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Capacity',
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
          final newStruct = OrgStructure(
            id: structure?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameController.text.trim(),
            location: locationController.text.trim(),
            capacity: int.tryParse(capacityController.text) ?? 0,
          );
          if (structure == null) {
            provider.addStructure(newStruct);
          } else {
            provider.updateStructure(newStruct);
          }
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
