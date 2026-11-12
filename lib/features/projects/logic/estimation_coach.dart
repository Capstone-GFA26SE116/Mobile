/// How the user's estimates in one work domain usually turn out (AI service FR-20).
class DomainBias {
  final String domainId;
  final String name;
  final int samples;
  final String confidence; // none / learning / confident
  final double? factor; // actual ÷ estimate, learned
  final String? direction; // slower / faster / accurate
  final int? percent; // |factor − 1| × 100

  const DomainBias({
    required this.domainId,
    required this.name,
    required this.samples,
    required this.confidence,
    this.factor,
    this.direction,
    this.percent,
  });

  factory DomainBias.fromJson(Map<String, dynamic> json) => DomainBias(
    domainId: json['domain_id'] as String,
    name: json['domain_name'] as String,
    samples: (json['samples'] as num?)?.toInt() ?? 0,
    confidence: json['confidence'] as String? ?? 'none',
    factor: (json['factor'] as num?)?.toDouble(),
    direction: json['direction'] as String?,
    percent: (json['percent'] as num?)?.toInt(),
  );
}

/// The estimation coach: one line under the estimate while a task is created.
/// It only informs; the number stays the user's (the scheduler already corrects
/// for the habit, so changing the estimate too would count it twice).
class EstimationCoach {
  /// Smaller gaps are not worth a remark.
  static const int minPercent = 10;

  static String? hint(DomainBias? bias, int? minutes) {
    if (bias == null || minutes == null || minutes <= 0) return null;
    final factor = bias.factor;
    final percent = bias.percent;
    if (bias.confidence == 'none' || factor == null || percent == null)
      return null;
    if (percent < minPercent) return null;
    final likely = roundTo5(minutes * factor);
    final String habit;
    switch (bias.direction) {
      case 'slower':
        habit = 'usually take about $percent% longer than you estimate';
      case 'faster':
        habit = 'usually finish about $percent% sooner than you estimate';
      default:
        return null;
    }
    final early = bias.confidence == 'learning'
        ? ' (early sign, ${bias.samples} tasks)'
        : '';
    return 'In ${bias.name} you $habit$early. '
        '$minutes min may really take about $likely min.';
  }

  static int roundTo5(double minutes) {
    final rounded = (minutes / 5).round() * 5;
    return rounded < 5 ? 5 : rounded;
  }
}
