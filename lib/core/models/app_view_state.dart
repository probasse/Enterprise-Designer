enum ShellTab { dashboard, projects, calendar, assignees }

class AppViewState {
  const AppViewState({
    this.isBootstrapping = true,
    this.isFirebaseConfigured = false,
    this.isAuthenticated = false,
    this.activeTab = ShellTab.dashboard,
    this.selectedProjectId,
    this.errorMessage,
  });

  final bool isBootstrapping;
  final bool isFirebaseConfigured;
  final bool isAuthenticated;
  final ShellTab activeTab;
  final String? selectedProjectId;
  final String? errorMessage;

  AppViewState copyWith({
    bool? isBootstrapping,
    bool? isFirebaseConfigured,
    bool? isAuthenticated,
    ShellTab? activeTab,
    String? selectedProjectId,
    String? errorMessage,
    bool clearError = false,
    bool clearSelectedProject = false,
  }) {
    return AppViewState(
      isBootstrapping: isBootstrapping ?? this.isBootstrapping,
      isFirebaseConfigured: isFirebaseConfigured ?? this.isFirebaseConfigured,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      activeTab: activeTab ?? this.activeTab,
      selectedProjectId: clearSelectedProject
          ? null
          : selectedProjectId ?? this.selectedProjectId,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}
