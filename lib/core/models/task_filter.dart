class TaskFilter {
  const TaskFilter({this.projectId, this.status, this.upcomingOnly = false});

  final String? projectId;
  final String? status;
  final bool upcomingOnly;

  TaskFilter copyWith({
    String? projectId,
    bool clearProject = false,
    String? status,
    bool clearStatus = false,
    bool? upcomingOnly,
  }) {
    return TaskFilter(
      projectId: clearProject ? null : projectId ?? this.projectId,
      status: clearStatus ? null : status ?? this.status,
      upcomingOnly: upcomingOnly ?? this.upcomingOnly,
    );
  }
}
