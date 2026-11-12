class ApiEndpoints {
  // Auth & Profile
  static const String loginGoogle = '/api/Auth/google';
  static const String refreshToken = '/api/Auth/refresh';
  static const String logout = '/api/Auth/logout';
  static const String me = '/api/me';
  static const String meProfile = '/api/me/profile';
  static const String meSettings = '/api/me/settings';
  static const String onboarding = '/api/me/onboarding';
  static const String domains = '/api/domains';

  // Projects
  static const String projects = '/api/projects';
  static const String projectsFilter = '/api/projects/filter';
  static String projectDetail(String id) => '/api/projects/$id';
  static String projectArchive(String id) => '/api/projects/$id/archive';
  static String projectRestore(String id) => '/api/projects/$id/restore';
  static String projectProgress(String id) => '/api/projects/$id/progress';

  // Tasks & SubTasks
  static String projectTasks(String projectId) => '/api/projects/$projectId/tasks';
  static String taskDetail(String taskId) => '/api/tasks/$taskId';
  static String taskSubtasks(String taskId) => '/api/tasks/$taskId/subtasks';
  static String subtaskDetail(String subTaskId) => '/api/subtasks/$subTaskId';

  // Milestones
  static String projectMilestones(String projectId) => '/api/projects/$projectId/milestones';
  static String milestoneDetail(String milestoneId) => '/api/milestones/$milestoneId';

  // Clients
  static const String clients = '/api/clients';
  static const String clientsFilter = '/api/clients/filter';
  static String clientDetail(String clientId) => '/api/clients/$clientId';

  // Schedule & Calendar
  static const String calendar = '/api/calendar';
  static const String proposeSchedule = '/api/schedule/propose';
  static const String pendingProposal = '/api/schedule/proposals/pending';
  static String approveProposal(String id) => '/api/schedule/proposals/$id/approve';
  static String taskScheduleSlots(String taskId) => '/api/tasks/$taskId/schedule-slots';
  static String scheduleSlotDetail(String slotId) => '/api/schedule-slots/$slotId';

  // Google Calendar Integration
  static const String googleCalendarStatus = '/api/google-calendar/status';
  static const String googleCalendarConnect = '/api/google-calendar/connect';
  static const String googleCalendarDisconnect = '/api/google-calendar/disconnect';
  static const String googleCalendarSync = '/api/google-calendar/sync';
  static const String googleCalendarEvents = '/api/google-calendar/events';

  // Payments & Subscription Plans
  static const String subscriptionPlans = '/api/subscription-plans';
  static const String userSubscriptions = '/api/user-subscriptions';
  static const String paymentsCheckout = '/api/payments/checkout';
  static String paymentSync(String paymentId) => '/api/payments/$paymentId/sync';

  // Focus Session (Timer & Real Time Tracking)
  static const String focusStart = '/api/focus/start';
  static String focusStop(String sessionId) => '/api/focus/$sessionId/stop';
  static const String focusCurrent = '/api/focus/current';
  static const String focusPendingConfirmation = '/api/focus/pending-confirmation';
  static String focusConfirm(String sessionId) => '/api/focus/$sessionId/confirm';
  static const String focusSelfReport = '/api/focus/self-report';
  static String focusTimeSummary(String slotId) => '/api/focus/$slotId/time-summary';
  static const String focusTracks = '/api/focus-tracks';

  // Notifications
  static const String notifications = '/api/notifications';
  static String notificationRead(String id) => '/api/notifications/$id/read';
  static const String notificationReadAll = '/api/notifications/read-all';
  static const String notificationVapidPublicKey = '/api/notifications/vapid-public-key';
  static const String notificationSubscribe = '/api/notifications/subscribe';
  static const String notificationUnsubscribe = '/api/notifications/unsubscribe';
  static const String notificationHub = '/hubs/notifications';

  // AI Service endpoints (Port 8000)
  static const String aiSchedulePropose = '/schedule/propose';
  static const String aiScheduleOverrun = '/schedule/overrun'; // FR-16b
  static const String aiBriefingToday = '/briefing/today';
  static const String aiAnalyticsOverview = '/analytics/overview';
  static const String aiAssistantTurn = '/assistant/turn';
  static String aiTaskChat(String taskId) => '/chat/tasks/$taskId';
  static String aiTaskChatMessages(String taskId) => '/chat/tasks/$taskId/messages';
  static String aiTaskChatApply(String taskId) => '/chat/tasks/$taskId/apply';
  static String aiProjectConversations(String projectId) =>
      '/chat/projects/$projectId/conversations';
  static String aiConversationMessages(String conversationId) =>
      '/chat/conversations/$conversationId/messages';
  static String aiConversationDetail(String conversationId) =>
      '/chat/conversations/$conversationId';
  static String aiConversationApply(String conversationId) =>
      '/chat/conversations/$conversationId/apply';
  static String aiMemorySimilar(String taskId, {int limit = 5}) =>
      '/memory/similar?task_id=$taskId&limit=$limit';
}
