import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../projects/data/project_repository.dart';
import '../../projects/models/project_models.dart';
import '../data/copilot_repository.dart';
import '../models/copilot_models.dart';

class CopilotScreen extends StatefulWidget {
  final String? initialProjectId;
  final String? projectTitle;
  // Optional task parameters for backward compatibility
  final String? initialTaskId;
  final String? taskTitle;

  const CopilotScreen({
    super.key,
    this.initialProjectId,
    this.projectTitle,
    this.initialTaskId,
    this.taskTitle,
  });

  @override
  State<CopilotScreen> createState() => _CopilotScreenState();
}

class _CopilotScreenState extends State<CopilotScreen> {
  final CopilotRepository _copilotRepo = CopilotRepository();
  final ProjectRepository _projectRepo = ProjectRepository();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ProjectModel> _projects = [];
  ProjectModel? _selectedProject;
  List<ProjectConversationModel> _conversations = [];
  ProjectConversationModel? _activeConversation;

  final List<ProjectChatMessage> _messages = [];
  bool _isLoadingProjects = true;
  bool _isLoadingChat = false;
  bool _isTyping = false;
  final Set<String> _appliedDraftIds = {};

  // Adaptive language state: dynamically follows user's input/prompts
  bool _isVietnameseMode = false;

  bool _detectVietnamese(String text) {
    if (text.isEmpty) return false;
    final viRegex = RegExp(
      r'[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđÀÁẠẢÃÂẦẤẬẨẪĂẰẮẶẲẴÈÉẸẺẼÊỀẾỆỂỄÌÍỊỈĨÒÓỌỎÕÔỒỐỘỔỖƠỜỚỢỞỠÙÚỤỦŨƯỪỨỰỬỮỲÝỴỶỸĐ]',
      caseSensitive: false,
    );
    if (viRegex.hasMatch(text)) return true;

    final viKeywords = [
      'kế hoạch', 'phân rã', 'dự án', 'công việc', 'thời gian',
      'giúp', 'cho', 'tôi', 'bạn', 'hãy', 'làm', 'và', 'của',
      'trong', 'mục tiêu', 'tính năng', 'thêm', 'sửa', 'xóa', 'ứng dụng',
      'mình', 'nhé', 'xem qua', 'todolist', 'lập trình'
    ];
    final lower = text.toLowerCase();
    for (final w in viKeywords) {
      if (lower.contains(w)) return true;
    }
    return false;
  }

  List<String> get _quickPrompts => _isVietnameseMode
      ? [
          '📋 Phân tích project brief & đề xuất milestones',
          '⏱️ Ước tính thời gian & hiệu chỉnh Kbias theo domain',
          '⚠️ Kiểm tra rủi ro tiến độ & cảnh báo quá tải',
          '🎯 Đề xuất danh sách tasks ưu tiên cho Phase 1',
        ]
      : [
          '📋 Analyze project brief & suggest milestones',
          '⏱️ Estimate workload & calibrate Kbias by domain',
          '⚠️ Check schedule risks & overload warnings',
          '🎯 Propose prioritized tasks for Phase 1',
        ];

  @override
  void initState() {
    super.initState();
    _loadProjectsAndInitChat();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectsAndInitChat() async {
    setState(() => _isLoadingProjects = true);
    try {
      final projects = await _projectRepo.getProjects();
      if (!mounted) return;

      setState(() {
        _projects = projects;
        if (projects.isNotEmpty) {
          if (widget.initialProjectId != null) {
            _selectedProject = projects.firstWhere(
              (p) => p.id == widget.initialProjectId,
              orElse: () => projects.first,
            );
          } else {
            _selectedProject = projects.first;
          }
        }
        _isLoadingProjects = false;
      });

      if (_selectedProject != null) {
        await _loadConversationsForProject(_selectedProject!.id);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingProjects = false);
    }
  }

  /// GET /chat/projects/{project_id}/conversations
  Future<void> _loadConversationsForProject(String projectId) async {
    setState(() => _isLoadingChat = true);
    try {
      final convList = await _copilotRepo.listProjectChats(projectId);
      if (!mounted) return;

      setState(() {
        _conversations = convList;
      });

      if (convList.isNotEmpty) {
        final newest = convList.first;
        await _selectConversation(newest);
      } else {
        await _handleStartNewChat(silent: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingChat = false);
    }
  }

  /// POST /chat/projects/{project_id}/conversations
  Future<void> _handleStartNewChat({bool silent = false}) async {
    if (_selectedProject == null) return;

    if (!silent) {
      setState(() => _isLoadingChat = true);
    }

    final newConv = await _copilotRepo.startProjectChat(_selectedProject!.id);
    if (!mounted) return;

    if (newConv != null) {
      setState(() {
        _conversations.insert(0, newConv);
        _activeConversation = newConv;
        _messages.clear();
        _messages.add(
          ProjectChatMessage(
            id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            kind: 'question',
            content: _isVietnameseMode
                ? 'Xin chào! Tôi là AI Copilot cho dự án "${_selectedProject!.name}". Hãy gửi cho tôi bản mô tả (project brief), yêu cầu tính năng hoặc các mục tiêu dự án để tôi phân tích và đề xuất milestones & tasks tối ưu.'
                : 'Hello! I am your AI Copilot for "${_selectedProject!.name}". Share your project brief, scope requirements, or goals in English or Vietnamese, and I will propose an optimal breakdown of milestones and tasks.',
            createdAt: DateTime.now(),
          ),
        );
        _isLoadingChat = false;
      });
      _scrollToBottom();
    } else {
      setState(() => _isLoadingChat = false);
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isVietnameseMode
                  ? 'Không thể tạo phiên chat mới. Vui lòng thử lại.'
                  : 'Could not create a new chat session. Please try again.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// GET /chat/conversations/{conversation_id}
  Future<void> _selectConversation(ProjectConversationModel conv) async {
    setState(() {
      _activeConversation = conv;
      _isLoadingChat = true;
    });

    final detail = await _copilotRepo.getProjectChat(conv.conversationId);
    if (!mounted) return;

    // Detect language from history if available
    bool detectedVi = _isVietnameseMode;
    if (detail != null && detail.messages.isNotEmpty) {
      for (final m in detail.messages) {
        if (_detectVietnamese(m.content)) {
          detectedVi = true;
          break;
        }
      }
    }

    setState(() {
      _isVietnameseMode = detectedVi;
      _messages.clear();
      if (detail != null && detail.messages.isNotEmpty) {
        _messages.addAll(detail.messages);
      } else {
        _messages.add(
          ProjectChatMessage(
            id: 'welcome_${DateTime.now().millisecondsSinceEpoch}',
            role: 'assistant',
            kind: 'question',
            content: _isVietnameseMode
                ? 'Phiên thảo luận "${conv.title}" đã sẵn sàng cho "${_selectedProject?.name ?? ''}". Hãy gửi thông tin dự án để tôi hỗ trợ lên kế hoạch!'
                : 'Discussion session "${conv.title}" is ready for "${_selectedProject?.name ?? ''}". Send project details to begin planning!',
            createdAt: DateTime.now(),
          ),
        );
      }
      _isLoadingChat = false;
    });

    _scrollToBottom();
  }

  /// POST /chat/conversations/{conversation_id}/messages
  Future<void> _handleSendMessage([String? customText]) async {
    final text = customText ?? _textController.text.trim();
    if (text.isEmpty || _activeConversation == null) return;

    if (customText == null) {
      _textController.clear();
    }

    // Adapt language immediately based on user prompt
    final isVi = _detectVietnamese(text);
    final now = DateTime.now();
    final userMsg = ProjectChatMessage(
      id: 'usr_${now.millisecondsSinceEpoch}',
      role: 'user',
      content: text,
      createdAt: now,
    );

    setState(() {
      _isVietnameseMode = isVi;
      _messages.add(userMsg);
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final turn = await _copilotRepo.sendProjectChatMessage(
        _activeConversation!.conversationId,
        text,
      );

      if (!mounted) return;

      setState(() {
        if (turn != null) {
          _messages.add(turn.aiMessage);
          // If AI answered in Vietnamese or English, refine detection
          if (_detectVietnamese(turn.aiMessage.content)) {
            _isVietnameseMode = true;
          }
        } else {
          _messages.add(
            ProjectChatMessage(
              id: 'err_${DateTime.now().millisecondsSinceEpoch}',
              role: 'assistant',
              kind: 'question',
              content: _isVietnameseMode
                  ? 'Hệ thống AI đang phản hồi chậm. Vui lòng thử lại trong giây lát.'
                  : 'The AI service is taking longer than expected. Please try again shortly.',
              createdAt: DateTime.now(),
            ),
          );
        }
        _isTyping = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isTyping = false);
    }
  }

  /// POST /chat/conversations/{conversation_id}/apply
  Future<void> _handleApplyDraft(ProjectDraft draft) async {
    if (_activeConversation == null) return;

    setState(() {
      _appliedDraftIds.add(draft.messageId);
    });

    final success = await _copilotRepo.applyProjectDraft(
      _activeConversation!.conversationId,
      draft.messageId,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVietnameseMode
                ? 'Đã áp dụng các Milestones & Tasks vào dự án thành công!'
                : 'Successfully applied milestones and tasks to your project!',
          ),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isVietnameseMode
                ? 'Không thể áp dụng bản thiết kế vào dự án.'
                : 'Unable to apply blueprint to project.',
          ),
          backgroundColor: Colors.redAccent,
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

  void _showProjectPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isVietnameseMode
                        ? 'Chọn dự án để trò chuyện với AI'
                        : 'Select Project for Copilot',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _projects.length,
                  separatorBuilder: (_, _) => const Divider(color: AppColors.surfaceBorder, height: 1),
                  itemBuilder: (_, index) {
                    final p = _projects[index];
                    final isSelected = _selectedProject?.id == p.id;
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surfaceBorder.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.folder_outlined,
                          color: isSelected ? AppColors.primary : AppColors.textMuted,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        p.name,
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        _isVietnameseMode
                            ? 'Hạn chót: ${p.deadline ?? 'Chưa đặt'}'
                            : 'Due: ${p.deadline ?? 'Not set'}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        if (_selectedProject?.id != p.id) {
                          setState(() {
                            _selectedProject = p;
                          });
                          _loadConversationsForProject(p.id);
                        }
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
  }

  void _showConversationsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isVietnameseMode ? 'Lịch sử trò chuyện' : 'Chat History',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _selectedProject?.name ?? (_isVietnameseMode ? 'Dự án' : 'Project'),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _handleStartNewChat();
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: Text(
                      _isVietnameseMode ? 'Chat mới' : 'New Chat',
                      style: const TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: _conversations.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _isVietnameseMode
                                ? 'Chưa có cuộc trò chuyện nào trong dự án này.'
                                : 'No conversation history for this project yet.',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _conversations.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: AppColors.surfaceBorder,
                          height: 1,
                        ),
                        itemBuilder: (_, index) {
                          final c = _conversations[index];
                          final isActive = _activeConversation?.conversationId == c.conversationId;
                          final dateStr =
                              '${c.createdAt.day.toString().padLeft(2, '0')}/${c.createdAt.month.toString().padLeft(2, '0')} ${c.createdAt.hour.toString().padLeft(2, '0')}:${c.createdAt.minute.toString().padLeft(2, '0')}';

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : AppColors.surfaceBorder.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                color: isActive ? AppColors.primary : AppColors.textMuted,
                                size: 18,
                              ),
                            ),
                            title: Text(
                              c.title.isNotEmpty ? c.title : 'Project Planning',
                              style: TextStyle(
                                color: isActive ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              dateStr,
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            trailing: c.status == 'applied'
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentGreen.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Applied',
                                      style: TextStyle(color: AppColors.accentGreen, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                : (isActive
                                    ? const Icon(Icons.check, color: AppColors.primary, size: 18)
                                    : null),
                            onTap: () {
                              Navigator.pop(ctx);
                              if (!isActive) {
                                _selectConversation(c);
                              }
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
                  'Project Copilot',
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
                  'Metanoia AI Engine • Project Breakdown',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: _isVietnameseMode ? 'Lịch sử cuộc trò chuyện' : 'Chat History',
            icon: const Icon(Icons.forum_outlined, color: AppColors.primary),
            onPressed: _conversations.isNotEmpty || _selectedProject != null
                ? _showConversationsList
                : null,
          ),
          IconButton(
            tooltip: _isVietnameseMode ? 'Tạo phiên chat mới' : 'Start New Chat',
            icon: const Icon(Icons.add_comment_outlined, color: AppColors.textSecondary),
            onPressed: () => _handleStartNewChat(),
          ),
        ],
      ),
      body: _isLoadingProjects
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : Column(
              children: [
                // PROJECT SELECTOR BANNER
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedProject != null
                                  ? _selectedProject!.name
                                  : (_isVietnameseMode ? 'Chưa chọn dự án' : 'No project selected'),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_activeConversation != null)
                              Text(
                                _activeConversation!.title.isNotEmpty
                                    ? _activeConversation!.title
                                    : (_isVietnameseMode ? 'Phiên thảo luận hiện tại' : 'Current discussion session'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _showProjectPicker,
                        icon: const Icon(Icons.swap_horiz, size: 14, color: AppColors.primary),
                        label: Text(
                          _isVietnameseMode ? 'Đổi dự án' : 'Switch',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ),

                // QUICK PROMPTS
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(top: 2, bottom: 6),
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
                            fontSize: 11,
                          ),
                        ),
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.surfaceBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onPressed: (_isTyping || _isLoadingChat)
                            ? null
                            : () => _handleSendMessage(prompt),
                      );
                    },
                  ),
                ),

                // CHAT STREAM OR LOADING
                Expanded(
                  child: _isLoadingChat
                      ? const Center(
                          child: CircularProgressIndicator(color: AppColors.primary),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return _buildMessageItem(msg);
                          },
                        ),
                ),

                // TYPING INDICATOR
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
                          _isVietnameseMode
                              ? 'AI Copilot đang phân tích brief và hoạch định...'
                              : 'AI Copilot is analyzing brief and planning...',
                          style: TextStyle(
                            color: AppColors.textSecondary.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // INPUT BAR
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildMessageItem(ProjectChatMessage msg) {
    final timeStr =
        '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}';

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
                msg.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
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
                timeStr,
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
                  msg.content,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (msg.hasDraft && msg.draft != null) ...[
                  const SizedBox(height: 14),
                  _buildProjectDraftCard(msg.draft!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectDraftCard(ProjectDraft draft) {
    final isApplied = _appliedDraftIds.contains(draft.messageId);

    // Determine language of the draft card:
    // Follows overall language mode, or detects language directly inside draft content!
    final bool isViCard = _isVietnameseMode ||
        (draft.milestones.isNotEmpty && _detectVietnamese(draft.milestones.first.title)) ||
        (draft.warnings.isNotEmpty && _detectVietnamese(draft.warnings.first));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HEADER - Adaptive language + flex protected
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.architecture, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isViCard
                      ? 'Đề Xuất Phân Rã Dự Án (Blueprint)'
                      : 'Project Breakdown Blueprint',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  isViCard
                      ? '${draft.milestones.length} Giai đoạn'
                      : '${draft.milestones.length} ${draft.milestones.length == 1 ? 'Milestone' : 'Milestones'}',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // MILESTONES & TASKS LIST
          ...draft.milestones.map((m) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.surfaceBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          m.title,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (m.deadline.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBorder,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isViCard ? 'Hạn: ${m.deadline}' : 'Due: ${m.deadline}',
                            style: const TextStyle(
                              color: AppColors.accentGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Tasks under this milestone
                  ...m.tasks.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (t.reason != null && t.reason!.isNotEmpty)
                                    Text(
                                      t.reason!,
                                      style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t.domain.name,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${t.estimatedMinutes}m',
                              style: const TextStyle(
                                color: AppColors.accentGreen,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            );
          }),

          // NUMBERS SUMMARY - Adaptive language + flex protected
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isViCard ? 'Khối lượng:' : 'Workload:',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isViCard
                            ? '${(draft.numbers.totalEstimatedMinutes / 60).toStringAsFixed(1)}h (Gốc) → ${(draft.numbers.totalAdjustedMinutes / 60).toStringAsFixed(1)}h (Kbias)'
                            : '${(draft.numbers.totalEstimatedMinutes / 60).toStringAsFixed(1)}h (Base) → ${(draft.numbers.totalAdjustedMinutes / 60).toStringAsFixed(1)}h (Kbias)',
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                          color: AppColors.accentGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (draft.numbers.daysLeft != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        isViCard ? 'Thời gian còn lại:' : 'Remaining Time:',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isViCard
                              ? '${draft.numbers.daysLeft} ngày trước deadline'
                              : '${draft.numbers.daysLeft} days until deadline',
                          textAlign: TextAlign.end,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // REMINDERS & WARNINGS
          if (draft.warnings.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...draft.warnings.map(
              (w) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        w,
                        style: const TextStyle(color: Colors.amber, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // APPLY BUTTON - Adaptive language
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isApplied ? null : () => _handleApplyDraft(draft),
              icon: Icon(
                isApplied ? Icons.check_circle : Icons.published_with_changes,
                size: 16,
              ),
              label: Text(
                isApplied
                    ? (isViCard ? 'Đã áp dụng vào dự án' : 'Applied to Project')
                    : (isViCard ? 'Áp Dụng Bản Kế Hoạch Vào Dự Án' : 'Apply Blueprint to Project'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isApplied ? AppColors.surface : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                  decoration: InputDecoration(
                    hintText: _isVietnameseMode
                        ? 'Nhập brief dự án hoặc câu hỏi cho Copilot...'
                        : 'Enter project brief or message for Copilot...',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_isTyping || _isLoadingChat)
                      ? null
                      : (_) => _handleSendMessage(),
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
                onPressed: (_isTyping || _isLoadingChat)
                    ? null
                    : () => _handleSendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
