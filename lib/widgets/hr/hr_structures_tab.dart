import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/attendance_provider.dart';
import '../../models/hr_models.dart';
import '../../screens/map_picker_screen.dart';
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
        final crossAxisCount = constraints.maxWidth > 1050
            ? 3
            : constraints.maxWidth > 650
                ? 2
                : 1;

        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: crossAxisCount == 1 ? 2.1 : 1.45,
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

  Widget _buildStructureCard(
    BuildContext context,
    OrgStructure structure,
    AttendanceProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final assignedEmployees = provider.employees
        .where((e) => e.structureId == structure.id)
        .toList();
    final empCount = assignedEmployees.length;

    CompanyEmployee? supervisor;
    if (structure.supervisorId != null && structure.supervisorId!.isNotEmpty) {
      try {
        supervisor = provider.employees.firstWhere((e) => e.id == structure.supervisorId);
      } catch (_) {}
    }

    OrgStructure? parent;
    if (structure.parentId != null && structure.parentId!.isNotEmpty) {
      try {
        parent = provider.structures.firstWhere((s) => s.id == structure.parentId);
      } catch (_) {}
    }

    final hasGeofence = structure.latitude != null && structure.longitude != null;

    return GlassContainer(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Top Row: Icon badge + Title + Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E65FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF2E65FF).withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.account_tree_rounded,
                  color: Color(0xFF2E65FF),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      structure.name,
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
                      parent != null && parent.name.isNotEmpty
                          ? 'Parent: ${parent.name}'
                          : 'Root Department',
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
                    message: 'Edit Structure',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onEdit != null) {
                          widget.onEdit!(structure);
                        } else {
                          showStructureDialog(context, structure: structure);
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
                    message: 'Delete Structure',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () {
                        if (widget.onDelete != null) {
                          widget.onDelete!(structure.id);
                        } else {
                          _showDeleteConfirm(context, structure.id, provider);
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

          // Divider
          Divider(
            height: 18,
            thickness: 1,
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),

          // Details Grid (Location & GPS, Workforce & Supervisor)
          Column(
            children: [
              Row(
                children: [
                  // Location Chip
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.location_on_outlined,
                      iconColor: const Color(0xFF06B6D4),
                      label: structure.location.isNotEmpty ? structure.location : 'No location',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Geofence Chip
                  Expanded(
                    child: _buildInfoChip(
                      icon: hasGeofence ? Icons.radar_rounded : Icons.location_off_outlined,
                      iconColor: hasGeofence ? const Color(0xFF10B981) : Colors.grey,
                      label: hasGeofence
                          ? '${structure.radius?.round() ?? 100}m Geofence'
                          : 'No GPS Set',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Workforce & Capacity Chip
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.people_alt_outlined,
                      iconColor: const Color(0xFF2E65FF),
                      label: '$empCount Members${structure.capacity > 0 ? " / ${structure.capacity}" : ""}',
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Supervisor Chip
                  Expanded(
                    child: _buildInfoChip(
                      icon: Icons.shield_outlined,
                      iconColor: supervisor != null ? const Color(0xFF8B5CF6) : Colors.grey,
                      label: supervisor != null ? supervisor.name : 'No Supervisor',
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
  final capacityController = TextEditingController(
    text: (structure?.capacity != null && structure!.capacity > 0)
        ? structure.capacity.toString()
        : '',
  );
  final provider = Provider.of<AttendanceProvider>(context, listen: false);

  String? selectedParentId = structure?.parentId;
  String? selectedSupervisorId = structure?.supervisorId;
  double? selectedLatitude = structure?.latitude;
  double? selectedLongitude = structure?.longitude;
  double? selectedRadius = structure?.radius ?? 100.0;
  String? selectedPredefinedLocationId;

  // Match existing location if present
  if (structure != null && structure.location.isNotEmpty) {
    for (var loc in provider.locations) {
      if (loc.name.toLowerCase() == structure.location.toLowerCase()) {
        selectedPredefinedLocationId = loc.id;
        break;
      }
    }
  }

  showGlassDialog(
    context: context,
    title: structure == null ? 'Add Structure' : 'Edit Structure',
    subtitle: structure == null ? 'Create new department/unit' : 'Update department settings and location',
    icon: Icons.account_tree_outlined,
    content: StatefulBuilder(
      builder: (context, setDialogState) {
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Structure Name
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Structure Name *',
                  hintText: 'e.g. Main Office, Marketing Dept',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.corporate_fare_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Location Preset Selector (from Company Locations if any exist)
              if (provider.locations.isNotEmpty) ...[
                DropdownButtonFormField<String?>(
                  initialValue: selectedPredefinedLocationId,
                  decoration: const InputDecoration(
                    labelText: 'Company Location Preset',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.pin_drop_outlined, size: 20),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Custom / Manual Location'),
                    ),
                    ...provider.locations.map(
                      (loc) => DropdownMenuItem(
                        value: loc.id,
                        child: Text('${loc.name} (${loc.radius.round()}m)'),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      selectedPredefinedLocationId = val;
                      if (val != null) {
                        final found = provider.locations.firstWhere((l) => l.id == val);
                        locationController.text = found.name;
                        selectedLatitude = found.latitude;
                        selectedLongitude = found.longitude;
                        selectedRadius = found.radius;
                      }
                    });
                  },
                ),
                const SizedBox(height: 14),
              ],

              // Location Name (free-text or prefilled)
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location Name / City / Branch',
                  hintText: 'e.g. Downtown, Suly Branch, Floor 2',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // GPS Geofencing Settings & Map Picker
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (selectedLatitude != null && selectedLongitude != null)
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.my_location_rounded,
                          size: 18,
                          color: selectedLatitude != null ? const Color(0xFF10B981) : Colors.white70,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'GPS Coordinates & Geofencing',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      selectedLatitude != null && selectedLongitude != null
                          ? 'Lat: ${selectedLatitude!.toStringAsFixed(5)}, Lng: ${selectedLongitude!.toStringAsFixed(5)} • Radius: ${selectedRadius?.round() ?? 100}m'
                          : 'No coordinates set. Clock-in geofence will be disabled.',
                      style: TextStyle(
                        fontSize: 12,
                        color: selectedLatitude != null ? const Color(0xFF10B981) : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        SizedBox(
                          height: 34,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.map_rounded, size: 15, color: Colors.white),
                            label: Text(
                              selectedLatitude != null ? 'Change on Map' : 'Pick on Map',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E65FF),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MapPickerScreen(
                                    initialLatitude: selectedLatitude ?? 33.3152,
                                    initialLongitude: selectedLongitude ?? 44.3661,
                                    initialRadius: selectedRadius ?? 100.0,
                                    fetchCurrentLocation: selectedLatitude == null,
                                  ),
                                ),
                              );
                              if (result != null) {
                                setDialogState(() {
                                  selectedLatitude = result['latitude'];
                                  selectedLongitude = result['longitude'];
                                  selectedRadius = result['radius'];
                                });
                              }
                            },
                          ),
                        ),
                        if (selectedLatitude != null) ...[
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () {
                              setDialogState(() {
                                selectedLatitude = null;
                                selectedLongitude = null;
                                selectedRadius = null;
                                selectedPredefinedLocationId = null;
                              });
                            },
                            child: const Text(
                              'Clear GPS',
                              style: TextStyle(fontSize: 12, color: Colors.redAccent),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Capacity
              TextField(
                controller: capacityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Staff Capacity (Optional)',
                  hintText: 'e.g. 50',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_outline, size: 20),
                ),
              ),
              const SizedBox(height: 14),

              // Parent Structure Dropdown
              Builder(
                builder: (context) {
                  final structureMap = <String, OrgStructure>{};
                  for (final s in provider.structures) {
                    if (structure == null || s.id != structure.id) {
                      structureMap[s.id] = s;
                    }
                  }
                  final hasCurrentParent = selectedParentId == null ||
                      structureMap.containsKey(selectedParentId);

                  return DropdownButtonFormField<String?>(
                    key: ValueKey(selectedParentId),
                    initialValue: selectedParentId,
                    decoration: const InputDecoration(
                      labelText: 'Parent Department',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.folder_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None (Top-Level Structure)'),
                      ),
                      if (selectedParentId != null && !hasCurrentParent)
                        DropdownMenuItem(
                          value: selectedParentId,
                          child: Text('Assigned Parent ($selectedParentId)'),
                        ),
                      ...structureMap.values.map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedParentId = val);
                    },
                  );
                },
              ),
              const SizedBox(height: 14),

              // Supervisor Dropdown
              Builder(
                builder: (context) {
                  final employeeMap = <String, CompanyEmployee>{};
                  for (final emp in provider.employees) {
                    employeeMap[emp.id] = emp;
                  }
                  final hasCurrentSupervisor = selectedSupervisorId == null ||
                      employeeMap.containsKey(selectedSupervisorId);

                  return DropdownButtonFormField<String?>(
                    key: ValueKey(selectedSupervisorId),
                    initialValue: selectedSupervisorId,
                    decoration: const InputDecoration(
                      labelText: 'Department Supervisor',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.shield_outlined, size: 20),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('None (No Supervisor)'),
                      ),
                      if (selectedSupervisorId != null && !hasCurrentSupervisor)
                        DropdownMenuItem(
                          value: selectedSupervisorId,
                          child: Text('Assigned ($selectedSupervisorId)'),
                        ),
                      ...employeeMap.values.map(
                        (emp) => DropdownMenuItem(
                          value: emp.id,
                          child: Text('${emp.name} (${emp.position.isNotEmpty ? emp.position : emp.role.toUpperCase()})'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setDialogState(() => selectedSupervisorId = val);
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      SizedBox(
        height: 38,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E65FF),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            if (nameController.text.trim().isEmpty) return;
            final newStruct = OrgStructure(
              id: structure?.id ?? 'struct_${DateTime.now().millisecondsSinceEpoch}',
              name: nameController.text.trim(),
              location: locationController.text.trim(),
              capacity: int.tryParse(capacityController.text) ?? 0,
              parentId: selectedParentId,
              supervisorId: selectedSupervisorId,
              latitude: selectedLatitude,
              longitude: selectedLongitude,
              radius: selectedRadius,
            );
            if (structure == null) {
              provider.addStructure(newStruct);
            } else {
              provider.updateStructure(newStruct);
            }
            Navigator.pop(context);
          },
          child: const Text(
            'Save Structure',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      ),
    ],
  );
}
