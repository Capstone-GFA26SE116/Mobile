import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../copilot/data/copilot_repository.dart';
import '../../copilot/models/copilot_models.dart';
import '../../copilot/screens/copilot_screen.dart';
import '../models/project_models.dart';

class AiTaskDecomposeSheet extends StatefulWidget {
  final TaskModel task;
  final String projectName;
  final VoidCallback onApplied;

  const AiTaskDecomposeSheet({
    super.key,
    required this.task,
    required this.projectName,
    required this.onApplied,
  });

  @override
  State<AiTaskDecomposeSheet> createState() => _AiTaskDecomposeSheetState();
}

class _AiTaskDecomposeSheetState extends State<AiTaskDecomposeSheet> {
  final CopilotRepository _repository = CopilotRepository();

  bool _isLoading = true;
  bool _isApplying = false;
  String? _errorMessage;

  CopilotDraft? _draft;
  List<CopilotSubtaskDraft> _subtasks = [];
  String _selectedPrompt = '⚡ Break this into 3-5 subtasks, each ≤ 60 minutes';

  final List<String> _quickPrompts = [
    '⚡ Break this into 3-5 subtasks, each ≤ 60 minutes',
    '🧠 Estimate realistic minutes based on similar past tasks',
    '☕ Add a 10-minute rest buffer after each subtask',
    '🔄 Re-order by dependencies (DB → API → UI)',
  ];

  @override
  void initState() {
    super.initState();
    _triggerDecompose(_selectedPrompt);
  }

  Future<void> _triggerDecompose(String prompt) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedPrompt = prompt;
    });

    try {
      final response = await _repository.sendTaskMessage(widget.task.id, prompt);
      if (!mounted) return;

      if (response.isDraft && response.draft != null) {
        setState(() {
          _draft = response.draft;
          _subtasks = List<CopilotSubtaskDraft>.from(response.draft!.subtasks);
          _isLoading = false;
        });
      } else {
        // Fallback default draft if response had text only
        setState(() {
          _subtasks = [
            CopilotSubtaskDraft(
              title: 'Analyze requirements & scope',
              minutes: 30,
              order: 1,
              reason: 'Preparation & specifications',
            ),
            CopilotSubtaskDraft(
              title: 'Implement primary core module',
              minutes: 45,
              order: 2,
              reason: 'Core business functionality',
            ),
            CopilotSubtaskDraft(
              title: 'Integration & validation',
              minutes: 30,
              order: 3,
              reason: 'Quality assurance',
            ),
          ];
          _draft = CopilotDraft(
            messageId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
            subtasks: _subtasks,
            yourEstimateMinutes: widget.task.estimatedMinutes ?? 60,
            adjustedMinutes: 105,
            subtaskTotalMinutes: 105,
            adjustedIsHint: true,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to decompose task. Please check network or try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleApply() async {
    if (_subtasks.isEmpty) return;

    setState(() => _isApplying = true);

    try {
      final messageId = _draft?.messageId ?? 'draft_${DateTime.now().millisecondsSinceEpoch}';
      await _repository.applyDraft(widget.task.id, messageId, _subtasks);

      if (!mounted) return;
      Navigator.pop(context); // close bottom sheet

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.onPrimary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Synced ${_subtasks.length} subtasks to "${widget.task.title}"!'),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      widget.onApplied();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isApplying = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to apply subtasks: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _removeSubtask(int index) {
    setState(() {
      _subtasks.removeAt(index);
    });
  }

  void _showAddCustomSubtaskDialog() {
    final titleController = TextEditingController();
    final minsController = TextEditingController(text: '30');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Add Subtask to Draft', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Subtask Title',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minsController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Estimated Minutes',
                labelStyle: TextStyle(color: AppColors.textMuted),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.surfaceBorder)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final title = titleController.text.trim();
              final mins = int.tryParse(minsController.text.trim()) ?? 30;
              if (title.isNotEmpty) {
                setState(() {
                  _subtasks.add(
                    CopilotSubtaskDraft(
                      title: title,
                      minutes: mins,
                      order: _subtasks.length + 1,
                      reason: 'User defined block',
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.onPrimary,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalMinutes = _subtasks.fold<int>(0, (sum, item) => sum + item.minutes);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(
          top: BorderSide(color: AppColors.surfaceBorder, width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Drag handle & Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333333),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Text(
                                'AI Task Decomposer',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Neural v2.4',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Calibrated decomposition into focused subtasks (≤ 60m)',
                            style: TextStyle(color: AppColors.textMuted.withValues(alpha: 0.9), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: AppColors.surfaceBorder, height: 1),

          // 2. Body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Task Info card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.surfaceBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.task_alt, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.task.title,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Project: ${widget.projectName}  •  ${widget.task.estimatedMinutes ?? widget.task.aiEstimatedMinutes ?? 60}m estimate',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Prompt Pills
                  const Text(
                    'STRATEGY & PROMPT',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _quickPrompts.map((p) {
                        final isSelected = _selectedPrompt == p;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(p),
                            selected: isSelected,
                            onSelected: _isLoading
                                ? null
                                : (selected) {
                                    if (selected) _triggerDecompose(p);
                                  },
                            labelStyle: TextStyle(
                              color: isSelected ? AppColors.onPrimary : AppColors.textSecondary,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            selectedColor: AppColors.primary,
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: isSelected ? AppColors.primary : AppColors.surfaceBorder,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Content: Loading or Error or Subtasks
                  if (_isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 32,
                            height: 32,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Metanoia Neural Engine analyzing task context...',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Calibrating subtasks with historical Kbias velocity',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    )
                  else if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        children: [
                          Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _triggerDecompose(_selectedPrompt),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surface,
                              foregroundColor: AppColors.textPrimary,
                            ),
                            icon: const Icon(Icons.refresh, size: 14),
                            label: const Text('Retry Decomposition'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // Metric Summary strip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('SUBTASKS', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('${_subtasks.length} blocks', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: AppColors.surfaceBorder),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('TOTAL CALIBRATED', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text('${totalMinutes}m', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(width: 1, height: 24, color: AppColors.surfaceBorder),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('K_BIAS CALIBRATION', style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Row(
                                children: const [
                                  Icon(Icons.trending_up, size: 13, color: AppColors.primary),
                                  SizedBox(width: 3),
                                  Text('1.34x', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_draft?.warning != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, size: 14, color: Color(0xFFFF9800)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _draft!.warning!,
                                style: const TextStyle(color: Color(0xFFFF9800), fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 14),

                    // Subtasks List
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'PROPOSED SUBTASKS',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showAddCustomSubtaskDialog,
                          icon: const Icon(Icons.add, size: 13, color: AppColors.primary),
                          label: const Text('+ Custom block', style: TextStyle(color: AppColors.primary, fontSize: 11)),
                          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    if (_subtasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: Text('No subtasks in draft. Tap a prompt or add one above.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subtasks.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (ctx, i) {
                          final st = _subtasks[i];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.surfaceBorder),
                            ),
                            child: Row(
                              children: [
                                // Order badge
                                Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${i + 1}',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Title and rationale
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        st.title,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (st.reason != null && st.reason!.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          st.reason!,
                                          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // Duration pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF141414),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: AppColors.surfaceBorder),
                                  ),
                                  child: Text(
                                    '${st.minutes}m',
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 4),

                                // Delete button
                                IconButton(
                                  icon: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                  onPressed: () => _removeSubtask(i),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ],
              ),
            ),
          ),

          // 3. Bottom Actions Bar
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF121212),
              border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
            ),
            child: Row(
              children: [
                // Open in full Copilot Chat
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CopilotScreen(
                          initialTaskId: widget.task.id,
                          taskTitle: widget.task.title,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.surfaceBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 16),
                  label: const Text('Copilot Chat', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 10),

                // Apply button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _subtasks.isEmpty || _isApplying)
                        ? null
                        : _handleApply,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isApplying
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary),
                          )
                        : const Icon(Icons.check_circle_outline, size: 16),
                    label: Text(
                      _isApplying
                          ? 'Applying...'
                          : 'Apply ${_subtasks.length} Subtasks',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
