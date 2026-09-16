import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../widgets/glass_dialog.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/avatar_image_helper.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: Container(
          // Use standard flat background
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF9FAFB),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                // Custom Header App Bar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 10.0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildBackButton(context),
                      Text(
                        provider.translate('profile'),
                        style: TextStyle(
                          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(
                        width: 44,
                      ), // Spacer to balance the back button
                    ],
                  ),
                ),

                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile Card
                        _buildProfileCard(context, provider),
                        SizedBox(height: 24),

                        // Personal Information Section
                        Text(
                          provider.translate('personal_info'),
                          style: TextStyle(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildPersonalInfoCard(provider, context),
                        SizedBox(height: 24),

                        // Language Selection Section
                        Text(
                          provider.translate('change_language'),
                          style: TextStyle(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildLanguageCard(provider, context),
                        SizedBox(height: 24),

                        // Theme Selection Section
                        Text(
                          provider.translate('theme') == 'theme' ? 'Theme Options' : provider.translate('theme'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7) ?? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildThemeCard(provider, context),
                        SizedBox(height: 24),

                        // Security Section
                        Text(
                          provider.translate('security'),
                          style: TextStyle(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildSecurityCard(context, provider),
                        SizedBox(height: 24),

                        // Account Switcher Section (Testing Only)
                        Text(
                          provider.translate('switch_account'),
                          style: TextStyle(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 12),
                        _buildAccountSwitcherCard(provider, context),
                        SizedBox(height: 24),

                        // Sign Out Section
                        _buildLogoutCard(provider, context),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.08)),
          border: Border.all(
            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.2)),
            width: 1,
          ),
        ),
        child: Icon(Icons.arrow_back, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 20),
      ),
    );
  }

  void _showPhotoPickerSheet(BuildContext context, AttendanceProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.15)),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.3)),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'Profile Photo',
                  style: TextStyle(
                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Choose how you want to update your profile photo',
                  style: TextStyle(
                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 24),
                Row(
                  children: [
                    // Camera option
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.camera,
                            maxWidth: 200,
                            maxHeight: 200,
                            imageQuality: 70,
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
                                  backgroundColor: Color(0xFF2EBD96),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.06)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_camera_outlined, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 32),
                              SizedBox(height: 12),
                              Text(
                                'Take Photo',
                                style: TextStyle(
                                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Gallery option
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picker = ImagePicker();
                          final image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 200,
                            maxHeight: 200,
                            imageQuality: 70,
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
                                  backgroundColor: Color(0xFF2EBD96),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.06)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1)),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.photo_library_outlined, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 32),
                              SizedBox(height: 12),
                              Text(
                                'Choose Photo',
                                style: TextStyle(
                                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (provider.avatarPath != null && provider.avatarPath!.isNotEmpty) ...[
                  SizedBox(height: 16),
                  // Delete option
                  GestureDetector(
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
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline, color: Color(0xFFF87171), size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Remove Photo',
                            style: TextStyle(
                              color: Color(0xFFFCA5A5),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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

  Widget _buildProfileCard(BuildContext context, AttendanceProvider provider) {
    final avatarProvider = getAvatarProvider(provider.avatarPath);
    return GlassContainer(
      child: Center(
        child: Column(
          children: [
            // Profile image with edit overlay
            Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: avatarProvider != null ? null : const Color(0xFF3B82F6),
                    image: avatarProvider != null
                        ? DecorationImage(
                            image: avatarProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), width: 2),
                  ),
                  child: avatarProvider != null
                      ? null
                      : Center(
                          child: Icon(
                            Icons.person_outline,
                            color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                            size: 56,
                          ),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _showPhotoPickerSheet(context, provider),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E65FF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.photo_camera,
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            // User name
            Text(
              provider.userName,
              style: TextStyle(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            // Title
            Text(
              provider.userTitle,
              style: TextStyle(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard(AttendanceProvider provider, BuildContext context) {
    String roleLabel = 'Employee';
    if (provider.currentEmployee?.role == 'hr') {
      roleLabel = 'HR Manager';
    } else if (provider.currentEmployee?.role == 'supervisor') {
      roleLabel = 'Supervisor';
    }

    return GlassContainer(
      padding: EdgeInsets.zero, // Zero padding to build clean list rows
      child: Column(
        children: [
          _buildInfoRow(context, 
            icon: Icons.person_outline,
            iconBg: const Color(0xFF2E65FF), // Blue
            title: provider.translate('user_id'),
            value: provider.employeeId,
          ),
          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
          _buildInfoRow(context, 
            icon: Icons.mail_outline,
            iconBg: const Color(0xFF2EBD96), // Green
            title: provider.translate('email'),
            value: provider.email,
          ),
          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
          _buildInfoRow(context, 
            icon: Icons.business_outlined,
            iconBg: const Color(0xFF8236FE), // Purple/Indigo
            title: provider.translate('department'),
            value: provider.department,
          ),
          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
          _buildInfoRow(context, 
            icon: Icons.work_outline,
            iconBg: const Color(0xFFF59E0B), // Orange/Brown
            title: provider.translate('position'),
            value: provider.position,
          ),
          Divider(color: (Theme.of(context).brightness == Brightness.dark ? Colors.white10 : Colors.black12), height: 1),
          _buildInfoRow(context, 
            icon: Icons.security_outlined,
            iconBg: const Color(0xFFEC4899), // Pink
            title: provider.translate('role'),
            value: roleLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
      child: Row(
        children: [
          // Icon container with rounded shape
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconBg.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: iconBg.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Icon(icon, color: iconBg, size: 20),
          ),
          SizedBox(width: 16),
          // Titles
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard(AttendanceProvider provider, BuildContext context) {
    final languages = [
      {'code': 'en', 'name': 'English'},
      {'code': 'ku', 'name': 'کوردی'},
      {'code': 'ar', 'name': 'العربية'},
    ];

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: languages.map((lang) {
          final isSelected = provider.currentLanguage == lang['code'];
          return Expanded(
            child: GestureDetector(
              onTap: () => provider.setLanguage(lang['code']!),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2E65FF)
                      : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2E65FF)
                        : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.15)),
                    width: 1,
                  ),
                ),
                child: Text(
                  lang['name']!,
                  style: TextStyle(
                    color: isSelected
                        ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))
                        : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeCard(AttendanceProvider provider, BuildContext context) {
    final themes = [
      {'value': 'dark', 'name': 'Dark'},
      {'value': 'light', 'name': 'Light'},
    ];
    final isDarkContext = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: themes.map((theme) {
          final isSelected = (theme['value'] == 'dark' && provider.isDarkMode) || 
                             (theme['value'] == 'light' && !provider.isDarkMode);
          
          return Expanded(
            child: GestureDetector(
              onTap: () {
                if (!isSelected) {
                  provider.toggleTheme();
                }
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2E65FF)
                      : (isDarkContext ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.08)) : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2E65FF)
                        : (isDarkContext ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.15)) : Colors.black.withValues(alpha: 0.1)),
                    width: 1,
                  ),
                ),
                child: Text(
                  theme['name']!,
                  style: TextStyle(
                    color: isSelected
                        ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))
                        : (isDarkContext ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)) : Colors.black.withValues(alpha: 0.7)),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSecurityCard(BuildContext context, AttendanceProvider provider) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: () => _showChangePasswordDialog(context, provider),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEC4899).withValues(alpha: 0.2), // Pink
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.lock_outline,
                  color: Color(0xFFEC4899),
                  size: 20,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      provider.translate('change_pwd'),
                      style: TextStyle(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      provider.translate('update_pwd'),
                      style: TextStyle(
                        color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSwitcherCard(AttendanceProvider provider, BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Theme(
        data: ThemeData.dark().copyWith(canvasColor: const Color(0xFF1E293B)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: provider.employeeId,
            isExpanded: true,
            icon: Icon(Icons.swap_horiz, color: (Theme.of(context).brightness == Brightness.dark ? Colors.white60 : Colors.black54)),
            style: TextStyle(
              color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            items: provider.employees.map((emp) {
              String roleLabel = 'Employee';
              if (emp.role == 'hr') {
                roleLabel = 'HR Manager';
              } else if (emp.role == 'supervisor') {
                roleLabel = 'Supervisor';
              }

              return DropdownMenuItem<String>(
                value: emp.id,
                child: Text('${emp.name} ($roleLabel)'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                provider.switchProfile(val);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutCard(AttendanceProvider provider, BuildContext context) {
    return GestureDetector(
      onTap: () {
        provider.logout();
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        borderColor: Colors.red.withValues(alpha: 0.3),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 22,
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
                      color: Colors.redAccent,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Log out of your current session',
                    style: TextStyle(
                      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.5)),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.redAccent,
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final controller = TextEditingController();

    showGlassDialog(
      context: context,
      title: provider.translate('change_pwd'),
      subtitle: 'Update your account password',
      icon: Icons.lock_outline,
      iconBackgroundColor: [Color(0xFFF59E0B), Color(0xFFD97706)], // Orange theme for security
      content: TextField(
        controller: controller,
        obscureText: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: provider.translate('new_pwd_hint'),
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
          ),
          focusedBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF2E65FF)),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            provider.translate('cancel'),
            style: const TextStyle(color: Colors.white70),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E65FF),
          ),
          onPressed: () {
            if (controller.text.isNotEmpty) {
              provider.updatePassword(controller.text);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(provider.translate('pwd_success')),
                  backgroundColor: const Color(0xFF2EBD96),
                ),
              );
            }
          },
          child: Text(
            provider.translate('save'),
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }
}
