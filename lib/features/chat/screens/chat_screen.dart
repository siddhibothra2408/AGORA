import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_badge.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../handoffs/repositories/handoff_repository.dart';
import '../../handoffs/screens/ai_ledger_screen.dart';
import '../../handoffs/widgets/handoff_preview_sheet.dart';
import '../../handoffs/widgets/proposal_tray_sheet.dart';
import '../../items/repositories/item_repository.dart';
import '../../profile/models/user_profile.dart';
import '../../profile/repositories/profile_repository.dart';
import '../../spaces/models/catch_up_summary.dart';
import '../../spaces/repositories/space_repository.dart';
import '../../spaces/widgets/catch_up_card.dart';
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
  bool _catchUpDismissed = false;

  // Lens Mode State
  bool _isLensMode = false;
  final Set<String> _selectedMessageIds = {};

  // Reply Context State
  Message? _replyToMessage;

  // Snapshot of lastReadAt captured when entering the space
  DateTime? _initialLastReadAt;
  bool _hasCapturedSnapshot = false;
  static DateTime? _lastRecordedTime;

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
    _recordLastReadAt();
    _textController.dispose();
    super.dispose();
  }

  void _recordLastReadAt() {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null || uid.isEmpty) return;

    final now = DateTime.now();
    if (_lastRecordedTime != null &&
        now.difference(_lastRecordedTime!).inSeconds < 10) {
      return;
    }
    _lastRecordedTime = now;

    try {
      ref
          .read(spaceRepositoryProvider)
          .updateLastReadAt(spaceId: widget.spaceId, uid: uid)
          .catchError((_) {});
    } catch (_) {}
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
    final replyId = _replyToMessage?.id;
    _textController.clear();

    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(
            spaceId: widget.spaceId,
            text: text,
            sender: profile,
            replyToId: replyId,
            aiWithheld: _withholdForNext,
          );
      if (mounted && _replyToMessage != null) {
        setState(() => _replyToMessage = null);
      }
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

  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        if (_selectedMessageIds.isEmpty) {
          _isLensMode = false;
        }
      } else {
        if (_selectedMessageIds.length >= 50) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 50 messages per handoff.')),
          );
          return;
        }
        _selectedMessageIds.add(messageId);
      }
    });
  }

  void _enterLensModeWith(String messageId) {
    setState(() {
      _isLensMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(messageId);
    });
  }

  void _exitLensMode() {
    setState(() {
      _isLensMode = false;
      _selectedMessageIds.clear();
    });
  }

  void _showHandoffPreview() {
    if (_selectedMessageIds.isEmpty) return;
    HandoffPreviewSheet.show(
      context,
      spaceId: widget.spaceId,
      selectedMessageIds: _selectedMessageIds.toList(),
      onCompleted: _exitLensMode,
    );
  }

  void _showMessageOptions(Message message, bool isMe) {
    final canEdit =
        isMe &&
        !message.isDeleted &&
        DateTime.now().difference(message.createdAt).inMinutes < 15;
    final canDelete = isMe && !message.isDeleted;

    showModalBottomSheet(
      context: context,
      backgroundColor: AgoraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.lg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.auto_awesome,
                color: AgoraColors.goldDark,
              ),
              title: const Text('Hand to AI (Lens Mode)'),
              subtitle: const Text(
                'Select this message for manual AI extraction',
              ),
              onTap: () {
                Navigator.of(ctx).pop();
                _enterLensModeWith(message.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.reply, color: AgoraColors.navy),
              title: const Text('Reply'),
              onTap: () {
                Navigator.of(ctx).pop();
                setState(() => _replyToMessage = message);
              },
            ),
            if (canEdit)
              ListTile(
                leading: const Icon(
                  Icons.edit_outlined,
                  color: AgoraColors.navy,
                ),
                title: const Text('Edit message'),
                subtitle: const Text('Available within 15 minutes of sending'),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showEditDialog(message);
                },
              ),
            if (canDelete)
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AgoraColors.error,
                ),
                title: const Text(
                  'Delete message',
                  style: TextStyle(color: AgoraColors.error),
                ),
                subtitle: const Text(
                  'Leaves a tombstone record per audit rule',
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  await ref
                      .read(chatRepositoryProvider)
                      .deleteMessage(
                        spaceId: widget.spaceId,
                        messageId: message.id,
                      );
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(Message message) {
    final editController = TextEditingController(text: message.text);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Message'),
        content: TextField(
          controller: editController,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Update message content...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.text) {
                Navigator.of(ctx).pop();
                await ref
                    .read(chatRepositoryProvider)
                    .editMessage(
                      spaceId: widget.spaceId,
                      messageId: message.id,
                      newText: newText,
                    );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showFootprintSheet(BuildContext context, Message message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AgoraColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.lg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AgoraSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AgoraColors.goldDark,
                    size: 20,
                  ),
                  const SizedBox(width: AgoraSpacing.sm),
                  Text(
                    'AI Footprint Record',
                    style: AgoraTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AgoraSpacing.sm),
              Text(
                'This message was explicitly handed to AI ${message.aiSeenCount} times by Space members.',
                style: AgoraTypography.bodyMedium,
              ),
              const SizedBox(height: AgoraSpacing.md),
              Text(
                'Full audit logs with timestamps and exact handed payloads are recorded in the AI Ledger.',
                style: AgoraTypography.bodySmall,
              ),
              const SizedBox(height: AgoraSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AgoraColors.aegean,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.history_edu, size: 18),
                  label: const Text('Open AI Ledger'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    AiLedgerScreen.show(context, widget.spaceId);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(spaceMessagesProvider(widget.spaceId));
    final currentUid = ref.watch(currentUserIdProvider) ?? '';
    final memberAsync = ref.watch(
      spaceMemberProvider((spaceId: widget.spaceId, uid: currentUid)),
    );
    final itemsAsync = ref.watch(
      spaceItemsProvider((spaceId: widget.spaceId, type: null)),
    );
    final handoffsAsync = ref.watch(spaceHandoffsProvider(widget.spaceId));
    final proposalsAsync = ref.watch(pendingProposalsProvider(widget.spaceId));

    // Capture initial lastReadAt snapshot on first load
    if (!_hasCapturedSnapshot && memberAsync.hasValue) {
      _initialLastReadAt = memberAsync.value?.lastReadAt;
      _hasCapturedSnapshot = true;
    }

    // Calculate CatchUpSummary
    CatchUpSummary? catchUpSummary;
    if (!_catchUpDismissed &&
        _hasCapturedSnapshot &&
        _initialLastReadAt != null) {
      catchUpSummary = CatchUpSummary.calculate(
        lastReadAt: _initialLastReadAt,
        messages: messagesAsync.value ?? [],
        items: itemsAsync.value ?? [],
        handoffs: handoffsAsync.value ?? [],
        currentUserId: currentUid,
      );
    }

    final pendingCount = proposalsAsync.value?.length ?? 0;

    return Column(
      children: [
        // Information Banner or Lens Banner
        if (!_isLensMode) ...[
          Container(
            color: AgoraColors.surfaceContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.md,
              vertical: AgoraSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  size: 16,
                  color: AgoraColors.navy,
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Expanded(
                  child: Text(
                    'Zero Ambient AI: AI only reads what you hand it.',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: AgoraColors.navy,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _isLensMode = true),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AgoraColors.goldContainer,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AgoraColors.goldContainerBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: AgoraColors.goldDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Lens Mode',
                          style: AgoraTypography.labelSmall.copyWith(
                            color: AgoraColors.goldDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (pendingCount > 0) ...[
                  const SizedBox(width: AgoraSpacing.xs),
                  InkWell(
                    onTap: () =>
                        ProposalTraySheet.show(context, widget.spaceId),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AgoraColors.goldContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Proposals ($pendingCount)',
                        style: AgoraTypography.labelSmall.copyWith(
                          color: AgoraColors.goldDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ] else ...[
          // Lens Mode Active Banner
          Container(
            color: AgoraColors.goldContainer,
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.md,
              vertical: AgoraSpacing.sm,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: AgoraColors.goldDark,
                  size: 18,
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Expanded(
                  child: Text(
                    'Lens: ${_selectedMessageIds.length} of 50 selected',
                    style: AgoraTypography.labelMedium.copyWith(
                      color: AgoraColors.goldDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _exitLensMode,
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AgoraColors.gold,
                    foregroundColor: AgoraColors.navyDark,
                    elevation: 0,
                  ),
                  onPressed: _selectedMessageIds.isEmpty
                      ? null
                      : _showHandoffPreview,
                  child: const Text('Preview Handoff'),
                ),
              ],
            ),
          ),
        ],

        // Catch-Up Card (Deterministic, Blue not Gold, Dismissible)
        if (catchUpSummary != null && catchUpSummary.shouldDisplay)
          CatchUpCard(
            spaceId: widget.spaceId,
            summary: catchUpSummary,
            onDismiss: () => setState(() => _catchUpDismissed = true),
          ),

        // Message Feed
        Expanded(
          child: Container(
            color: _isLensMode
                ? AgoraColors.navyDark.withValues(alpha: 0.03)
                : Colors.transparent,
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
                    final isSelected = _selectedMessageIds.contains(msg.id);

                    if (msg.isItemCard) {
                      return _ItemCardBubble(
                        message: msg,
                        onTap: () =>
                            context.go('/spaces/${widget.spaceId}/board'),
                      );
                    }

                    return _ChatMessageBubble(
                      message: msg,
                      isMe: isMe,
                      isLensMode: _isLensMode,
                      isSelected: isSelected,
                      onTap: _isLensMode
                          ? () => _toggleMessageSelection(msg.id)
                          : null,
                      onLongPress: () => _showMessageOptions(msg, isMe),
                      onFootprintTap: () => _showFootprintSheet(context, msg),
                      onToggleWithhold: () {},
                    );
                  },
                );
              },
            ),
          ),
        ),

        // Reply preview strip
        if (_replyToMessage != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.md,
              vertical: AgoraSpacing.xs,
            ),
            color: AgoraColors.surfaceContainer,
            child: Row(
              children: [
                const Icon(
                  Icons.reply,
                  size: 16,
                  color: AgoraColors.navySubtle,
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Expanded(
                  child: Text(
                    'Replying to ${_replyToMessage!.senderDisplayName}: ${_replyToMessage!.text}',
                    style: AgoraTypography.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _replyToMessage = null),
                ),
              ],
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
    required this.isLensMode,
    required this.isSelected,
    this.onTap,
    required this.onLongPress,
    required this.onFootprintTap,
    required this.onToggleWithhold,
  });

  final Message message;
  final bool isMe;
  final bool isLensMode;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback onLongPress;
  final VoidCallback onFootprintTap;
  final VoidCallback onToggleWithhold;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.createdAt);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
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
                  if (message.isEdited) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(edited)',
                      style: AgoraTypography.bodySmall.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 10,
                      ),
                    ),
                  ],
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
                color: isSelected
                    ? AgoraColors.goldContainer.withValues(alpha: 0.35)
                    : (isMe
                          ? AgoraColors.aegeanContainer
                          : AgoraColors.surface),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AgoraRadius.md),
                  topRight: const Radius.circular(AgoraRadius.md),
                  bottomLeft: Radius.circular(isMe ? AgoraRadius.md : 2),
                  bottomRight: Radius.circular(isMe ? 2 : AgoraRadius.md),
                ),
                border: Border(
                  left: isSelected
                      ? const BorderSide(color: AgoraColors.gold, width: 4.0)
                      : BorderSide(
                          color: isMe
                              ? AgoraColors.aegeanContainerBorder
                              : AgoraColors.surfaceBorder,
                          width: 1.0,
                        ),
                  top: BorderSide(
                    color: isMe
                        ? AgoraColors.aegeanContainerBorder
                        : AgoraColors.surfaceBorder,
                    width: 1.0,
                  ),
                  right: BorderSide(
                    color: isMe
                        ? AgoraColors.aegeanContainerBorder
                        : AgoraColors.surfaceBorder,
                    width: 1.0,
                  ),
                  bottom: BorderSide(
                    color: isMe
                        ? AgoraColors.aegeanContainerBorder
                        : AgoraColors.surfaceBorder,
                    width: 1.0,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.isDeleted
                        ? 'This message was deleted'
                        : message.text,
                    style: AgoraTypography.bodyLarge.copyWith(
                      color: message.isDeleted
                          ? AgoraColors.navyDisabled
                          : AgoraColors.navyDark,
                      fontStyle: message.isDeleted ? FontStyle.italic : null,
                    ),
                  ),
                  const SizedBox(height: AgoraSpacing.xs),

                  // Metadata strip
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AgoraConsentBadge(isWithheld: message.aiWithheld),
                      if (message.aiSeenCount > 0) ...[
                        const SizedBox(width: AgoraSpacing.xs),
                        InkWell(
                          onTap: onFootprintTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AgoraColors.goldContainer,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AgoraColors.goldContainerBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  size: 11,
                                  color: AgoraColors.goldDark,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  'AI Seen',
                                  style: AgoraTypography.labelSmall.copyWith(
                                    color: AgoraColors.goldDark,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _ItemCardBubble extends StatelessWidget {
  const _ItemCardBubble({required this.message, required this.onTap});

  final Message message;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final title = message.itemRef?['title'] as String? ?? message.text;
    final type = (message.itemRef?['type'] as String? ?? 'ITEM').toUpperCase();

    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: AgoraSpacing.sm),
        padding: const EdgeInsets.all(AgoraSpacing.md),
        decoration: BoxDecoration(
          color: AgoraColors.surface,
          borderRadius: BorderRadius.circular(AgoraRadius.md),
          border: Border.all(
            color: AgoraColors.aegeanContainerBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AgoraColors.aegeanContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                type,
                style: AgoraTypography.labelSmall.copyWith(
                  color: AgoraColors.aegeanDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: AgoraSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AgoraTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Added to Board with human approval',
                    style: AgoraTypography.bodySmall.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AgoraColors.navySubtle,
              size: 20,
            ),
          ],
        ),
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
