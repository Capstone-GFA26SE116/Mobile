import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/models/project_models.dart';
import '../data/copilot_repository.dart';
import '../models/copilot_models.dart';

class CopilotScreen extends StatefulWidget {
  final String? initialTaskId;
  final String? taskTitle;

  const CopilotScreen({
    super.key,
    this.initialTaskId,
    this.taskTitle,
  });

  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final CopilotRepository _repository = CopilotRepository();
  final ProjectRepository _projectRepo = ProjectRepository();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _selectedTaskId;
  String? _selectedTaskTitle;

  final List<CopilotMessage> _messages = [];
  bool _isTyping = false;
  final Set<String> _appliedDraftIds = {};

  final List<String> _quickPrompts = [
    '⚡ Break down into 3-5 subtasks (≤ 60m)',
    '🧠 Estimate realistic time based on historical Kbias',
    '☕ Add 10m buffer after each focus block',
    '🔄 Optimize sequence by technical dependency',
  ];

  @override
  void initState() {
    super.initState();
    _selectedTaskId = widget.initialTaskId;
    _selectedTaskTitle = widget.taskTitle;
    _initChat();
  }

  void _initChat() {
    _messages.add(
      CopilotMessage(
        id: 'msg_welcome',
        role: 'ai',
        text: _selectedTaskTitle != null
            ? 'Hello! I am synced with "$_selectedTaskTitle". Would you like me to decompose it into subtasks, recalculate durations with your cognitive K_bias factor, or optimize your schedule?'
            : 'Hello! I am Metanoia Copilot — your cognitive scheduling and decomposition assistant. Select a task or chat directly to optimize your focus rhythm.',
        time: 'Now',
        kind: 'text',
      ),
    );
  }

  Future<void> _handleSelectTask() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    List<ProjectModel> projects = [];
    try {
      projects = await _projectRepo.getProjects();
    } catch (_) {}

    if (!mounted) return;
    Navigator.pop(context); // Close loading

    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No projects found to select tasks from.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Task for Cognitive Decomposition',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: projects.length,
                      separatorBuilder: (_, _) => const Divider(color: AppColors.surfaceBorder),
                      itemBuilder: (_, pIndex) {
                        final p = projects[pIndex];
                        return FutureBuilder<List<TaskModel>>(
                          future: _projectRepo.getProjectTasks(p.id),
                          builder: (context, snapshot) {
                            final tasks = snapshot.data ?? [];
                            return ExpansionTile(
                              title: Text(
                                p.name,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              children: tasks.isEmpty
                                  ? [
                                      const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: Text(
                                          'No tasks in this project.',
                                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                                        ),
                                      )
                                    ]
                                  : tasks.map((t) {
                                      return ListTile(
                                        title: Text(
                                          t.title,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                          ),
                                        ),
                                        trailing: const Icon(Icons.arrow_forward_ios,
                                            size: 12, color: AppColors.primary),
                                        onTap: () {
                                          Navigator.pop(ctx);
                                          _onTaskChosen(t.id, t.title);
                                        },
                                      );
                                    }).toList(),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onTaskChosen(String taskId, String title) async {
    setState(() {
      _selectedTaskId = taskId;
      _selectedTaskTitle = title;
    });

    final history = await _repository.getTaskChat(taskId);
    if (!mounted) return;

    if (history.isNotEmpty) {
      setState(() {
        _messages.clear();
        _messages.addAll(history);
      });
    } else {
      setState(() {
        _messages.add(
          CopilotMessage(
            id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
            role: 'ai',
            text: 'Switched to task "$title". Would you like me to decompose it into subtasks or re-estimate durations with Kbias?',
            time: 'Now',
            kind: 'text',
          ),
        );
      });
    }
    _scrollToBottom();
  }

  Future<void> _handleSendMessage([String? customText]) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty) return;

    if (customText == null) {
      _textController.clear();
    }

    final now = DateTime.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final userMsg = CopilotMessage(
      id: 'msg_user_${DateTime.now().millisecondsSinceEpoch}',
      role: 'user',
      text: text,
      time: timeStr,
    );

    setState(() {
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    final taskId = _selectedTaskId ?? 'active-task';
    final aiResponse = await _repository.sendTaskMessage(taskId, text);

    if (!mounted) return;

    setState(() {
      _messages.add(aiResponse);
      _isTyping = false;
    });
    _scrollToBottom();
  }

  Future<void> _handleApplyDraft(CopilotDraft draft) async {
    setState(() {
      _appliedDraftIds.add(draft.messageId);
    });

    final taskId = _selectedTaskId ?? 'active-task';
    final success = await _repository.applyDraft(taskId, draft.messageId, draft.subtasks);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully synced subtasks to task schedule!'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.psychology, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Metanoia Copilot',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.accentGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Neural Engine v2.4 (Gemini 2.5 Flash)',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Select task to break down',
            icon: const Icon(Icons.playlist_add_check, color: AppColors.primary),
            onPressed: _handleSelectTask,
          ),
        ],
      ),
      body: Column(
        children: [
          // ACTIVE TASK BAR IF CHOSEN
          if (_selectedTaskTitle != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.task_alt, color: AppColors.accentGreen, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Task: $_selectedTaskTitle',
                      style: const TextStyle(color: AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: _handleSelectTask,
                    child: const Text('Change', style: TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Quick prompts horizontal scroll
          Container(
            height: 44,
            margin: const EdgeInsets.only(top: 4, bottom: 8),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(
                    prompt,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: AppColors.surface,
                  side: const BorderSide(color: AppColors.surfaceBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  onPressed: _isTyping ? null : () => _handleSendMessage(prompt),
                );
              },
            ),
          ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageItem(msg);
              },
            ),
          ),

          // Typing indicator
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Copilot is reasoning and analyzing...',
                    style: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

          // Input area
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageItem(CopilotMessage msg) {
    if (msg.isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16, left: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Text(
                msg.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              msg.time,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      );
    }

    // AI Message
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppColors.accentGreen,
                  size: 14,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Metanoia AI',
                style: TextStyle(
                  color: AppColors.accentGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                msg.time,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg.text,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (msg.isDraft && msg.draft != null) ...[
                  const SizedBox(height: 12),
                  _buildDraftCard(msg.draft!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(CopilotDraft draft) {
    final isApplied = _appliedDraftIds.contains(draft.messageId);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.checklist_rtl, color: AppColors.primary, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Cognitive Subtasks Proposal',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${draft.subtaskTotalMinutes} mins',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Subtasks list
          ...draft.subtasks.map((sub) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${sub.order}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (sub.reason != null)
                            Text(
                              sub.reason!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${sub.minutes}m',
                      style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),

          if (draft.warning != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      draft.warning!,
                      style: const TextStyle(color: Colors.amber, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isApplied ? null : () => _handleApplyDraft(draft),
              icon: Icon(
                isApplied ? Icons.check : Icons.sync,
                size: 16,
              ),
              label: Text(
                isApplied ? 'Applied to task' : 'Accept & Apply Subtasks',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApplied ? AppColors.surface : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.surfaceBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.surfaceBorder),
                ),
                child: TextField(
                  controller: _textController,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Ask a question or request task breakdown...',
                    hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                  ),
                  onSubmitted: _isTyping ? null : (_) => _handleSendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                onPressed: _isTyping ? null : () => _handleSendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
