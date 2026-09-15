import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/glass_container.dart';
import '../widgets/custom_calendar.dart';
import '../widgets/stat_card.dart';
import '../widgets/avatar_image_helper.dart';
import 'main_navigation_screen.dart';
import 'profile_screen.dart';
import 'hr_management_screen.dart';
import 'chat_list_screen.dart';
import 'face_auth_screen.dart';
import '../widgets/company_settings_dialog.dart';

class HomeScreenMobile extends StatelessWidget {
  const HomeScreenMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background gradient is on the shell
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        provider.translate('welcome_back'),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color?.withValues(alpha: 0.7) ?? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        provider.userName,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyLarge?.color ?? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  // Header Buttons
                  Row(
                    children: [
                      if (provider.canEditCompanyInfo) ...[
                        _buildHeaderButton(context, 
                          icon: Icons.settings_outlined,
                          onTap: () {
                            showCompanySettingsDialog(context);
                          },
                        ),
                        SizedBox(width: 12),
                        _buildHeaderButton(context, 
                          icon: Icons.admin_panel_settings_outlined,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const HrManagementScreen(),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 12),
                      ],
                      _buildHeaderButton(context, 
                        icon: Icons.chat_bubble_outline_rounded,
                        hasBadge: provider.hasUnreadMessages,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ChatListScreen(),
                            ),
                          );
                        },
                      ),
                      SizedBox(width: 12),
                      _buildHeaderButton(context, 
                        icon: Icons.person_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ProfileScreen(),
                            ),
                          );
                        },
                        isProfile: true,
                        avatarUrl: provider.avatarPath,
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),

              // Date Title
              Center(
                child: Text(
                  todayStr,
                  style: TextStyle(
                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.8)),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Clock Status Card
              _buildClockStatusCard(context, provider),
              SizedBox(height: 20),

              // Calendar Card
              const CustomCalendar(),
              SizedBox(height: 20),

              // Statistics Grid
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 800 ? 4 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: MediaQuery.of(context).size.width > 800 ? 1.5 : 1.15,
                children: [
                  StatCard(
                    icon: Icons.access_time_outlined,
                    value: provider.weeklyHours.toStringAsFixed(1),
                    label: provider.translate('weekly_hours'),
                    accentColor: const Color(0xFF9AA0EE), // light blue
                  ),
                  StatCard(
                    icon: Icons.attach_money_outlined,
                    value:
                        '\$${NumberFormat('#,##0').format(provider.monthlyEarnings)}',
                    label: provider.translate('monthly_earnings'),
                    accentColor: const Color(0xFF82A6DD), // steel blue
                  ),
                  StatCard(
                    icon: Icons.calendar_today_outlined,
                    value: '${provider.daysWorked}',
                    label: provider.translate('days_worked'),
                    accentColor: const Color(0xFFB08CD8), // purple/pink
                  ),
                  StatCard(
                    icon: Icons.trending_up_outlined,
                    value: '${provider.overtimeHours.toStringAsFixed(1)}h',
                    label: provider.translate('overtime'),
                    accentColor: const Color(0xFFC88BE8), // pinkish
                  ),
                  StatCard(
                    icon: Icons.account_balance_wallet_outlined,
                    value: '${provider.currentEmployee?.annualLeaveBalance ?? 0}h',
                    label: 'Remain Balance',
                    accentColor: const Color(0xFF9AA0EE), // light blue
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Quick Actions
              Text(
                provider.translate('quick_actions'),
                style: TextStyle(
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 12),
              _buildQuickActionButton(
                context: context,
                label: provider.translate('view_history'),
                icon: Icons.calendar_today_outlined,
                targetTab: 2,
              ),
              SizedBox(height: 12),
              _buildQuickActionButton(
                context: context,
                label: provider.translate('view_payroll'),
                icon: Icons.attach_money_outlined,
                targetTab: 3,
              ),
              SizedBox(height: 12),
              _buildChatQuickActionButton(
                context: context,
                label: provider.translate('chat'),
                icon: Icons.chat_bubble_outline_rounded,
                hasBadge: provider.hasUnreadMessages,
              ),

              // Extra padding to scroll above bottom nav bar
              SizedBox(height: 100),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }

  Widget _buildHeaderButton(BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    bool isProfile = false,
    String? avatarUrl,
    bool hasBadge = false,
  }) {
    final avatarProvider = isProfile ? getAvatarProvider(avatarUrl) : null;
    return GestureDetector(
      onTap: onTap,
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
          image: avatarProvider != null
              ? DecorationImage(
                  image: avatarProvider,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (avatarProvider == null)
              Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)), size: 20),
            if (hasBadge)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildClockStatusCard(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final hasClockedIn = provider.isClockedIn;
    bool isProcessing = false;

    return GlassContainer(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.translate('current_status'),
                    style: TextStyle(
                      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6)),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    hasClockedIn
                        ? provider.translate('clocked_in')
                        : provider.translate('clocked_out'),
                    style: TextStyle(
                      color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Clock Icon on grey/black rounded background
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black.withValues(alpha: 0.35),
                  border: Border.all(
                    color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1)),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.access_time,
                  color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.7)),
                  size: 26,
                ),
              ),
            ],
          ),
          SizedBox(height: 18),

          // Action Buttons
          StatefulBuilder(
            builder: (context, setState) {
              Widget buildButton({
                required String label,
                required bool isActive,
                required Color color,
                required Future<void> Function() onTap,
              }) {
                return Expanded(
                  child: GestureDetector(
                    onTap: (isActive && !isProcessing)
                        ? () async {
                            setState(() {
                              isProcessing = true;
                            });
                            try {
                              await onTap();
                            } finally {
                              if (context.mounted) {
                                setState(() {
                                  isProcessing = false;
                                });
                              }
                            }
                          }
                        : null,
                    child: Container(
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isActive
                            ? (isProcessing
                                ? color.withValues(alpha: 0.5)
                                : color)
                            : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          if (isActive && !isProcessing)
                            BoxShadow(
                              color: color.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                        ],
                      ),
                      child: isProcessing && isActive
                          ? SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))),
                              ),
                            )
                          : Text(
                              label,
                              style: TextStyle(
                                color: isActive
                                    ? ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black))
                                    : ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.3)),
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                );
              }

              if (kIsWeb) return const SizedBox.shrink();

              return Row(
                children: [
                  buildButton(
                    label: provider.translate('clock_in_btn'),
                    isActive: !hasClockedIn,
                    color: const Color(0xFF1AD579), // Green
                    onTap: () async {
                      final locError = await provider.verifyLocation();
                      if (locError != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locError),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }

                      if (provider.currentEmployee?.faceEmbedding != null) {
                        if (!context.mounted) return;
                        final success = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FaceAuthScreen(
                              targetEmbedding: provider.currentEmployee!.faceEmbedding,
                            ),
                          ),
                        );
                        
                        if (success != true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.translate('face_auth_failed') != 'face_auth_failed' ? provider.translate('face_auth_failed') : 'Face authentication failed or cancelled.'),
                                backgroundColor: Colors.redAccent,
                              )
                            );
                          }
                          return;
                        }
                      }

                      final error = await provider.clockIn();
                      if (!context.mounted) return;
                      if (error == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.translate('success_clock_in')),
                            backgroundColor: const Color(0xFF2EBD96),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(error),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(width: 16),
                  buildButton(
                    label: provider.translate('clock_out_btn'),
                    isActive: true, // Always active so they can clock out if they forgot check in
                    color: const Color(0xFFFF4B4B), // Red
                    onTap: () async {
                      final locError = await provider.verifyLocation();
                      if (locError != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(locError),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }

                      if (provider.currentEmployee?.faceEmbedding != null) {
                        if (!context.mounted) return;
                        final success = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FaceAuthScreen(
                              targetEmbedding: provider.currentEmployee!.faceEmbedding,
                            ),
                          ),
                        );
                        
                        if (success != true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(provider.translate('face_auth_failed') != 'face_auth_failed' ? provider.translate('face_auth_failed') : 'Face authentication failed or cancelled.'),
                                backgroundColor: Colors.redAccent,
                              )
                            );
                          }
                          return;
                        }
                      }

                      final result = await provider.clockOut();
                      if (!context.mounted) return;
                      if (result == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.translate('success_clock_out')),
                            backgroundColor: const Color(0xFF2EBD96),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      } else if (result == 'missed_checkin') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Clocked out successfully, but check-in was missed! Please submit a Missing Punch.'),
                            backgroundColor: Color(0xFFFFA726), // Orange warning
                            duration: Duration(seconds: 4),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result),
                            backgroundColor: const Color(0xFFFF5C5C),
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required int targetTab,
  }) {
    return GestureDetector(
      onTap: () {
        context
            .findAncestorStateOfType<MainNavigationScreenState>()
            ?.onTabSelected(targetTab);
      },
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.8)), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChatQuickActionButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    bool hasBadge = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ChatListScreen()),
        );
      },
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black)),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: ((Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.8)), size: 20),
                if (hasBadge)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
