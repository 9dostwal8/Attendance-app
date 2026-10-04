import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/hr_models.dart';
import '../../providers/attendance_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/zkteco_service.dart';
import '../glass_container.dart';
import '../neu_button.dart';

class HrDeviceTab extends StatefulWidget {
  const HrDeviceTab({super.key});

  @override
  State<HrDeviceTab> createState() => _HrDeviceTabState();
}

class _HrDeviceTabState extends State<HrDeviceTab> {
  final ZkTecoService _zkService = ZkTecoService.instance;
  late int _syncInterval;
  late int _cooldown;
  late bool _autoSync;

  bool _isTestingAll = false;
  bool _isSyncingAll = false;
  String? _syncingDeviceId;
  String? _testingDeviceId;
  bool _isFetchingUsers = false;
  String? _selectedDeviceForUsers;

  @override
  void initState() {
    super.initState();
    _syncInterval = _zkService.autoSyncIntervalMinutes;
    _cooldown = _zkService.cooldownMinutes;
    _autoSync = _zkService.autoSyncEnabled;

    _zkService.addListener(_onServiceUpdate);
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _zkService.removeListener(_onServiceUpdate);
    super.dispose();
  }

  Future<void> _handleSaveGlobalSettings(AttendanceProvider provider, FirebaseService firebase) async {
    await _zkService.saveSettings(
      autoSync: _autoSync,
      intervalMinutes: _syncInterval,
      cooldownMinutes: _cooldown,
      provider: provider,
      firebase: firebase,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ZKTeco global settings saved!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleTestAllDevices() async {
    setState(() => _isTestingAll = true);
    final results = await _zkService.testAllConnections();
    setState(() => _isTestingAll = false);

    if (!mounted) return;
    final onlineCount = results.values.where((info) => info.isConnected).length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connection check complete: $onlineCount / ${results.length} devices online.'),
        backgroundColor: onlineCount > 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleSyncAllDevices(AttendanceProvider provider, FirebaseService firebase) async {
    setState(() => _isSyncingAll = true);
    final summary = await _zkService.syncAllDevices(
      provider: provider,
      firebase: firebase,
    );
    setState(() => _isSyncingAll = false);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.message),
        backgroundColor: summary.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleSyncSingleDevice(ZkDeviceConfig dev, AttendanceProvider provider, FirebaseService firebase) async {
    setState(() => _syncingDeviceId = dev.id);
    final summary = await _zkService.syncDevice(
      dev,
      provider: provider,
      firebase: firebase,
    );
    setState(() => _syncingDeviceId = null);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.message),
        backgroundColor: summary.success ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  Future<void> _handleTestSingleDevice(ZkDeviceConfig dev) async {
    setState(() => _testingDeviceId = dev.id);
    final info = await _zkService.testDeviceConnection(dev);
    setState(() => _testingDeviceId = null);

    if (!mounted) return;
    if (info.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${dev.name}: ${info.deviceName} (${info.serialNumber})'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed to ${dev.name}: ${info.errorMessage ?? "Unreachable"}'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _handleFetchUsers(ZkDeviceConfig? dev) async {
    setState(() => _isFetchingUsers = true);
    try {
      final users = await _zkService.fetchUsers(device: dev);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fetched ${users.length} users from ${dev?.name ?? "device"}'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to fetch users: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isFetchingUsers = false);
    }
  }

  void _showAddEditDeviceDialog(BuildContext context, {ZkDeviceConfig? device}) {
    final isEditing = device != null;
    final nameCtrl = TextEditingController(text: device?.name ?? 'Terminal ${_zkService.devices.length + 1}');
    final ipCtrl = TextEditingController(text: device?.ip ?? '192.168.1.${200 + _zkService.devices.length + 1}');
    final portCtrl = TextEditingController(text: device?.port.toString() ?? '4370');
    final pwdCtrl = TextEditingController(text: device?.password.toString() ?? '0');
    bool isEnabled = device?.isEnabled ?? true;

    bool isTestingModal = false;
    ZkDeviceInfo? testResult;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
            final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
            final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: GlassContainer(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.fingerprint, color: Color(0xFF2E65FF), size: 24),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Edit Biometric Device' : 'Add Biometric Device',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                ),
                                Text(
                                  'Configure ZKTeco IP, port, and security key',
                                  style: TextStyle(fontSize: 12, color: subtextColor),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Device Name / Location *',
                          hintText: 'e.g., Main Entrance, Workshop Gate',
                          prefixIcon: Icon(Icons.badge_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: ipCtrl,
                        decoration: const InputDecoration(
                          labelText: 'IP Address *',
                          hintText: '192.168.1.201',
                          prefixIcon: Icon(Icons.router_outlined, size: 20),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: portCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port (Default 4370)',
                                hintText: '4370',
                                prefixIcon: Icon(Icons.numbers, size: 20),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: pwdCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Comm Key (Password)',
                                hintText: '0',
                                prefixIcon: Icon(Icons.key_outlined, size: 20),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Enable device for auto-sync', style: TextStyle(fontSize: 14)),
                        value: isEnabled,
                        activeThumbColor: const Color(0xFF10B981),
                        onChanged: (val) => setDialogState(() => isEnabled = val),
                      ),
                      if (testResult != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: testResult!.isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: testResult!.isConnected
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFFEF4444).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                testResult!.isConnected ? Icons.check_circle : Icons.error_outline,
                                color: testResult!.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  testResult!.isConnected
                                      ? 'Online: ${testResult!.deviceName} (${testResult!.serialNumber})'
                                      : 'Offline: ${testResult!.errorMessage ?? "Unreachable"}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: testResult!.isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          NeuButton(
                            onPressed: isTestingModal
                                ? null
                                : () async {
                                    final ip = ipCtrl.text.trim();
                                    final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
                                    final pwd = int.tryParse(pwdCtrl.text.trim()) ?? 0;
                                    if (ip.isEmpty) return;

                                    setDialogState(() => isTestingModal = true);
                                    final info = await _zkService.testConnection(ip: ip, port: port, password: pwd);
                                    setDialogState(() {
                                      isTestingModal = false;
                                      testResult = info;
                                    });
                                  },
                            isLoading: isTestingModal,
                            icon: const Icon(Icons.cable, size: 16),
                            label: 'Test Connection',
                            variant: NeuButtonVariant.whitePill,
                            height: 38,
                            fontSize: 12,
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogCtx),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              NeuButton(
                                onPressed: () async {
                                  final name = nameCtrl.text.trim();
                                  final ip = ipCtrl.text.trim();
                                  final port = int.tryParse(portCtrl.text.trim()) ?? 4370;
                                  final pwd = int.tryParse(pwdCtrl.text.trim()) ?? 0;

                                  if (name.isEmpty || ip.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Please enter both device name and IP address.')),
                                    );
                                    return;
                                  }

                                  if (device != null) {
                                    final updated = device.copyWith(
                                      name: name,
                                      ip: ip,
                                      port: port,
                                      password: pwd,
                                      isEnabled: isEnabled,
                                      cachedInfo: testResult ?? device.cachedInfo,
                                    );
                                    await _zkService.updateDevice(updated);
                                  } else {
                                    final newDev = ZkDeviceConfig(
                                      id: 'dev_${DateTime.now().millisecondsSinceEpoch}',
                                      name: name,
                                      ip: ip,
                                      port: port,
                                      password: pwd,
                                      isEnabled: isEnabled,
                                      cachedInfo: testResult,
                                    );
                                    await _zkService.addDevice(newDev);
                                  }

                                  if (dialogCtx.mounted) {
                                    Navigator.pop(dialogCtx);
                                  }
                                },
                                label: isEditing ? 'Save Changes' : 'Add Device',
                                variant: NeuButtonVariant.primary,
                                height: 38,
                                fontSize: 13,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeleteDevice(BuildContext context, ZkDeviceConfig dev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${dev.name}"?'),
        content: Text('Are you sure you want to remove ${dev.ip}:${dev.port} from the biometric devices list?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _zkService.deleteDevice(dev.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final firebase = FirebaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    final devices = _zkService.devices;
    final onlineCount = devices.where((d) => d.cachedInfo?.isConnected == true).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (kIsWeb)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E65FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF2E65FF).withValues(alpha: 0.35)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.hub_outlined, color: Color(0xFF2E65FF), size: 24),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Web Browser Mode: To communicate with local ZKTeco devices from Chrome/Edge, start "start_zk_bridge.bat" (or run natively: flutter run -d windows). Multi-device routing is automatically handled.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // 1. Multi-Device Header Card
          _buildMultiDeviceHeaderCard(context, textColor, subtextColor, devices, onlineCount, provider, firebase),
          const SizedBox(height: 16),

          // 2. Devices Grid / List
          _buildDevicesList(context, textColor, subtextColor, devices, provider, firebase),
          const SizedBox(height: 16),

          // 3. Smart Auto-Sync & Multi-Device Settings
          _buildSmartSyncCard(context, textColor, subtextColor, provider, firebase),
          const SizedBox(height: 16),

          // 4. Device Users & Employee Mapping
          _buildUserMappingCard(context, textColor, subtextColor, provider, devices),
          const SizedBox(height: 16),

          // 5. Live Sync Activity Log
          _buildSyncLogsCard(context, textColor, subtextColor),
        ],
      ),
    );
  }

  Widget _buildMultiDeviceHeaderCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    List<ZkDeviceConfig> devices,
    int onlineCount,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF2E65FF).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2E65FF).withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.hub_rounded, color: Color(0xFF2E65FF), size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ZKTeco Biometric Devices',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        '${devices.length} Configured • $onlineCount Online',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Multi-device synchronization with cross-terminal Smart Punch Pairing (Check In at Terminal A, Check Out at Terminal B)',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              NeuButton(
                onPressed: () => _showAddEditDeviceDialog(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: 'Add Device',
                variant: NeuButtonVariant.primary,
                height: 40,
                fontSize: 13,
              ),
              NeuButton(
                onPressed: _isTestingAll ? null : _handleTestAllDevices,
                isLoading: _isTestingAll,
                icon: const Icon(Icons.cable_rounded, size: 18),
                label: 'Test All',
                variant: NeuButtonVariant.whitePill,
                height: 40,
                fontSize: 13,
              ),
              NeuButton(
                onPressed: _isSyncingAll ? null : () => _handleSyncAllDevices(provider, firebase),
                isLoading: _isSyncingAll,
                icon: const Icon(Icons.sync_rounded, size: 18),
                label: 'Sync All Devices',
                variant: NeuButtonVariant.navy,
                height: 40,
                fontSize: 13,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    List<ZkDeviceConfig> devices,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    if (devices.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
        child: Column(
          children: [
            const Icon(Icons.devices_other_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text('No ZKTeco biometric devices configured yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 6),
            Text('Connect your biometric machines over local Wi-Fi or Ethernet LAN', style: TextStyle(fontSize: 12, color: subtextColor)),
            const SizedBox(height: 16),
            NeuButton(
              onPressed: () => _showAddEditDeviceDialog(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: 'Add First Device',
              variant: NeuButtonVariant.primary,
              height: 38,
            ),
          ],
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: devices.map((dev) {
        final info = dev.cachedInfo;
        final isConnected = info?.isConnected ?? false;
        final isSyncingThis = _syncingDeviceId == dev.id;
        final isTestingThis = _testingDeviceId == dev.id;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isConnected
                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                            : (isDark ? Colors.white10 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isConnected
                              ? const Color(0xFF10B981).withValues(alpha: 0.4)
                              : Colors.transparent,
                        ),
                      ),
                      child: Icon(
                        Icons.fingerprint,
                        color: isConnected ? const Color(0xFF10B981) : Colors.grey,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                dev.name,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (isDark ? Colors.white12 : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${dev.ip}:${dev.port}',
                                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: subtextColor),
                                ),
                              ),
                              if (dev.password > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text('Key: ${dev.password}', style: const TextStyle(fontSize: 10, color: Colors.amber)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isConnected ? const Color(0xFF10B981) : (info != null ? const Color(0xFFEF4444) : Colors.grey),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isConnected
                                    ? 'Online (${info!.deviceName.isNotEmpty ? info.deviceName : "ZKTeco Terminal"})'
                                    : (info != null ? 'Offline: ${info.errorMessage ?? "Unreachable"}' : 'Ready to connect'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isConnected ? const Color(0xFF10B981) : (info != null ? const Color(0xFFEF4444) : subtextColor),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text('• Last Sync: ${dev.lastSyncStatus}', style: TextStyle(fontSize: 11, color: subtextColor)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: dev.isEnabled,
                      activeThumbColor: const Color(0xFF10B981),
                      onChanged: (val) => _zkService.toggleDevice(dev.id, val),
                    ),
                  ],
                ),
                if (isConnected && info != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 6,
                    children: [
                      _buildMiniBadge('Serial', info.serialNumber.isNotEmpty ? info.serialNumber : 'N/A', textColor, subtextColor),
                      _buildMiniBadge('Firmware', info.firmwareVersion.isNotEmpty ? info.firmwareVersion : 'N/A', textColor, subtextColor),
                      _buildMiniBadge('Users', '${info.userCount}', textColor, subtextColor),
                      _buildMiniBadge('Logs', '${info.logCount}', textColor, subtextColor),
                      if (info.deviceTime != null)
                        _buildMiniBadge('Device Clock', info.deviceTime.toString().substring(0, 16), textColor, subtextColor),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeuButton(
                      onPressed: isTestingThis ? null : () => _handleTestSingleDevice(dev),
                      isLoading: isTestingThis,
                      icon: const Icon(Icons.cable, size: 14),
                      label: 'Test Connection',
                      variant: NeuButtonVariant.whitePill,
                      height: 32,
                      fontSize: 11.5,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    const SizedBox(width: 8),
                    NeuButton(
                      onPressed: () => _handleFetchUsers(dev),
                      icon: const Icon(Icons.people_outline, size: 14),
                      label: 'Users',
                      variant: NeuButtonVariant.whitePill,
                      height: 32,
                      fontSize: 11.5,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    const SizedBox(width: 8),
                    NeuButton(
                      onPressed: isSyncingThis ? null : () => _handleSyncSingleDevice(dev, provider, firebase),
                      isLoading: isSyncingThis,
                      icon: const Icon(Icons.sync, size: 14),
                      label: 'Sync This',
                      variant: NeuButtonVariant.primary,
                      height: 32,
                      fontSize: 11.5,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Edit Device Settings',
                      onPressed: () => _showAddEditDeviceDialog(context, device: dev),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: 'Delete Device',
                      onPressed: () => _confirmDeleteDevice(context, dev),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMiniBadge(String label, String value, Color textColor, Color subtextColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: TextStyle(fontSize: 11, color: subtextColor)),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildSmartSyncCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Color(0xFF10B981), size: 20),
              const SizedBox(width: 8),
              Text(
                'Multi-Device Smart Pairing & Background Sync',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Background Auto-Sync (All Active Terminals)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
            subtitle: Text(
              'Polls all active biometric devices simultaneously in the background while the app is running',
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
            value: _autoSync,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              setState(() => _autoSync = val);
              _handleSaveGlobalSettings(provider, firebase);
            },
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Auto-Sync Interval', style: TextStyle(fontSize: 12, color: subtextColor)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _syncInterval,
                      isDense: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('Every 5 mins')),
                        DropdownMenuItem(value: 10, child: Text('Every 10 mins')),
                        DropdownMenuItem(value: 15, child: Text('Every 15 mins (Default)')),
                        DropdownMenuItem(value: 30, child: Text('Every 30 mins')),
                        DropdownMenuItem(value: 60, child: Text('Every 1 hour')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _syncInterval = val);
                          _handleSaveGlobalSettings(provider, firebase);
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Duplicate Punch Cooldown', style: TextStyle(fontSize: 12, color: subtextColor)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _cooldown,
                      isDense: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 minute')),
                        DropdownMenuItem(value: 2, child: Text('2 minutes')),
                        DropdownMenuItem(value: 3, child: Text('3 minutes (Default)')),
                        DropdownMenuItem(value: 5, child: Text('5 minutes')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _cooldown = val);
                          _handleSaveGlobalSettings(provider, firebase);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2E65FF).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF2E65FF).withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF2E65FF), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cross-Terminal Pairing: When an employee clocks in at Terminal A (e.g. Main Entrance) and clocks out at Terminal B (e.g. Back Exit or Warehouse), the smart pairing engine automatically matches them into a single attendance session.',
                    style: TextStyle(fontSize: 12, color: textColor, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserMappingCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    AttendanceProvider provider,
    List<ZkDeviceConfig> devices,
  ) {
    final deviceUsers = _zkService.cachedUsers;
    final employees = provider.employees;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, color: Color(0xFF8B5CF6), size: 20),
              const SizedBox(width: 8),
              Text(
                'Device Users & Employee ID Mapping',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              const Spacer(),
              if (devices.isNotEmpty)
                DropdownButton<String>(
                  value: _selectedDeviceForUsers ?? devices.first.id,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 12, color: textColor),
                  items: devices.map((d) {
                    return DropdownMenuItem(value: d.id, child: Text(d.name));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDeviceForUsers = val);
                  },
                ),
              const SizedBox(width: 8),
              NeuButton(
                onPressed: _isFetchingUsers
                    ? null
                    : () {
                        final dev = devices.cast<ZkDeviceConfig?>().firstWhere(
                              (d) => d != null && d.id == _selectedDeviceForUsers,
                              orElse: () => devices.isNotEmpty ? devices.first : null,
                            );
                        _handleFetchUsers(dev);
                      },
                isLoading: _isFetchingUsers,
                icon: const Icon(Icons.download, size: 16),
                label: 'Fetch Users',
                variant: NeuButtonVariant.whitePill,
                height: 36,
                fontSize: 12,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (deviceUsers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              alignment: Alignment.center,
              child: Text(
                'Click "Fetch Users" to inspect enrolled fingerprints and match them with registered employees.',
                style: TextStyle(fontSize: 13, color: subtextColor),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: deviceUsers.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final u = deviceUsers[index];
                final matched = employees.cast<CompanyEmployee?>().firstWhere(
                      (e) =>
                          e != null &&
                          (e.id.trim().toLowerCase() == u.userId.trim().toLowerCase() ||
                              e.name.trim().toLowerCase() == u.name.trim().toLowerCase() ||
                              e.id.replaceAll(RegExp(r'[^0-9]'), '') == u.userId.replaceAll(RegExp(r'[^0-9]'), '')),
                      orElse: () => null,
                    );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          u.userId,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF8B5CF6)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              u.name.isNotEmpty ? u.name : 'User ${u.userId}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                            ),
                            Text(
                              'Device UID: ${u.uid} • Card: ${u.card > 0 ? u.card : "None"}',
                              style: TextStyle(fontSize: 11, color: subtextColor),
                            ),
                          ],
                        ),
                      ),
                      if (matched != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check, size: 14, color: Color(0xFF10B981)),
                              const SizedBox(width: 4),
                              Text(
                                'Matched: ${matched.name} (${matched.position})',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber, size: 14, color: Color(0xFFF59E0B)),
                              SizedBox(width: 4),
                              Text(
                                'No matching employee in app',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSyncLogsCard(BuildContext context, Color textColor, Color subtextColor) {
    final logs = _zkService.syncLogs;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.list_alt, color: Color(0xFF06B6D4), size: 20),
              const SizedBox(width: 8),
              Text(
                'Live Multi-Device Activity Log',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
              const Spacer(),
              if (logs.isNotEmpty)
                Text(
                  '${logs.length} events',
                  style: TextStyle(fontSize: 12, color: subtextColor),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 180,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: subtextColor.withValues(alpha: 0.2)),
            ),
            child: logs.isEmpty
                ? Center(
                    child: Text(
                      'No sync activity recorded yet. Click "Sync All Devices" to start.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final log = logs[idx];
                      final isError = log.contains('failed') || log.contains('error') || log.contains('Error') || log.contains('✗');
                      final isSuccess = log.contains('success') || log.contains('Synced') || log.contains('Connected') || log.contains('✓');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2.5),
                        child: Text(
                          log,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11.5,
                            color: isError
                                ? const Color(0xFFEF4444)
                                : isSuccess
                                    ? const Color(0xFF10B981)
                                    : textColor.withValues(alpha: 0.85),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
