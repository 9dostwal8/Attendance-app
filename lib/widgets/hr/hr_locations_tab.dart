import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';

class HrLocationsTab extends StatefulWidget {
  final String searchQuery;
  final Function(WorkLocation location)? onEdit;
  final Function(String id)? onDelete;

  const HrLocationsTab({
    super.key,
    required this.searchQuery,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<HrLocationsTab> createState() => _HrLocationsTabState();
}

class _HrLocationsTabState extends State<HrLocationsTab> {
  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final locations = provider.locations;

    if (locations.isEmpty) {
      return _buildEmptyState(context);
    }

    final filtered = widget.searchQuery.isEmpty
        ? locations
        : locations
            .where((l) => l.name.toLowerCase().contains(widget.searchQuery.toLowerCase()))
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
            return _buildLocationCard(context, filtered[index], provider);
          },
        );
      },
    );
  }

  Widget _buildLocationCard(BuildContext context, WorkLocation location, AttendanceProvider provider) {
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
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF8B5CF6),
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
                        widget.onEdit!(location);
                      } else {
                        showLocationDialog(context, location: location);
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    color: Colors.red.shade400,
                    onPressed: () {
                      if (widget.onDelete != null) {
                        widget.onDelete!(location.id);
                      } else {
                        _showDeleteConfirm(context, location.id, provider);
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          Text(
            location.name,
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
            'Radius: ${location.radius.toInt()}m | (${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)})',
            style: TextStyle(
              fontSize: 12,
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
            Icons.location_on_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'No Work Locations Found',
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
      title: 'Delete Location',
      subtitle: 'Remove work branch location',
      icon: Icons.delete_outline,
      content: const Text('Are you sure you want to delete this work location?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () {
            provider.deleteLocation(id);
            Navigator.pop(context);
          },
          child: const Text('Delete', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

void showLocationDialog(BuildContext context, {WorkLocation? location}) {
  final nameController = TextEditingController(text: location?.name ?? '');
  final latController = TextEditingController(text: (location?.latitude ?? 0.0).toString());
  final lngController = TextEditingController(text: (location?.longitude ?? 0.0).toString());
  final radiusController = TextEditingController(text: (location?.radius ?? 100.0).toString());
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  showGlassDialog(
    context: context,
    title: location == null ? 'Add Location' : 'Edit Location',
    subtitle: location == null ? 'Define geofence location' : 'Update branch location details',
    icon: Icons.location_on_outlined,
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Location Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: latController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Latitude',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: lngController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Longitude',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: radiusController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Radius (Meters)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () {
          if (nameController.text.trim().isEmpty) return;
          final newLoc = WorkLocation(
            id: location?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: nameController.text.trim(),
            latitude: double.tryParse(latController.text) ?? 0.0,
            longitude: double.tryParse(lngController.text) ?? 0.0,
            radius: double.tryParse(radiusController.text) ?? 100.0,
          );
          if (location == null) {
            provider.addLocation(newLoc);
          } else {
            provider.updateLocation(newLoc);
          }
          Navigator.pop(context);
        },
        child: const Text('Save'),
      ),
    ],
  );
}
