import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/theme/agora_colors.dart';
import '../../../core/theme/agora_radius.dart';
import '../../../core/theme/agora_spacing.dart';
import '../../../core/theme/agora_typography.dart';
import '../../../shared/design_system/agora_button.dart';
import '../../../shared/design_system/agora_states.dart';
import '../../chat/repositories/chat_repository.dart';
import '../screens/private_results_screen.dart';

enum HandoffState { initial, loadingPreview, ready, sending, error }

class HandoffPreviewSheet extends ConsumerStatefulWidget {
  const HandoffPreviewSheet({
    super.key,
    required this.spaceId,
    required this.selectedMessageIds,
    this.onCompleted,
  });

  final String spaceId;
  final List<String> selectedMessageIds;
  final VoidCallback? onCompleted;

  static void show(
    BuildContext context, {
    required String spaceId,
    required List<String> selectedMessageIds,
    VoidCallback? onCompleted,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HandoffPreviewSheet(
        spaceId: spaceId,
        selectedMessageIds: selectedMessageIds,
        onCompleted: onCompleted,
      ),
    );
  }

  @override
  ConsumerState<HandoffPreviewSheet> createState() =>
      _HandoffPreviewSheetState();
}

class _HandoffPreviewSheetState extends ConsumerState<HandoffPreviewSheet> {
  static const _uuid = Uuid();
  HandoffState _state = HandoffState.loadingPreview;
  String? _errorMessage;

  String _selectedPurpose = 'extract';
  final _instructionController = TextEditingController();

  Map<String, dynamic>? _previewData;
  bool _showRawPayload = false;

  @override
  void initState() {
    super.initState();
    _fetchPreview();
  }

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _fetchPreview() async {
    setState(() {
      _state = HandoffState.loadingPreview;
      _errorMessage = null;
    });

    try {
      final functions = ref.read(firebaseFunctionsProvider);
      if (functions != null) {
        final instruction = _instructionController.text.trim();
        final result = await functions.httpsCallable('previewHandoff').call({
          'spaceId': widget.spaceId,
          'messageIds': widget.selectedMessageIds,
          'purpose': _selectedPurpose,
          if (instruction.isNotEmpty) 'customInstruction': instruction,
        });
        if (mounted) {
          setState(() {
            _previewData = Map<String, dynamic>.from(result.data as Map);
            _state = HandoffState.ready;
          });
        }
      } else {
        // Local preview simulation for widget test / offline fallback
        final messages =
            ref.read(spaceMessagesProvider(widget.spaceId)).value ?? [];
        final selectedMsgs = messages
            .where((m) => widget.selectedMessageIds.contains(m.id))
            .toList();

        final items = selectedMsgs.map((m) {
          final isExcluded = m.aiWithheld;
          return {
            'messageId': m.id,
            'status': isExcluded ? 'excluded' : 'included',
            'reason': isExcluded ? 'excluded-withheld' : 'included-consented',
            'authorLabel': 'Member ${m.senderDisplayName}',
          };
        }).toList();

        final includedCount = items
            .where((i) => i['status'] == 'included')
            .length;
        final excludedCount = items.length - includedCount;

        if (mounted) {
          setState(() {
            _previewData = {
              'charterVersion': 1,
              'policy': 'anyone',
              'items': items,
              'counts': {
                'totalRequested': items.length,
                'included': includedCount,
                'excludedWithheld': excludedCount,
                'excludedDeleted': 0,
                'excludedInvalid': 0,
              },
              'payload': items
                  .where((i) => i['status'] == 'included')
                  .map((i) => {'token': 'm1', 'authorLabel': i['authorLabel']})
                  .toList(),
              'payloadHash': 'hash_${items.length}',
            };
            _state = HandoffState.ready;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = HandoffState.error;
          _errorMessage = _mapFriendlyError(e.toString());
        });
      }
    }
  }

  String _mapFriendlyError(String raw) {
    if (raw.contains('policy-off')) {
      return 'AI handoffs are currently disabled by Space policy.';
    }
    if (raw.contains('admins-only')) {
      return 'Only Space admins are permitted to initiate AI handoffs.';
    }
    if (raw.contains('charter-changed') || raw.contains('payload-changed')) {
      return 'The Space charter or message content was updated. Please review the updated preview.';
    }
    if (raw.contains('nothing-to-send')) {
      return 'No eligible messages were available to send (all selected messages are withheld).';
    }
    if (raw.contains('rate-limited')) {
      return 'Too many requests. Please wait a moment before trying again.';
    }
    return 'Unable to prepare handoff preview: $raw';
  }

  Future<void> _handleRunHandoff() async {
    if (_previewData == null) return;
    setState(() => _state = HandoffState.sending);

    try {
      final functions = ref.read(firebaseFunctionsProvider);
      final requestId = _uuid.v4();

      final instruction = _instructionController.text.trim();
      if (functions != null) {
        await functions.httpsCallable('runHandoff').call({
          'spaceId': widget.spaceId,
          'messageIds': widget.selectedMessageIds,
          'purpose': _selectedPurpose,
          if (instruction.isNotEmpty) 'customInstruction': instruction,
          'requestId': requestId,
          'expectedPayloadHash': _previewData!['payloadHash'],
          'expectedCharterVersion': _previewData!['charterVersion'],
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        if (widget.onCompleted != null) {
          widget.onCompleted!();
        }
        final uid = ref.read(currentUserIdProvider) ?? 'me';
        // Open Private Results Screen
        PrivateResultsScreen.show(
          context,
          spaceId: widget.spaceId,
          handoffId: '${uid}_$requestId',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = HandoffState.error;
          _errorMessage = _mapFriendlyError(e.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AgoraColors.surfaceDim,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AgoraRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        top: AgoraSpacing.md,
        left: AgoraSpacing.lg,
        right: AgoraSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AgoraSpacing.xl,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AgoraColors.surfaceBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AgoraSpacing.md),

          // Header with AI Accent
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AgoraColors.goldContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AgoraColors.goldDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: AgoraSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Handoff Preview',
                      style: AgoraTypography.headlineMedium,
                    ),
                    Text(
                      'Purpose: Find tasks, decisions and open questions',
                      style: AgoraTypography.bodySmall.copyWith(
                        color: AgoraColors.navyDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AgoraSpacing.md),

          // Body content based on state
          Expanded(child: _buildBody()),

          const SizedBox(height: AgoraSpacing.md),

          // Action Buttons
          if (_state == HandoffState.ready) ...[
            AgoraButton(
              label:
                  'Send ${_previewData?['counts']?['included'] ?? 0} messages to AI',
              variant: AgoraButtonVariant.gold,
              onPressed: (_previewData?['counts']?['included'] ?? 0) == 0
                  ? null
                  : _handleRunHandoff,
            ),
          ] else if (_state == HandoffState.sending) ...[
            AgoraButton(
              label: 'Stop waiting',
              variant: AgoraButtonVariant.secondary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else if (_state == HandoffState.error) ...[
            AgoraButton(label: 'Retry Preview', onPressed: _fetchPreview),
          ],
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_state == HandoffState.loadingPreview) {
      return const AgoraLoadingIndicator(
        message: 'Verifying consent matrix...',
      );
    }

    if (_state == HandoffState.sending) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AgoraColors.goldDark),
            const SizedBox(height: AgoraSpacing.md),
            Text(
              'Analyzing handed-off messages...',
              style: AgoraTypography.titleMedium,
            ),
            SizedBox(height: AgoraSpacing.xs),
            Text(
              'No standing access · Gemini only reads what was explicitly handed',
              style: AgoraTypography.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_state == HandoffState.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AgoraSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AgoraColors.error,
                size: 40,
              ),
              const SizedBox(height: AgoraSpacing.sm),
              Text(
                'Handoff Blocked',
                style: AgoraTypography.titleMedium.copyWith(
                  color: AgoraColors.error,
                ),
              ),
              const SizedBox(height: AgoraSpacing.xs),
              Text(
                _errorMessage ?? 'An error occurred.',
                style: AgoraTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final counts = _previewData?['counts'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(
      _previewData?['items'] as List? ?? const [],
    );
    final payload = _previewData?['payload'] ?? [];

    return ListView(
      children: [
        // Purpose Selector Strip
        Container(
          padding: const EdgeInsets.all(AgoraSpacing.md),
          decoration: BoxDecoration(
            color: AgoraColors.surface,
            borderRadius: BorderRadius.circular(AgoraRadius.md),
            border: Border.all(color: AgoraColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Handoff Purpose',
                style: AgoraTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AgoraSpacing.xs),
              Wrap(
                spacing: AgoraSpacing.xs,
                children: [
                  ChoiceChip(
                    label: const Text('Tasks & Decisions'),
                    selected: _selectedPurpose == 'extract',
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedPurpose = 'extract');
                        _fetchPreview();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Action Items'),
                    selected: _selectedPurpose == 'actions',
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedPurpose = 'actions');
                        _fetchPreview();
                      }
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Decisions Summary'),
                    selected: _selectedPurpose == 'summarize',
                    onSelected: (val) {
                      if (val) {
                        setState(() => _selectedPurpose = 'summarize');
                        _fetchPreview();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: AgoraSpacing.sm),
              TextField(
                controller: _instructionController,
                maxLength: 200,
                style: AgoraTypography.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Optional Guidance for AI',
                  hintText: 'e.g. Focus on milestone deliverables...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AgoraRadius.sm),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onSubmitted: (_) => _fetchPreview(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AgoraSpacing.md),

        // Consent & Exclusion Summary Box
        Container(
          padding: const EdgeInsets.all(AgoraSpacing.md),
          decoration: BoxDecoration(
            color: AgoraColors.surface,
            borderRadius: BorderRadius.circular(AgoraRadius.md),
            border: Border.all(color: AgoraColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: AgoraColors.navy,
                  ),
                  const SizedBox(width: AgoraSpacing.xs),
                  Text(
                    'Audit Summary',
                    style: AgoraTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AgoraSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _SummaryCount(
                    label: 'Included',
                    count: counts['included'] ?? 0,
                    color: AgoraColors.aegean,
                  ),
                  _SummaryCount(
                    label: 'Withheld',
                    count: counts['excludedWithheld'] ?? 0,
                    color: AgoraColors.withhold,
                  ),
                  _SummaryCount(
                    label: 'Excluded (Other)',
                    count:
                        (counts['excludedDeleted'] ?? 0) +
                        (counts['excludedInvalid'] ?? 0),
                    color: AgoraColors.navyMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AgoraSpacing.md),

        // Per-Message Status List
        Text('Selected Messages', style: AgoraTypography.titleMedium),
        const SizedBox(height: AgoraSpacing.xs),
        ...items.map((item) {
          final isIncluded = item['status'] == 'included';
          final reason = item['reason'] as String? ?? '';
          final label = item['authorLabel'] as String? ?? 'Author';

          return Container(
            margin: const EdgeInsets.only(bottom: AgoraSpacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: AgoraSpacing.md,
              vertical: AgoraSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: AgoraColors.surface,
              borderRadius: BorderRadius.circular(AgoraRadius.sm),
              border: Border.all(
                color: isIncluded
                    ? AgoraColors.surfaceBorder
                    : AgoraColors.withholdBorder,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isIncluded ? Icons.check_circle : Icons.block,
                  color: isIncluded ? AgoraColors.aegean : AgoraColors.withhold,
                  size: 16,
                ),
                const SizedBox(width: AgoraSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: AgoraTypography.bodySmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!isIncluded)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AgoraColors.withholdContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      reason == 'excluded-withheld'
                          ? 'AUTHOR WITHHELD'
                          : 'EXCLUDED',
                      style: AgoraTypography.labelSmall.copyWith(
                        color: AgoraColors.withhold,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  Text(
                    'Included',
                    style: AgoraTypography.labelSmall.copyWith(
                      color: AgoraColors.aegeanDark,
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: AgoraSpacing.md),

        // Transparent Guarantee Notes
        Container(
          padding: const EdgeInsets.all(AgoraSpacing.md),
          decoration: BoxDecoration(
            color: AgoraColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AgoraRadius.md),
            border: Border.all(color: AgoraColors.surfaceBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is NOT sent to AI:',
                style: AgoraTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AgoraColors.navyDark,
                ),
              ),
              const SizedBox(height: AgoraSpacing.xs),
              Text(
                '• Real sender names & handles (replaced by "Member A")\n'
                '• Emails, phone numbers & 9+ digit runs (redacted)\n'
                '• Unselected messages or other Spaces\n'
                '• Messages from authors who withheld consent',
                style: AgoraTypography.bodySmall.copyWith(
                  color: AgoraColors.navySubtle,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AgoraSpacing.sm),

        // Collapsible Exactly What Will Be Sent
        InkWell(
          onTap: () => setState(() => _showRawPayload = !_showRawPayload),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AgoraSpacing.xs),
            child: Row(
              children: [
                Icon(
                  _showRawPayload
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 18,
                  color: AgoraColors.navySubtle,
                ),
                const SizedBox(width: AgoraSpacing.xs),
                Text(
                  'Exactly what will be sent (payload inspection)',
                  style: AgoraTypography.labelSmall.copyWith(
                    color: AgoraColors.navySubtle,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showRawPayload)
          Container(
            padding: const EdgeInsets.all(AgoraSpacing.sm),
            margin: const EdgeInsets.only(top: AgoraSpacing.xs),
            decoration: BoxDecoration(
              color: AgoraColors.navyDark,
              borderRadius: BorderRadius.circular(AgoraRadius.sm),
            ),
            child: Text(
              const JsonEncoder.withIndent('  ').convert(payload),
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: AgoraTypography.headlineLarge.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: AgoraTypography.labelSmall.copyWith(
            color: AgoraColors.navySubtle,
          ),
        ),
      ],
    );
  }
}
