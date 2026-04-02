import 'project_model.dart';

/// Capability grant strings used in [AssigneeModel.projectGrants].
class ProjectGrant {
  ProjectGrant._();

  /// Permission to add and update tasks on a project.
  static const String tasks = 'tasks';

  /// Permission to add and update issues on a project.
  static const String issues = 'issues';

  /// Permission to add and update risks on a project.
  static const String risks = 'risks';

  /// Permission to add and update actions on a project.
  static const String actions = 'actions';

  /// Permission to add and update decisions on a project.
  static const String decisions = 'decisions';

  /// Returns the grant string that corresponds to a [ProjectRecordType].
  static String forRecordType(ProjectRecordType type) {
    switch (type) {
      case ProjectRecordType.issue:
        return issues;
      case ProjectRecordType.risk:
        return risks;
      case ProjectRecordType.action:
        return actions;
      case ProjectRecordType.decision:
        return decisions;
    }
  }

  static const List<String> all = [tasks, issues, risks, actions, decisions];
}
