import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/app_notification.dart';
import '../providers/attendance_provider.dart';
import '../screens/chat_room_screen.dart';
import '../screens/requests_screen.dart';
import '../services/web_notification_helper.dart';

void showWebNotificationsDialog(BuildContext context) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Notifications',
    barrierColor: Colors.black.withValues(alpha: 0.4),
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (ctx, anim, secondAnim, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, anim, secondAnim) {
      return const WebNotificationsDialog();
    },
  );
}

class WebNotificationsDialog extends StatelessWidget {
  const WebNotificationsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final notifications = provider.notifications;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadCount = notifications.where((n) => !n.isRead).length;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0),
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                width: 480,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.75,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.95),
                  border: Border.all(
                    color: isDark ? Colors.white12 : Colors.black12,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF2E65FF), Color(0xFF8236FE)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Notifications',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  notifications.isEmpty
                                      ? 'No new alerts'
                                      : '$unreadCount unread',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white54 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (notifications.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                provider.markAllNotificationsAsRead();
                              },
                              child: const Text(
                                'Mark all read',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2E65FF),
                                ),
                              ),
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white70 : Colors.black54,
                              size: 20,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Enable Desktop Notifications Banner (Web only)
                    if (kIsWeb)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: const Color(0xFF2E65FF).withValues(alpha: 0.08),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.computer_rounded,
                              size: 18,
                              color: Color(0xFF2E65FF),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Enable browser notifications for live alerts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF2E65FF),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                await requestWebNotificationPermission();
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                backgroundColor: const Color(0xFF2E65FF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Enable',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Notifications List
                    Flexible(
                      child: notifications.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(40.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.notifications_none_rounded,
                                    size: 48,
                                    color: (isDark ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.2),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No notifications yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'You will see new messages and updates here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.white38
                                          : Colors.black45,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: notifications.length,
                              separatorBuilder: (ctx, i) => Divider(
                                height: 1,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.05),
                              ),
                              itemBuilder: (ctx, index) {
                                final item = notifications[index];
                                return _buildNotificationTile(
                                  context,
                                  provider,
                                  item,
                                  isDark,
                                );
                              },
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

  Widget _buildNotificationTile(
    BuildContext context,
    AttendanceProvider provider,
    AppNotification item,
    bool isDark,
  ) {
    final timeStr = DateFormat('h:mm a').format(item.timestamp);

    return InkWell(
      onTap: () {
        provider.markNotificationAsRead(item.id);
        Navigator.of(context).pop();

        if (item.type == NotificationType.chat && item.relatedId != null) {
          final contact = provider.employees
              .where((e) => e.id == item.relatedId)
              .firstOrNull;
          if (contact != null) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatRoomScreen(contact: contact),
              ),
            );
          }
        } else if (item.type == NotificationType.request) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const RequestsScreen(),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: !item.isRead
            ? const Color(0xFF2E65FF).withValues(alpha: isDark ? 0.12 : 0.06)
            : Colors.transparent,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.type == NotificationType.chat
                    ? const Color(0xFF2E65FF).withValues(alpha: 0.15)
                    : const Color(0xFF8236FE).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                item.type == NotificationType.chat
                    ? Icons.chat_bubble_outline_rounded
                    : Icons.description_outlined,
                size: 18,
                color: item.type == NotificationType.chat
                    ? const Color(0xFF2E65FF)
                    : const Color(0xFF8236FE),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.black38,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: Color(0xFF2E65FF),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
