import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../glass_container.dart';
import '../glass_dialog.dart';
import '../neu_button.dart';

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
        final crossAxisCount = constraints.maxWidth > 1400
            ? 4
            : constraints.maxWidth > 950
                ? 3
                : constraints.maxWidth > 650
                    ? 2
                    : 1;

        if (crossAxisCount == 1) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              return _buildLocationCard(context, filtered[index], provider);
            },
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 2 ? 1.75 : 1.9,
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
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFF8B5CF6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      location.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Radius: ${location.radius.toInt()}m',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subtextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: 'Edit Location',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!(location);
                        } else {
                          showLocationDialog(context, location: location);
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(5),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Delete Location',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onDelete != null) {
                          widget.onDelete!(location.id);
                        } else {
                          _showDeleteConfirm(context, location.id, provider);
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(5),
                        child: Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          Divider(
            height: 16,
            thickness: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.radar_rounded, size: 14, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${location.radius.toInt()}m Geofence',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.gps_fixed_rounded, size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
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
        NeuButton(
          label: 'Delete',
          variant: NeuButtonVariant.danger,
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          onPressed: () {
            provider.deleteLocation(id);
            Navigator.pop(context);
          },
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
      NeuButton(
        label: 'Save',
        variant: NeuButtonVariant.primary,
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 18),
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
      ),
    ],
  );
}
