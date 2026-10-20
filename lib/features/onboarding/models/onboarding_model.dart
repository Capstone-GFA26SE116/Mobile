class DomainModel {
  final String id;
  final String name;

  DomainModel({required this.id, required this.name});

  factory DomainModel.fromJson(Map<String, dynamic> json) {
    return DomainModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
    );
  }
}

class OnboardingRequest {
  final String workDayStart;
  final String workDayEnd;
  final bool worksOnWeekend;
  final List<String> domainIds;
  final List<int> productiveHours;
  final String overrunLevel;

  OnboardingRequest({
    required this.workDayStart,
    required this.workDayEnd,
    required this.worksOnWeekend,
    required this.domainIds,
    required this.productiveHours,
    required this.overrunLevel,
  });

  Map<String, dynamic> toJson() {
    return {
      'workDayStart': workDayStart,
      'workDayEnd': workDayEnd,
      'worksOnWeekend': worksOnWeekend,
      'domainIds': domainIds,
      'productiveHours': productiveHours,
      'overrunLevel': overrunLevel,
    };
  }
}
