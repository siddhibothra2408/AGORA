import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/repositories/profile_repository.dart';
import '../models/message.dart';
import '../repositories/chat_repository.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.spaceId});

  final String spaceId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textController = TextEditingController();
  bool _withholdForNext = false;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Default the withhold toggle based on user's profile default
    final profile = ref.read(currentProfileProvider).value;
    if (profile?.defaultAiConsent == DefaultAiConsent.withheld) {
      _withholdForNext = true;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    final profile = ref.read(currentProfileProvider).value;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete your profile first.')),
      );
      return;
    }

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            spaceId: widget.spaceId,
            text: text,
            sender: profile,
            aiWithheld: _withholdForNext,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send message: $e'),
          backgroundColor: AgoraColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _toggleMessageWithhold(
    Message message,
    String currentUid,
  ) async {
    if (message.senderId != currentUid) return;
    try {
      await ref
          .read(chatRepositoryProvider)
          .setMessageWithhold(
            spaceId: widget.spaceId,
            messageId: message.id,
            userId: currentUid,
            aiWithheld: !message.aiWithheld,
          );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: AgoraColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(spaceMessagesProvider(widget.spaceId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';

    return Column(
      children: [
        // Information Banner about Consent Architecture
        const AgoraBanner(
          text: 'Zero Ambient AI: AI cannot read messages unless explicitly handed off by a human.',
          icon: Icons.shield_outlined,
          backgroundColor: AgoraColors.surfaceContainer,
          textColor: AgoraColors.navy,
          borderColor: AgoraColors.surfaceBorder,
        ),

        // Message Feed
        Expanded(
          child: messagesAsync.when(
            loading: () =>
                const AgoraLoadingIndicator(message: 'Loading messages...'),
            error: (err, _) => AgoraErrorView(
              title: 'Failed to load chat',
              message: err.toString(),
              onRetry: () =>
                  ref.invalidate(spaceMessagesProvider(widget.spaceId)),
            ),
            data: (messages) {
              if (messages.isEmpty) {
                return const AgoraEmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Quiet Space',
                  message: 'Start the conversation. Remember, you control which messages can be passed to AI proposals.',
                );
              }

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AgoraSpacing.md,
                  vertical: AgoraSpacing.md,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMe = msg.senderId == currentUid;
                  return _ChatMessageBubble(
                    message: msg,
                    isMe: isMe,
                    onToggleWithhold: () =>
                        _toggleMessageWithhold(msg, currentUid),
                  );
                },
              );
            },
          ),
        ),

        // Composer
        _ChatComposer(
          controller: _textController,
          withholdForNext: _withholdForNext,
          isSending: _isSending,
          onWithholdChanged: (val) => setState(() => _withholdForNext = val),
          onSend: _handleSendMessage,
        ),
      ],
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.isMe,
    required this.onToggleWithhold,
  });

  final Message message;
  final bool isMe;
  final VoidCallback onToggleWithhold;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.createdAt);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AgoraSpacing.xs),
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          // Author Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AgoraSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? 'You' : message.senderDisplayName,
                  style: AgoraTypography.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isMe ? AgoraColors.aegean : AgoraColors.navyDark,
                  ),
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Text(
                  '@${message.senderHandle} · $timeStr',
                  style: AgoraTypography.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),

          // Bubble Container
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            padding: const EdgeInsets.all(AgoraSpacing.md),
            decoration: BoxDecoration(
              color: isMe ? AgoraColors.aegeanContainer : AgoraColors.surface,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AgoraRadius.md),
                topRight: const Radius.circular(AgoraRadius.md),
                bottomLeft: Radius.circular(isMe ? AgoraRadius.md : 2),
                bottomRight: Radius.circular(isMe ? 2 : AgoraRadius.md),
              ),
              border: Border.all(
                color: isMe
                    ? AgoraColors.aegeanContainerBorder
                    : AgoraColors.surfaceBorder,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.text,
                  style: AgoraTypography.bodyLarge.copyWith(
                    color: AgoraColors.navyDark,
                  ),
                ),
                const SizedBox(height: AgoraSpacing.xs),

                // Consent indicator & toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AgoraConsentBadge(isWithheld: message.aiWithheld),
                    if (isMe) ...[
                      const SizedBox(width: AgoraSpacing.xs),
                      InkWell(
                        onTap: onToggleWithhold,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Text(
                            message.aiWithheld ? 'Make eligible' : 'Withhold',
                            style: AgoraTypography.labelSmall.copyWith(
                              color: AgoraColors.navySubtle,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.withholdForNext,
    required this.isSending,
    required this.onWithholdChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool withholdForNext;
  final bool isSending;
  final ValueChanged<bool> onWithholdChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surface,
        border: Border(
          top: BorderSide(color: AgoraColors.surfaceBorder, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AgoraSpacing.md,
        vertical: AgoraSpacing.sm,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Author Consent Toggle Bar
            Row(
              children: [
                Icon(
                  withholdForNext ? Icons.shield : Icons.shield_outlined,
                  size: 16,
                  color: withholdForNext
                      ? AgoraColors.withhold
                      : AgoraColors.navySubtle,
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Expanded(
                  child: Text(
                    withholdForNext
                        ? 'Withheld: AI will never ingest this message'
                        : 'Eligible for manual handoff',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: withholdForNext
                          ? AgoraColors.withhold
                          : AgoraColors.navySubtle,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: withholdForNext,
                  onChanged: onWithholdChanged,
                  activeTrackColor: AgoraColors.withhold,
                ),
              ],
            ),
            const SizedBox(height: AgoraSpacing.xs),

            // Text Entry and Send Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: AgoraTypography.bodyLarge.copyWith(
                      color: AgoraColors.navyDark,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Share with the space...',
                      border: OutlineInputBorder(
                        borderRadius: AgoraRadius.borderLg,
                        borderSide: const BorderSide(
                          color: AgoraColors.surfaceBorder,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AgoraSpacing.md,
                        vertical: AgoraSpacing.sm,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AgoraColors.aegean,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.arrow_upward,
                            color: Colors.white,
                            size: 20,
                          ),
                    onPressed: isSending ? null : onSend,
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
