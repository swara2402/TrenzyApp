import 'product_model.dart';

class DecisionFlow {
  final String? id;
  final String? name;
  final String? description;
  final List<DecisionStep>? steps;
  final DateTime? createdAt;
  final bool? isCompleted;

  DecisionFlow({
    this.id,
    this.name,
    this.description,
    this.steps,
    this.createdAt,
    this.isCompleted,
  });

  factory DecisionFlow.fromJson(Map<String, dynamic> json) {
    return DecisionFlow(
      id: json['id'] as String?,
      name: json['name'] as String?,
      description: json['description'] as String?,
      steps: (json['steps'] as List<dynamic>?)
          ?.map((item) => DecisionStep.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'steps': steps?.map((item) => item.toJson()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }
}

class DecisionStep {
  final String? id;
  final String? title;
  final String? question;
  final List<String>? options;
  final String? selectedOption;
  final bool? isCompleted;

  DecisionStep({
    this.id,
    this.title,
    this.question,
    this.options,
    this.selectedOption,
    this.isCompleted,
  });

  factory DecisionStep.fromJson(Map<String, dynamic> json) {
    return DecisionStep(
      id: json['id'] as String?,
      title: json['title'] as String?,
      question: json['question'] as String?,
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      selectedOption: json['selectedOption'] as String?,
      isCompleted: json['isCompleted'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'question': question,
      'options': options,
      'selectedOption': selectedOption,
      'isCompleted': isCompleted,
    };
  }
}

class SuggestionOption {
  final ProductModel product;
  final double matchScore;

  SuggestionOption({
    required this.product,
    this.matchScore = 0.0,
  });
}

class DecisionRouteExtra {
  final String query;
  final List<SuggestionOption> selectedOptions;
  final List<dynamic> reactions;

  DecisionRouteExtra({
    required this.query,
    required this.selectedOptions,
    this.reactions = const [],
  });
}