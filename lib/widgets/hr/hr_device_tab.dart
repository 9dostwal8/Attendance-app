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
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _passwordController;
  late int _syncInterval;
  late int _cooldown;
  late bool _autoSync;

  bool _isTesting = false;
  bool _isSyncing = false;
  bool _isFetchingUsers = false;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController(text: _zkService.deviceIp);
    _portController = TextEditingController(text: _zkService.devicePort.toString());
    _passwordController = TextEditingController(text: _zkService.devicePassword.toString());
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
    _ipController.dispose();
    _portController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveSettings(AttendanceProvider provider, FirebaseService firebase) async {
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4370;
    final pwd = int.tryParse(_passwordController.text.trim()) ?? 0;

    await _zkService.saveSettings(
      ip: ip,
      port: port,
      password: pwd,
      autoSync: _autoSync,
      intervalMinutes: _syncInterval,
      cooldownMinutes: _cooldown,
      provider: provider,
      firebase: firebase,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device settings saved successfully!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
    }
  }

  Future<void> _handleTestConnection() async {
    setState(() => _isTesting = true);
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 4370;
    final pwd = int.tryParse(_passwordController.text.trim()) ?? 0;

    final info = await _zkService.testConnection(
      ip: ip,
      port: port,
      password: pwd,
    );

    setState(() => _isTesting = false);

    if (!mounted) return;

    if (info.isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connected to ${info.deviceName} (${info.serialNumber})'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connection failed: ${info.errorMessage ?? "Unreachable"}'),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleSyncNow(AttendanceProvider provider, FirebaseService firebase) async {
    setState(() => _isSyncing = true);

    final summary = await _zkService.syncAttendances(
      provider: provider,
      firebase: firebase,
    );

    setState(() => _isSyncing = false);

    if (!mounted) return;

    if (summary.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary.message),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(summary.message),
          backgroundColor: const Color(0xFFEF4444),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleFetchUsers() async {
    setState(() => _isFetchingUsers = true);
    try {
      await _zkService.fetchUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fetched ${_zkService.cachedUsers.length} users from device'),
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

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final firebase = FirebaseService();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

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
                      'Web Browser Mode: To communicate with your local ZKTeco device from Chrome/Edge, simply run "start_zk_bridge.bat" on this computer (or run the app natively on Windows Desktop: flutter run -d windows).',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // 1. Device Header & Status Card
          _buildDeviceStatusCard(context, textColor, subtextColor, provider, firebase),
          const SizedBox(height: 16),

          // 2. Settings Grid (Connection Settings & Auto Sync)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildConnectionSettingsCard(context, textColor, subtextColor, provider, firebase),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 6,
                      child: _buildSmartSyncCard(context, textColor, subtextColor, provider, firebase),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildConnectionSettingsCard(context, textColor, subtextColor, provider, firebase),
                    const SizedBox(height: 16),
                    _buildSmartSyncCard(context, textColor, subtextColor, provider, firebase),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),

          // 3. Device Users & Employee Mapping
          _buildUserMappingCard(context, textColor, subtextColor, provider),
          const SizedBox(height: 16),

          // 4. Live Sync Activity Log
          _buildSyncLogsCard(context, textColor, subtextColor),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard(
    BuildContext context,
    Color textColor,
    Color subtextColor,
    AttendanceProvider provider,
    FirebaseService firebase,
  ) {
    final info = _zkService.cachedDeviceInfo;
    final isConnected = info?.isConnected ?? false;

    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isConnected
                      ? const Color(0xFF10B981).withValues(alpha: 0.15)
                      : const Color(0xFF2E65FF).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isConnected
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : const Color(0xFF2E65FF).withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: isConnected ? const Color(0xFF10B981) : const Color(0xFF2E65FF),
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          info?.deviceName.isNotEmpty == true ? info!.deviceName : 'ZKTeco Attendance Device',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isConnected
                                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                : const Color(0xFF64748B).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isConnected
                                  ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                  : const Color(0xFF64748B).withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: isConnected ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isConnected ? 'Online' : 'Ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isConnected ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Target: ${_zkService.deviceIp}:${_zkService.devicePort} • Last Sync: ${_zkService.lastSyncStatus}',
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
                    onPressed: _isTesting ? null : _handleTestConnection,
                    isLoading: _isTesting,
                    icon: const Icon(Icons.cable, size: 18),
                    label: 'Test Connection',
                    variant: NeuButtonVariant.whitePill,
                    height: 40,
                    fontSize: 13,
                  ),
                  NeuButton(
                    onPressed: _isSyncing ? null : () => _handleSyncNow(provider, firebase),
                    isLoading: _isSyncing,
                    icon: const Icon(Icons.sync, size: 18),
                    label: 'Sync Now',
                    variant: NeuButtonVariant.primary,
                    height: 40,
                    fontSize: 13,
                  ),
                ],
              ),
            ],
          ),
          if (info != null && info.isConnected) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                _buildInfoBadge('Serial', info.serialNumber.isNotEmpty ? info.serialNumber : 'N/A', textColor, subtextColor),
                _buildInfoBadge('Firmware', info.firmwareVersion.isNotEmpty ? info.firmwareVersion : 'N/A', textColor, subtextColor),
                _buildInfoBadge('Platform', info.platform.isNotEmpty ? info.platform : 'ZEM560', textColor, subtextColor),
                _buildInfoBadge('Device Users', '${info.userCount}', textColor, subtextColor),
                _buildInfoBadge('Stored Logs', '${info.logCount}', textColor, subtextColor),
                if (info.deviceTime != null)
                  _buildInfoBadge('Device Clock', info.deviceTime.toString().substring(0, 19), textColor, subtextColor),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoBadge(String label, String value, Color textColor, Color subtextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor)),
      ],
    );
  }

  Widget _buildConnectionSettingsCard(
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
              const Icon(Icons.settings_ethernet, color: Color(0xFF2E65FF), size: 20),
              const SizedBox(width: 8),
              Text(
                'Connection Parameters',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ipController,
            decoration: const InputDecoration(
              labelText: 'Device IP Address',
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
                  controller: _portController,
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
                  controller: _passwordController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Comm Key / Password',
                    hintText: '0',
                    prefixIcon: Icon(Icons.key_outlined, size: 20),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: NeuButton(
              onPressed: () => _handleSaveSettings(provider, firebase),
              label: 'Save Configuration',
              variant: NeuButtonVariant.navy,
              height: 38,
              fontSize: 13,
            ),
          ),
        ],
      ),
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
                'Smart Shift Pairing & Auto-Sync',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Background Auto-Sync',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
            ),
            subtitle: Text(
              'Syncs punches automatically in the background while the app is active',
              style: TextStyle(fontSize: 12, color: subtextColor),
            ),
            value: _autoSync,
            activeThumbColor: const Color(0xFF10B981),
            onChanged: (val) {
              setState(() => _autoSync = val);
              _handleSaveSettings(provider, firebase);
            },
          ),
          const Divider(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sync Interval', style: TextStyle(fontSize: 12, color: subtextColor)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<int>(
                      initialValue: _syncInterval,
                      isDense: true,
                      decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('Every 5 mins')),
                        DropdownMenuItem(value: 10, child: Text('Every 10 mins')),
                        DropdownMenuItem(value: 15, child: Text('Every 15 mins')),
                        DropdownMenuItem(value: 30, child: Text('Every 30 mins')),
                        DropdownMenuItem(value: 60, child: Text('Every 1 hour')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _syncInterval = val);
                          _handleSaveSettings(provider, firebase);
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
                    Text('Duplicate Cooldown', style: TextStyle(fontSize: 12, color: subtextColor)),
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
                          _handleSaveSettings(provider, firebase);
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
                    'Smart Pairing automatically matches Check-In & Check-Out punches without employees pressing buttons. Overnight & 24h shifts (e.g. 08:00 AM to 08:00 AM next day) are fully supported.',
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
              NeuButton(
                onPressed: _isFetchingUsers ? null : _handleFetchUsers,
                isLoading: _isFetchingUsers,
                icon: const Icon(Icons.download, size: 16),
                label: 'Fetch Users from Device',
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
                'Click "Fetch Users from Device" to preview enrolled fingerprints and match them with app employees.',
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
                // Match with employee
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
                'Live Sync Activity Log',
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
                      'No sync activity recorded yet. Click "Sync Now" to start.',
                      style: TextStyle(fontSize: 12, color: subtextColor),
                    ),
                  )
                : ListView.builder(
                    itemCount: logs.length,
                    itemBuilder: (context, idx) {
                      final log = logs[idx];
                      final isError = log.contains('failed') || log.contains('error') || log.contains('Error');
                      final isSuccess = log.contains('success') || log.contains('Synced') || log.contains('Connected');

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
