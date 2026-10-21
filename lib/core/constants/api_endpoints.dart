class ApiEndpoints {
  // Auth & Profile
  static const String loginGoogle = '/api/Auth/google';
  static const String refreshToken = '/api/Auth/refresh';
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

  // AI Service endpoints (Port 8000)
  static const String aiSchedulePropose = '/schedule/propose';
  static String aiTaskChat(String taskId) => '/chat/tasks/$taskId';
  static String aiTaskChatMessages(String taskId) => '/chat/tasks/$taskId/messages';
  static String aiTaskChatApply(String taskId) => '/chat/tasks/$taskId/apply';
  static String aiMemorySimilar(String taskId, {int limit = 5}) =>
      '/memory/similar?task_id=$taskId&limit=$limit';
}
