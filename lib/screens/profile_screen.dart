import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../models/hr_models.dart';
import '../providers/attendance_provider.dart';
import '../widgets/avatar_image_helper.dart';
import '../widgets/glass_dialog.dart';
import 'user_management_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _copiedKey;

  void _copyToClipboard(String key, String title, String value) {
    if (value.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: value.trim()));
    HapticFeedback.lightImpact();
    setState(() => _copiedKey = key);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _copiedKey == key) {
        setState(() => _copiedKey = null);
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$title copied to clipboard!',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF10B981),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _getDepartmentName(AttendanceProvider provider) {
    final currentEmp = provider.currentEmployee;
    final structId = currentEmp?.structureId ?? provider.department;
    final structMatch = provider.structures.where((s) => s.id == structId).firstOrNull;
    if (structMatch != null) {
      return structMatch.name;
    }
    final dept = provider.department;
    if (dept.isNotEmpty && !dept.startsWith('struct_')) {
      return dept;
    }
    return currentEmp?.position.isNotEmpty == true ? currentEmp!.position : 'General';
  }

  String _getRoleLabel(String? role) {
    switch (role) {
      case 'admin':
        return 'Super Admin';
      case 'hr':
        return 'HR Manager';
      case 'supervisor':
        return 'Supervisor';
      case 'employee':
      default:
        return 'Employee';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRtl = provider.currentLanguageDirection == TextDirection.rtl;

    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final currentEmp = provider.currentEmployee;
    WorkShift? activeShift;
    if (currentEmp != null) {
      activeShift = provider.getShiftForDate(currentEmp, DateTime.now());
    }

    final departmentName = _getDepartmentName(provider);
    final roleLabel = _getRoleLabel(currentEmp?.role);

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            // Ambient top decoration glow
            Positioned(
              top: -120,
              left: 0,
              right: 0,
              height: 320,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.2,
                    colors: [
                      isDark
                          ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                          : const Color(0xFF3B82F6).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    children: [
                      // Modern Navigation Header
                      _buildHeader(context, provider, isDark, isRtl, primaryTextColor, secondaryTextColor),

                      // Scrollable content
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Hero Profile Card
                              _buildHeroProfileCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                currentEmp,
                                activeShift,
                                departmentName,
                                roleLabel,
                              ),
                              const SizedBox(height: 24),

                              // Section: Personal & Employment Information
                              _buildSectionTitle(
                                icon: Icons.badge_outlined,
                                iconColor: const Color(0xFF2563EB),
                                title: provider.translate('personal_info'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildPersonalInfoCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                currentEmp,
                                activeShift,
                                departmentName,
                                roleLabel,
                              ),
                              const SizedBox(height: 24),

                              // Section: Preferences (Language & Appearance)
                              _buildSectionTitle(
                                icon: Icons.tune_rounded,
                                iconColor: const Color(0xFF8B5CF6),
                                title: provider.translate('change_language'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildLanguageSelector(context, provider, isDark, cardBg, cardBorder),
                              const SizedBox(height: 24),

                              _buildSectionTitle(
                                icon: Icons.palette_outlined,
                                iconColor: const Color(0xFFF59E0B),
                                title: provider.translate('theme'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildThemeSelector(context, provider, isDark, cardBg, cardBorder),
                              const SizedBox(height: 24),

                              // Section: Security
                              _buildSectionTitle(
                                icon: Icons.shield_outlined,
                                iconColor: const Color(0xFFEF4444),
                                title: provider.translate('security'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildSecurityCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                                isRtl,
                              ),
                              const SizedBox(height: 24),

                              // Administrative Access (If applicable)
                              if (currentEmp?.role == 'hr' || currentEmp?.role == 'admin') ...[
                                _buildSectionTitle(
                                  icon: Icons.admin_panel_settings_outlined,
                                  iconColor: const Color(0xFF6366F1),
                                  title: 'System Administration',
                                  textColor: secondaryTextColor,
                                ),
                                const SizedBox(height: 12),
                                _buildUserManagementCard(
                                  context,
                                  isDark,
                                  cardBg,
                                  cardBorder,
                                  primaryTextColor,
                                  secondaryTextColor,
                                  isRtl,
                                ),
                                const SizedBox(height: 24),
                              ],

                              // Account Switcher (Testing Mode)
                              _buildSectionTitle(
                                icon: Icons.swap_horiz_rounded,
                                iconColor: const Color(0xFF06B6D4),
                                title: provider.translate('switch_account'),
                                textColor: secondaryTextColor,
                              ),
                              const SizedBox(height: 12),
                              _buildAccountSwitcherCard(
                                context,
                                provider,
                                isDark,
                                cardBg,
                                cardBorder,
                                primaryTextColor,
                                secondaryTextColor,
                              ),
                              const SizedBox(height: 28),

                              // Sign Out Button
                              _buildSignOutCard(context, provider, isDark),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADER APP BAR ---
  Widget _buildHeader(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    bool isRtl,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Frosted Back Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isRtl ? Icons.arrow_forward_ios_rounded : Icons.arrow_back_ios_new_rounded,
                  color: primaryColor,
                  size: 18,
                ),
              ),
            ),
          ),

          // Title & Subtitle
          Column(
            children: [
              Text(
                provider.translate('profile'),
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Personal Account & Preferences',
                style: TextStyle(
                  color: secondaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          // Quick Theme Toggle Button in Header
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                provider.toggleTheme();
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
                child: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF6366F1),
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION HEADER ---
  Widget _buildSectionTitle({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Color textColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  // --- HERO PROFILE CARD ---
  Widget _buildHeroProfileCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    CompanyEmployee? currentEmp,
    WorkShift? activeShift,
    String departmentName,
    String roleLabel,
  ) {
    final avatarProvider = getAvatarProvider(provider.avatarPath);
    final initials = provider.userName.trim().isNotEmpty
        ? provider.userName.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'U';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Banner with Mesh Gradient and Decorative Elements
          Stack(
            children: [
              Container(
                height: 95,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1D4ED8),
                      Color(0xFF2563EB),
                      Color(0xFF4F46E5),
                      Color(0xFF7C3AED),
                    ],
                  ),
                ),
              ),
              // Subtle background circle accents
              Positioned(
                top: -30,
                right: -20,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),
              Positioned(
                bottom: -20,
                left: 30,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ],
          ),

          // Avatar overlapping the banner
          Transform.translate(
            offset: const Offset(0, -48),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                        border: Border.all(
                          color: cardBg,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.15),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                        image: avatarProvider != null
                            ? DecorationImage(image: avatarProvider, fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarProvider == null
                          ? Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            )
                          : null,
                    ),

                    // Camera floating action badge
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showPhotoPickerSheet(context, provider),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                              ),
                              shape: BoxShape.circle,
                              border: Border.all(color: cardBg, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.45),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Full Name
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    provider.userName.isNotEmpty ? provider.userName : 'Employee',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: primaryColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Job Title
                Text(
                  provider.userTitle.isNotEmpty ? provider.userTitle : 'Staff Member',
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),

                // Badges Row
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Role Badge
                    _buildPillBadge(
                      icon: Icons.shield_rounded,
                      label: roleLabel,
                      bgColor: const Color(0xFF3B82F6).withValues(alpha: isDark ? 0.2 : 0.1),
                      fgColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    ),

                    // Department Badge
                    _buildPillBadge(
                      icon: Icons.domain_rounded,
                      label: departmentName,
                      bgColor: const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.2 : 0.1),
                      fgColor: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED),
                    ),

                    // Active Status Badge
                    _buildPillBadge(
                      icon: Icons.fiber_manual_record_rounded,
                      label: 'Active',
                      bgColor: const Color(0xFF10B981).withValues(alpha: isDark ? 0.2 : 0.1),
                      fgColor: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Highlights Bottom Row
          Transform.translate(
            offset: const Offset(0, -28),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.03) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFEEF2F6),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      label: 'EMP ID',
                      value: provider.employeeId.isNotEmpty ? provider.employeeId : 'N/A',
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      label: 'SHIFT',
                      value: activeShift != null ? activeShift.name : 'Standard',
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                    ),
                  ),
                  Container(
                    height: 28,
                    width: 1,
                    color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      label: 'HOURS',
                      value: activeShift != null
                          ? '${activeShift.startTime} - ${activeShift.endTime}'
                          : '09:00 - 17:00',
                      primaryColor: primaryColor,
                      secondaryColor: secondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillBadge({
    required IconData icon,
    required String label,
    required Color bgColor,
    required Color fgColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fgColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required Color primaryColor,
    required Color secondaryColor,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: secondaryColor,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // --- PERSONAL INFO CARD ---
  Widget _buildPersonalInfoCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    CompanyEmployee? currentEmp,
    WorkShift? activeShift,
    String departmentName,
    String roleLabel,
  ) {
    final shiftValue = activeShift != null
        ? '${activeShift.name} (${activeShift.startTime} - ${activeShift.endTime})'
        : 'Standard Shift (09:00 - 17:00)';

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Full Name
          _buildInfoRow(
            context: context,
            icon: Icons.person_rounded,
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
            title: 'Full Name',
            value: provider.userName,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          _buildDivider(isDark),

          // User / Employee ID
          _buildInfoRow(
            context: context,
            icon: Icons.badge_rounded,
            gradientColors: const [Color(0xFF6366F1), Color(0xFF4338CA)],
            title: provider.translate('user_id'),
            value: provider.employeeId,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trailing: _buildCopyButton('emp_id', provider.translate('user_id'), provider.employeeId, isDark),
          ),
          _buildDivider(isDark),

          // Email Address
          _buildInfoRow(
            context: context,
            icon: Icons.alternate_email_rounded,
            gradientColors: const [Color(0xFF10B981), Color(0xFF047857)],
            title: provider.translate('email'),
            value: provider.email,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            trailing: _buildCopyButton('email', provider.translate('email'), provider.email, isDark),
          ),
          _buildDivider(isDark),

          // Department (Properly resolved!)
          _buildInfoRow(
            context: context,
            icon: Icons.domain_rounded,
            gradientColors: const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
            title: provider.translate('department'),
            value: departmentName,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          _buildDivider(isDark),

          // Job Position
          _buildInfoRow(
            context: context,
            icon: Icons.work_rounded,
            gradientColors: const [Color(0xFFF59E0B), Color(0xFFB45309)],
            title: provider.translate('position'),
            value: provider.position.isNotEmpty ? provider.position : provider.userTitle,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
          _buildDivider(isDark),

          // Current Shift & Schedule
          _buildInfoRow(
            context: context,
            icon: Icons.schedule_rounded,
            gradientColors: const [Color(0xFF06B6D4), Color(0xFF0E7490)],
            title: 'Assigned Shift',
            value: shiftValue,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),

          // Phone Number (if available)
          if (currentEmp?.phoneNumber.isNotEmpty == true) ...[
            _buildDivider(isDark),
            _buildInfoRow(
              context: context,
              icon: Icons.phone_rounded,
              gradientColors: const [Color(0xFF14B8A6), Color(0xFF0F766E)],
              title: 'Phone Number',
              value: currentEmp!.phoneNumber,
              isDark: isDark,
              primaryColor: primaryColor,
              secondaryColor: secondaryColor,
              trailing: _buildCopyButton('phone', 'Phone Number', currentEmp.phoneNumber, isDark),
            ),
          ],

          _buildDivider(isDark),

          // Access Role
          _buildInfoRow(
            context: context,
            icon: Icons.admin_panel_settings_rounded,
            gradientColors: const [Color(0xFFEC4899), Color(0xFFBE185D)],
            title: provider.translate('role'),
            value: roleLabel,
            isDark: isDark,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 68,
      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
    );
  }

  Widget _buildCopyButton(String key, String title, String value, bool isDark) {
    final isCopied = _copiedKey == key;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _copyToClipboard(key, title, value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isCopied
                ? const Color(0xFF10B981).withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCopied ? Icons.check_rounded : Icons.copy_rounded,
                size: 14,
                color: isCopied ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 4),
              Text(
                isCopied ? 'Copied' : 'Copy',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCopied ? const Color(0xFF10B981) : (isDark ? Colors.white60 : Colors.black54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required List<Color> gradientColors,
    required String title,
    required String value,
    required bool isDark,
    required Color primaryColor,
    required Color secondaryColor,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          // Gradient Icon Container
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  gradientColors[0].withValues(alpha: isDark ? 0.25 : 0.12),
                  gradientColors[1].withValues(alpha: isDark ? 0.20 : 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: gradientColors[0].withValues(alpha: isDark ? 0.35 : 0.25),
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              color: gradientColors[0],
              size: 19,
            ),
          ),
          const SizedBox(width: 14),

          // Titles and Values
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: secondaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : '—',
                  style: TextStyle(
                    color: primaryColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // --- LANGUAGE SELECTOR ---
  Widget _buildLanguageSelector(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'ku', 'name': 'کوردی'},
      {'code': 'ar', 'name': 'العربية'},
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: languages.map((lang) {
          final isSelected = provider.currentLanguage == lang['code'];
          return Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                provider.setLanguage(lang['code']!);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        )
                      : null,
                  color: isSelected ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected) ...[
                      const Icon(Icons.check_rounded, color: Colors.white, size: 15),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      lang['name']!,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- THEME SELECTOR ---
  Widget _buildThemeSelector(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
  ) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Row(
        children: [
          // Light Mode Segment
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (provider.isDarkMode) {
                  HapticFeedback.selectionClick();
                  provider.toggleTheme();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: !provider.isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        )
                      : null,
                  color: !provider.isDarkMode ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: !provider.isDarkMode
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.light_mode_rounded,
                      size: 17,
                      color: !provider.isDarkMode ? Colors.white : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.translate('light_mode'),
                      style: TextStyle(
                        color: !provider.isDarkMode
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        fontSize: 13,
                        fontWeight: !provider.isDarkMode ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Dark Mode Segment
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!provider.isDarkMode) {
                  HapticFeedback.selectionClick();
                  provider.toggleTheme();
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: provider.isDarkMode
                      ? const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        )
                      : null,
                  color: provider.isDarkMode ? null : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: provider.isDarkMode
                      ? [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.dark_mode_rounded,
                      size: 17,
                      color: provider.isDarkMode ? Colors.white : const Color(0xFF6366F1),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      provider.translate('dark_mode'),
                      style: TextStyle(
                        color: provider.isDarkMode
                            ? Colors.white
                            : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        fontSize: 13,
                        fontWeight: provider.isDarkMode ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECURITY CARD (CHANGE PASSWORD) ---
  Widget _buildSecurityCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    bool isRtl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showChangePasswordDialog(context, provider),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.12),
                      const Color(0xFFD97706).withValues(alpha: isDark ? 0.20 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFFF59E0B),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('change_pwd'),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      provider.translate('update_pwd'),
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
                child: Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: secondaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- USER MANAGEMENT CARD (ADMIN / HR) ---
  Widget _buildUserManagementCard(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
    bool isRtl,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UserManagementScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cardBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: isDark ? 0.25 : 0.12),
                      const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.20 : 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.manage_accounts_rounded,
                  color: Color(0xFF6366F1),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage System Users & Roles',
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Configure employee permissions and accounts',
                      style: TextStyle(
                        color: secondaryColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                ),
                child: Icon(
                  isRtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                  color: secondaryColor,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ACCOUNT SWITCHER (TESTING) ---
  Widget _buildAccountSwitcherCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
    Color cardBg,
    Color cardBorder,
    Color primaryColor,
    Color secondaryColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: provider.employeeId,
          isExpanded: true,
          dropdownColor: cardBg,
          borderRadius: BorderRadius.circular(16),
          icon: Icon(
            Icons.unfold_more_rounded,
            color: secondaryColor,
          ),
          style: TextStyle(
            color: primaryColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          items: provider.employees.map((emp) {
            final role = _getRoleLabel(emp.role);
            final isCurrent = emp.id == provider.employeeId;
            return DropdownMenuItem<String>(
              value: emp.id,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isCurrent
                          ? const Color(0xFF2563EB).withValues(alpha: 0.2)
                          : (isDark ? Colors.white12 : const Color(0xFFF1F5F9)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emp.name.isNotEmpty ? emp.name[0].toUpperCase() : 'U',
                      style: TextStyle(
                        color: isCurrent
                            ? const Color(0xFF2563EB)
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${emp.name} ($role)',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              HapticFeedback.mediumImpact();
              provider.switchProfile(val);
            }
          },
        ),
      ),
    );
  }

  // --- SIGN OUT BUTTON ---
  Widget _buildSignOutCard(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _confirmSignOut(context, provider, isDark),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFFEF4444).withValues(alpha: 0.08)
                : const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                  : const Color(0xFFFECACA),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEF4444).withValues(alpha: 0.14),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign Out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Log out of your current session safely',
                      style: TextStyle(
                        color: isDark ? const Color(0xFFF87171).withValues(alpha: 0.7) : const Color(0xFFB91C1C).withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFEF4444),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, AttendanceProvider provider, bool isDark) {
    showGlassDialog(
      context: context,
      title: 'Sign Out',
      subtitle: 'Are you sure you want to end your session?',
      icon: Icons.logout_rounded,
      iconBackgroundColor: const [Color(0xFFEF4444), Color(0xFFDC2626)],
      content: const Text(
        'You will need to sign in again to access your attendance records and requests.',
        style: TextStyle(color: Colors.white70, fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            provider.translate('cancel'),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          onPressed: () {
            Navigator.pop(context);
            provider.logout();
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
          child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  // --- PHOTO PICKER SHEET ---
  void _showPhotoPickerSheet(BuildContext context, AttendanceProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white60 : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 24,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose how you want to update your profile photo',
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    // Camera option
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 300,
                            maxHeight: 300,
                            imageQuality: 80,
                          );
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            final base64String = base64Encode(bytes);
                            provider.updateProfileImage(base64String);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile picture updated successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.photo_camera_rounded,
                                  color: Color(0xFF2563EB),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Take Photo',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Gallery option
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 300,
                            maxHeight: 300,
                            imageQuality: 80,
                          );
                          if (image != null) {
                            final bytes = await image.readAsBytes();
                            final base64String = base64Encode(bytes);
                            provider.updateProfileImage(base64String);
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile picture updated successfully!'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.photo_library_rounded,
                                  color: Color(0xFF8B5CF6),
                                  size: 26,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Choose Gallery',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Remove Photo Option (if user has avatar)
                if (provider.avatarPath != null && provider.avatarPath!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        provider.updateProfileImage(null);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile picture removed!'),
                            backgroundColor: Color(0xFFEF4444),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Remove Photo',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  // --- CHANGE PASSWORD DIALOG ---
  void _showChangePasswordDialog(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;

    showGlassDialog(
      context: context,
      title: provider.translate('change_pwd'),
      subtitle: 'Enter and confirm your new account password',
      icon: Icons.lock_reset_rounded,
      iconBackgroundColor: const [Color(0xFFF59E0B), Color(0xFFD97706)],
      content: StatefulBuilder(
        builder: (context, setModalState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: newPasswordController,
                obscureText: obscureNew,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'New Password *',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                  hintText: provider.translate('new_pwd_hint'),
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Colors.white60, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white60,
                      size: 18,
                    ),
                    onPressed: () {
                      setModalState(() => obscureNew = !obscureNew);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirm,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Confirm Password *',
                  labelStyle: const TextStyle(color: Colors.white70, fontSize: 13),
                  hintText: 'Re-enter your new password',
                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 12),
                  prefixIcon: const Icon(Icons.verified_user_outlined, color: Colors.white60, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Colors.white60,
                      size: 18,
                    ),
                    onPressed: () {
                      setModalState(() => obscureConfirm = !obscureConfirm);
                    },
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.08),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                  ),
                ),
              ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            provider.translate('cancel'),
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
          onPressed: () {
            final newPass = newPasswordController.text.trim();
            final confirmPass = confirmPasswordController.text.trim();

            if (newPass.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a new password'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }
            if (newPass.length < 6) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password must be at least 6 characters long'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }
            if (newPass != confirmPass) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Passwords do not match'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
              return;
            }

            provider.updatePassword(newPass);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(provider.translate('pwd_success')),
                backgroundColor: const Color(0xFF10B981),
              ),
            );
          },
          child: Text(
            provider.translate('save'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
