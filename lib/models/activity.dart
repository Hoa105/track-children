/// Which detail-screen variant an activity opens, driven by its group's
/// `kind` in the prototype's mock data.
enum ActivityKind { move, music, story }

class Activity {
  final String id;
  final String groupId;
  final String name;
  final String ageRangeLabel; // prototype field `a`
  final String durationLabel; // prototype field `t`
  final bool isDone; // prototype field `d`
  final ActivityKind kind;
  final bool isFavorite;

  // Detail-screen fields (populated for the handful of activities that have
  // a full detail example in the prototype; others fall back to generic copy).
  final String? goal;
  final List<String> materials;
  final List<String> steps;
  final String? safetyNote;
  final String? lyrics;
  final String? movementTip;
  final List<String> storyParagraphs;
  final String? questionsToAsk;
  final String? tagsNote;

  const Activity({
    required this.id,
    required this.groupId,
    required this.name,
    required this.ageRangeLabel,
    required this.durationLabel,
    required this.isDone,
    required this.kind,
    this.isFavorite = false,
    this.goal,
    this.materials = const [],
    this.steps = const [],
    this.safetyNote,
    this.lyrics,
    this.movementTip,
    this.storyParagraphs = const [],
    this.questionsToAsk,
    this.tagsNote,
  });

  Activity copyWith({bool? isDone, bool? isFavorite}) => Activity(
        id: id,
        groupId: groupId,
        name: name,
        ageRangeLabel: ageRangeLabel,
        durationLabel: durationLabel,
        isDone: isDone ?? this.isDone,
        kind: kind,
        isFavorite: isFavorite ?? this.isFavorite,
        goal: goal,
        materials: materials,
        steps: steps,
        safetyNote: safetyNote,
        lyrics: lyrics,
        movementTip: movementTip,
        storyParagraphs: storyParagraphs,
        questionsToAsk: questionsToAsk,
        tagsNote: tagsNote,
      );
}
