import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../models/hr_models.dart';
import '../models/chat_message.dart';
import '../widgets/glass_container.dart';
import '../widgets/avatar_image_helper.dart';

class ChatRoomScreen extends StatefulWidget {
  final CompanyEmployee contact;
  const ChatRoomScreen({super.key, required this.contact});

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollToBottom(isInit: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<AttendanceProvider>(context, listen: false)
            .ensureChatLoaded(widget.contact.id);
      }
    });
  }

  void _scrollToBottom({bool isInit = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (isInit) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  void _sendMessage(AttendanceProvider provider) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    provider.sendChatMessage(widget.contact.id, text);
    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final messages = provider.getMessagesWith(widget.contact.id);
    final currentUser = provider.currentEmployee;

    // Mark messages as read when viewing the chat room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        provider.markMessagesAsRead(widget.contact.id);
      }
    });

    // Trigger auto-scroll on new message list length
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Directionality(
      textDirection: provider.currentLanguageDirection,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF2E65FF), Color(0xFF8236FE)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar / Header
                _buildHeader(context, provider),

                // Message List
                Expanded(
                  child: messages.isEmpty
                      ? _buildEmptyChat(provider)
                      : ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 16.0,
                          ),
                          itemCount: messages.length,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isMe =
                                message.senderId == provider.employeeId;
                            return _buildMessageBubble(
                              context,
                              message,
                              isMe,
                              provider,
                              currentUser,
                            );
                          },
                        ),
                ),

                // Input Section
                _buildInputSection(provider),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AttendanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        children: [
          // Back Button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          _buildAvatar(widget.contact),
          const SizedBox(width: 12),

          // Contact Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.contact.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.contact.position,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(CompanyEmployee contact) {
    final avatarProvider = getAvatarProvider(contact.avatarUrl);
    final initials = contact.name.isNotEmpty
        ? contact.name.substring(0, 1).toUpperCase()
        : 'E';
    final List<Color> gradientColors = contact.role == 'supervisor'
        ? [const Color(0xFFEC4899), const Color(0xFF8236FE)]
        : [const Color(0xFF2E65FF), const Color(0xFF2EBD96)];

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: avatarProvider != null ? null : LinearGradient(colors: gradientColors),
        image: avatarProvider != null
            ? DecorationImage(
                image: avatarProvider,
                fit: BoxFit.cover,
              )
            : null,
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      child: avatarProvider != null
          ? null
          : Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }

  Widget _buildEmptyChat(AttendanceProvider provider) {
    return Center(
      child: Text(
        provider
            .translate('chat_with')
            .replaceAll('{name}', widget.contact.name),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ChatMessage message,
    bool isMe,
    AttendanceProvider provider,
    CompanyEmployee? currentUser,
  ) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: message.isRequestCard
            ? _buildRequestCard(context, message, isMe, provider, currentUser)
            : _buildTextBubble(context, message, isMe),
      ),
    );
  }

  Widget _buildTextBubble(
    BuildContext context,
    ChatMessage message,
    bool isMe,
  ) {
    final bg = isMe
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2E65FF), Color(0xFF4F46E5)],
          )
        : LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.12),
              Colors.white.withValues(alpha: 0.08),
            ],
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        gradient: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
          bottomRight: isMe ? Radius.zero : const Radius.circular(16),
        ),
        border: Border.all(
          color: isMe
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    ChatMessage message,
    bool isMe,
    AttendanceProvider provider,
    CompanyEmployee? currentUser,
  ) {
    // Resolve the active request details from provider
    // The request can be owned by sender (if employee sent it) or receiver
    final requestOwnerId = widget.contact.role == 'employee'
        ? widget.contact.id
        : provider.employeeId;
    final request = provider.getRequestById(
      requestOwnerId,
      message.requestId ?? '',
    );

    if (request == null) {
      // Fallback if request is not found
      return _buildTextBubble(context, message, isMe);
    }

    final isSupervisor =
        currentUser?.role == 'supervisor' || currentUser?.role == 'hr';
    final isPending = request.status == 'Pending';
    final translatedType = _translateRequestType(request.type, provider);

    return GlassContainer(
      padding: const EdgeInsets.all(14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    color: Colors.white70,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    translatedType,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: request.statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: request.statusColor.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  _translateRequestStatus(request.status, provider),
                  style: TextStyle(
                    color: request.statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(color: Colors.white12, height: 1),
          ),

          // Request details
          Text(
            '${provider.translate('date')}: ${request.date}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            '${provider.translate('duration')}: ${request.duration}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          
          if (request.note != null && request.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined, color: Colors.white54, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      request.note!,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),

          // Action buttons for supervisor if request is Pending
          if (isPending && isSupervisor) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Reject Button
                GestureDetector(
                  onTap: () async {
                    await provider.updateRequestStatus(
                      requestOwnerId,
                      request.id,
                      'Rejected',
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.contact.name}\'s request rejected.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.close,
                          color: Color(0xFFF87171),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.translate('reject'),
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Approve Button
                GestureDetector(
                  onTap: () async {
                    await provider.updateRequestStatus(
                      requestOwnerId,
                      request.id,
                      'Approved',
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '${widget.contact.name}\'s request approved.',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check,
                          color: Color(0xFF34D399),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          provider.translate('approve'),
                          style: const TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 4),
          Align(
            alignment: Alignment.bottomRight,
            child: Text(
              _formatTime(message.timestamp),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputSection(AttendanceProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          // Glassmorphic Input Bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    cursorColor: const Color(0xFF2E65FF),
                    decoration: InputDecoration(
                      hintText: provider.translate('write_message'),
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendMessage(provider),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
          GestureDetector(
            onTap: () => _sendMessage(provider),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2E65FF), Color(0xFF8236FE)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  String _translateRequestType(String rawType, AttendanceProvider provider) {
    switch (rawType) {
      case 'Annual Leave':
        return provider.translate('vacation_leave');
      case 'Sick Leave':
        return provider.translate('sick_leave');
      case 'Overtime Approval':
        return provider.translate('overtime_approval');
      case 'Forgot to Clock Out':
        return provider.translate('forgot_to_clock_out');
      default:
        return rawType;
    }
  }

  String _translateRequestStatus(
    String rawStatus,
    AttendanceProvider provider,
  ) {
    switch (rawStatus) {
      case 'Approved':
        return provider.translate('status_approved');
      case 'Pending':
        return provider.translate('status_pending');
      case 'Rejected':
        return provider.translate('status_rejected');
      default:
        return rawStatus;
    }
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
