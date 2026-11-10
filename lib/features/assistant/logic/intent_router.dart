/// MVP command matching (plan decision #4): one command, matched by keywords on the device.
/// Phase B replaces this with the AI service's `/assistant/turn` agent.
enum AssistantIntent { briefing, unknown }

class IntentRouter {
  static const String fallbackReply = 'Bạn thử hỏi: Hôm nay tôi nên làm gì?';

  static const List<String> _briefingKeywords = [
    'hom nay',
    'lam gi',
    'uu tien',
    'viec gi',
    'today',
  ];

  /// Words that point to another `/assistant/turn` tool (timer, habits, projects, quota,
  /// another part of the day). A sentence with one of them is not "what do I do today",
  /// even when it also says "viec gi" or "hom nay" — reading the briefing would answer wrongly.
  static const List<String> _otherTopicKeywords = [
    'bam gio',
    'dang chay',
    'timer',
    'tre',
    'thoi quen',
    'uoc tinh',
    'bao lau',
    'du an',
    'project',
    'projects',
    'tien do',
    'luot',
    'quota',
    'khung gio',
    'gio nao',
    'sang nay',
    'chieu nay',
    'toi nay',
    'ngay mai',
    'tomorrow',
    'morning',
    'afternoon',
    'evening',
  ];

  static AssistantIntent route(String sentence) {
    final text = normalize(sentence);
    for (final keyword in _otherTopicKeywords) {
      if (RegExp('\\b$keyword\\b').hasMatch(text)) return AssistantIntent.unknown;
    }
    for (final keyword in _briefingKeywords) {
      if (RegExp('\\b$keyword\\b').hasMatch(text)) return AssistantIntent.briefing;
    }
    return AssistantIntent.unknown;
  }

  /// Lowercase, strip Vietnamese diacritics (precomposed or combining), collapse whitespace.
  static String normalize(String input) {
    final buffer = StringBuffer();
    for (final rune in input.toLowerCase().runes) {
      if (rune >= 0x0300 && rune <= 0x036F) continue; // combining marks (NFD input)
      final char = String.fromCharCode(rune);
      buffer.write(_plainLetter[char] ?? char);
    }
    return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static final Map<String, String> _plainLetter = {
    for (final entry in const {
      'a': 'àáạảãâầấậẩẫăằắặẳẵ',
      'e': 'èéẹẻẽêềếệểễ',
      'i': 'ìíịỉĩ',
      'o': 'òóọỏõôồốộổỗơờớợởỡ',
      'u': 'ùúụủũưừứựửữ',
      'y': 'ỳýỵỷỹ',
      'd': 'đ',
    }.entries)
      for (final accented in entry.value.split('')) accented: entry.key,
  };
}
