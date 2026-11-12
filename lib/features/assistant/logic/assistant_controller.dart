import 'package:flutter/foundation.dart';

import '../../schedule/models/overrun_models.dart';
import '../data/assistant_repository.dart';
import '../data/command_repository.dart';
import '../models/assistant_turn.dart';
import '../widgets/avatar_view.dart';
import 'assistant_turn.dart';
import 'intent_router.dart';

enum AssistantPhase { idle, listening, thinking, speaking }

/// One screen session with the assistant (agent plan section 2): sends each sentence to
/// `/assistant/turn`, keeps the recent history, and holds the options / suggestions to show.
/// The screen owns the mic and the avatar; it reports to [startListening] / [updateHeard] /
/// [ask] / [speakingChanged] and draws from the fields here.
class AssistantController extends ChangeNotifier {
  // FR-22 request limits (decision #10, `text` 1–500).
  static const int historyMaxEntries = 6;
  static const int historyMaxChars = 2000;
  static const int textMaxChars = 500;

  /// Errors after which a "what should I do today" sentence still works through the MVP
  /// keyword path (agent plan AC4). Not 401: the briefing call would fail the same way.
  static const Set<AssistantErrorKind> fallbackKinds = {
    AssistantErrorKind.quotaExceeded,
    AssistantErrorKind.noPlan,
    AssistantErrorKind.network,
    AssistantErrorKind.server,
  };

  /// FR-22c: tapping one of these is the same as saying it.
  static const String yes = 'Có';
  static const String no = 'Không';
  static const String cancelled = 'Ok, mình không làm nữa.';

  final AssistantRepository _repository;
  final AssistantTurn _fallback;
  final CommandRepository? _commandsOverride;
  // Built on first use: needs the Backend config, which tests without commands never load.
  late final CommandRepository _commands =
      _commandsOverride ?? CommandRepository.create();

  /// Reads [text] aloud; returns false when the device has no Vietnamese voice.
  final Future<bool> Function(String text) _speak;

  AssistantController({
    required AssistantRepository repository,
    required this._speak,
    CommandRepository? commands,
  }) : _repository = repository,
       _commandsOverride = commands,
       _fallback = AssistantTurn(fetchBriefing: repository.getTodayBriefing);

  AssistantPhase _phase = AssistantPhase.idle;
  String _heard = '';
  String? _reply;
  bool _noVoice = false;
  AvatarEmotion _emotion = AvatarEmotion.neutral;
  List<TurnOption> _options = const [];
  List<String> _suggestions = const [];
  List<TurnHistoryEntry> _history = const [];
  // The question a `clarify` turn asked about, with the history it was sent with.
  ({String text, List<TurnHistoryEntry> history})? _clarifying;
  // Bumped on every new question, so an answer that arrives after a newer one is dropped.
  int _generation = 0;
  // FR-22c: the command waiting for "Có" / "Không" (kept while the mic is open).
  ({TurnAction action, OverrunPlan? plan})? _pending;

  AssistantPhase get phase => _phase;
  String get heard => _heard;
  String? get reply => _reply;

  /// The last [reply] could not be spoken; the screen shows it as text only.
  bool get noVoice => _noVoice;
  AvatarEmotion get emotion => _emotion;
  List<TurnOption> get options => _options;
  List<String> get suggestions => _suggestions;
  List<TurnHistoryEntry> get history => List.unmodifiable(_history);

  /// A command waits for the user's yes / no.
  bool get confirming => _pending != null;

  /// Mic pressed: drops the current answer, options and any pending clarify.
  void startListening() {
    _generation++;
    _clear();
    _phase = AssistantPhase.listening;
    notifyListeners();
  }

  void updateHeard(String words) {
    if (_phase != AssistantPhase.listening) return;
    _heard = words;
    notifyListeners();
  }

  /// A spoken sentence, a tapped suggestion, or the debug DEV_UTTERANCE.
  Future<void> ask(String sentence) async {
    final pending = _pending;
    if (pending != null) {
      _pending = null; // answered now, or dropped by a new question
      final answer = confirmation(sentence);
      if (answer != null) {
        final generation = ++_generation;
        _clear();
        _heard = sentence;
        if (!answer) return _say(cancelled, AvatarEmotion.neutral);
        return _run(pending.action, pending.plan, generation);
      }
    }
    final generation = ++_generation;
    _clear();
    _heard = sentence;
    final text = sentence.trim();
    if (text.isEmpty) {
      await _say(AssistantTurn.notHeard, AvatarEmotion.neutral);
      return;
    }
    final clipped = text.length > textMaxChars
        ? text.substring(0, textMaxChars)
        : text;
    await _send(clipped, _history, generation: generation);
  }

  /// A tapped option of the last `clarify` turn: re-sends that question with the option's id.
  Future<void> choose(TurnOption option) async {
    final clarifying = _clarifying;
    if (clarifying == null || !_options.contains(option)) return;
    final generation = ++_generation;
    _clear();
    _heard = option.title;
    await _send(
      clarifying.text,
      clarifying.history,
      selectedId: option.id,
      generation: generation,
    );
  }

  /// Shows and speaks a sentence that did not come from the AI service (e.g. a mic error).
  Future<void> say(String text, AvatarEmotion emotion) async {
    _generation++;
    _clear();
    await _say(text, emotion);
  }

  /// From the voice engine: the avatar finished (or was stopped).
  void speakingChanged(bool speaking) {
    if (speaking || _phase != AssistantPhase.speaking) return;
    _phase = AssistantPhase.idle;
    notifyListeners();
  }

  Future<void> _send(
    String text,
    List<TurnHistoryEntry> history, {
    String? selectedId,
    required int generation,
  }) async {
    _phase = AssistantPhase.thinking;
    _emotion = AvatarEmotion.thinking;
    notifyListeners();

    try {
      final turn = await _repository.turn(
        text,
        history,
        selectedId: selectedId,
      );
      if (generation != _generation) return;
      debugPrint('[assistant] turn: ${turn.kind.name} ${turn.tool ?? '-'}');
      _history = _trimmed([
        ...history,
        TurnHistoryEntry(TurnRole.user, text),
        TurnHistoryEntry(TurnRole.assistant, turn.reply),
      ]);
      if (turn.kind == TurnKind.clarify && turn.options.isNotEmpty) {
        _clarifying = (text: text, history: history);
      }
      _options = turn.kind == TurnKind.clarify ? turn.options : const [];
      _suggestions = turn.suggestions;
      final action = turn.action;
      if (turn.kind == TurnKind.confirm && action != null) {
        await _askToConfirm(turn.reply, action, generation);
      } else {
        await _say(turn.reply, turn.emotion);
      }
    } on AssistantException catch (e) {
      if (generation != _generation) return;
      if (fallbackKinds.contains(e.kind) && AssistantTurn.needsBriefing(text)) {
        // Not added to history: the AI service never saw this exchange.
        final reply = await _fallback.answer(text);
        if (generation != _generation) return;
        await _say(reply.text, reply.emotion);
      } else {
        await _say(e.message, AvatarEmotion.sad);
      }
    }
  }

  /// FR-22c: keeps the action and asks "Có / Không". Adding time first shows what moves.
  Future<void> _askToConfirm(
    String reply,
    TurnAction action,
    int generation,
  ) async {
    OverrunPlan? plan;
    var question = reply;
    if (action.type == TurnActionType.extendTimer) {
      try {
        plan = await _commands.previewExtend(action);
      } on CommandException catch (e) {
        if (generation != _generation) return;
        return _say(e.message, AvatarEmotion.sad);
      }
      if (generation != _generation) return;
      question = '${plan.summary} Áp dụng nhé?';
    }
    _pending = (action: action, plan: plan);
    _suggestions = const [yes, no];
    await _say(question, AvatarEmotion.thinking);
  }

  Future<void> _run(
    TurnAction action,
    OverrunPlan? plan,
    int generation,
  ) async {
    _phase = AssistantPhase.thinking;
    _emotion = AvatarEmotion.thinking;
    notifyListeners();
    try {
      final done = await _commands.run(action, plan: plan);
      if (generation != _generation) return;
      await _say(done, AvatarEmotion.happy);
    } on CommandException catch (e) {
      if (generation != _generation) return;
      await _say(e.message, AvatarEmotion.sad);
    }
  }

  static const List<String> _yesWords = [
    'co',
    'ok',
    'oke',
    'okay',
    'dong y',
    'duoc',
    'chac chan',
    'lam di',
    'u',
    'uh',
    'vang',
    'da',
    'yes',
    'yeah',
    'yep',
    'sure',
    'go ahead',
  ];
  static const List<String> _noWords = [
    'khong',
    'thoi',
    'huy',
    'khoi',
    'dung',
    'chua',
    'no',
    'nope',
    'cancel',
    'not now',
  ];

  /// FR-22c: true for a short yes ("Có", "Ok đồng ý"), false for a no ("Thôi", "Không"),
  /// null for anything else — that is a new question and drops the waiting command.
  static bool? confirmation(String sentence) {
    final words = IntentRouter.normalize(sentence);
    if (words.isEmpty || words.split(' ').length > 4) return null;
    bool has(List<String> list) =>
        list.any((w) => RegExp('\\b$w\\b').hasMatch(words));
    final saidNo = has(_noWords);
    if (saidNo) return false; // "không đồng ý" is a no
    return has(_yesWords) ? true : null;
  }

  Future<void> _say(String text, AvatarEmotion emotion) async {
    debugPrint('[assistant] ${emotion.name}: $text');
    _reply = text;
    _emotion = emotion;
    _noVoice = false;
    _phase = AssistantPhase.speaking;
    notifyListeners();

    final generation = _generation;
    final spoke = await _speak(text);
    if (spoke || generation != _generation) return;
    _noVoice = true;
    _phase = AssistantPhase.idle;
    notifyListeners();
  }

  void _clear() {
    _heard = '';
    _reply = null;
    _noVoice = false;
    _emotion = AvatarEmotion.neutral;
    _options = const [];
    _suggestions = const [];
    _clarifying = null;
  }

  /// The last [historyMaxEntries] lines, then oldest dropped until within [historyMaxChars].
  static List<TurnHistoryEntry> _trimmed(List<TurnHistoryEntry> entries) {
    var kept = entries.length > historyMaxEntries
        ? entries.sublist(entries.length - historyMaxEntries)
        : entries;
    int chars(List<TurnHistoryEntry> list) =>
        list.fold(0, (sum, entry) => sum + entry.text.length);
    while (kept.isNotEmpty && chars(kept) > historyMaxChars) {
      kept = kept.sublist(1);
    }
    return List.unmodifiable(kept);
  }
}
