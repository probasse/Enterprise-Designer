import 'package:flutter/material.dart';

import '../../core/app_controller.dart';
import '../../core/models/app_view_state.dart';
import '../../core/models/assignee_model.dart';
import '../../shared/widgets/feedback_banner.dart';
import '../../shared/widgets/notification_bell.dart';
import '../assignees/assignees_screen.dart';
import '../auth/auth_screen.dart';
import '../calendar/calendar_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../projects/projects_screen.dart';
import '../setup/firebase_setup_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool _sidebarCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.viewState;

    if (!state.isFirebaseConfigured) {
      return FirebaseSetupScreen(controller: widget.controller);
    }

    if (!state.isAuthenticated) {
      return AuthScreen(controller: widget.controller);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 980;
        final isMid = constraints.maxWidth < 1200;
        final expandedRailWidth = isMid ? 240.0 : 280.0;

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4EFE7), Color(0xFFE6F1EC)],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // ── Impersonation banner ──────────────────────────────
                  if (widget.controller.isImpersonating)
                    _ImpersonationBanner(
                      assignee: widget.controller.impersonatedAssignee!,
                      roleLabel: widget.controller
                          .roleLabel(widget.controller.impersonatedAssignee!.role),
                      onStop: widget.controller.stopImpersonation,
                    ),
                  Expanded(
                    child: Row(
                      children: [
                        if (!isCompact)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            width: _sidebarCollapsed ? 72 : expandedRailWidth,
                            child: _PlannerRail(
                              collapsed: _sidebarCollapsed,
                              selectedTab: state.activeTab,
                              onSelected: widget.controller.setActiveTab,
                              onToggleCollapse: () => setState(
                                  () => _sidebarCollapsed = !_sidebarCollapsed),
                              onSignOut: widget.controller.signOut,
                              userName: widget.controller.currentUserName,
                              userRoleLabel:
                                  widget.controller.currentUserRoleLabel,
                            ),
                          ),
                        Expanded(
                          child: Column(
                            children: [
                              // ── Top bar: bell always, sign-out on compact ──
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 4, 8, 0),
                                child: Row(
                                  children: [
                                    if (isCompact) ...[
                                      _UserAvatar(
                                        name: widget
                                            .controller.currentUserName,
                                        size: 30,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          widget.controller.currentUserName,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ] else
                                      const Spacer(),
                                    NotificationBell(
                                        controller: widget.controller),
                                    IconButton(
                                      tooltip: 'My Profile',
                                      icon: const Icon(
                                          Icons.account_circle_outlined),
                                      onPressed: () => showDialog<void>(
                                        context: context,
                                        builder: (_) => MyProfileDialog(
                                          controller: widget.controller,
                                        ),
                                      ),
                                    ),
                                    if (isCompact)
                                      TextButton.icon(
                                        onPressed: widget.controller.signOut,
                                        icon: const Icon(
                                            Icons.logout_rounded,
                                            size: 16),
                                        label: const Text('Sign out'),
                                      ),
                                  ],
                                ),
                              ),
                              FeedbackBanner(controller: widget.controller),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: _BodySwitcher(
                                      controller: widget.controller),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: isCompact
              ? NavigationBar(
                  selectedIndex: state.activeTab.index,
                  onDestinationSelected: (index) =>
                      widget.controller
                          .setActiveTab(ShellTab.values[index]),
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.folder_open_outlined),
                      selectedIcon: Icon(Icons.folder_open),
                      label: 'Projects',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.calendar_month_outlined),
                      selectedIcon: Icon(Icons.calendar_month),
                      label: 'Calendar',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: 'Assignees',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }
}

class _PlannerRail extends StatelessWidget {
  const _PlannerRail({
    required this.selectedTab,
    required this.onSelected,
    required this.onToggleCollapse,
    required this.onSignOut,
    required this.userName,
    required this.userRoleLabel,
    this.collapsed = false,
  });

  final ShellTab selectedTab;
  final ValueChanged<ShellTab> onSelected;
  final VoidCallback onToggleCollapse;
  final VoidCallback onSignOut;
  final String userName;
  final String userRoleLabel;
  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      child: Card(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: collapsed ? 4 : 12,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: collapsed
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              // ── Collapse / expand toggle ────────────────────────────
              Align(
                alignment: collapsed
                    ? Alignment.center
                    : Alignment.centerRight,
                child: IconButton(
                  tooltip:
                      collapsed ? 'Expand sidebar' : 'Collapse sidebar',
                  icon: Icon(
                    collapsed
                        ? Icons.keyboard_double_arrow_right_rounded
                        : Icons.keyboard_double_arrow_left_rounded,
                  ),
                  onPressed: onToggleCollapse,
                ),
              ),

              if (!collapsed) ...[
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'Project Planner',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    'Organize projects, tasks, and due dates from your own Firebase project.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 12),

              // ── Nav items ───────────────────────────────────────────
              for (final tab in ShellTab.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: collapsed
                      ? _CollapsedNavItem(
                          icon: _iconForTab(tab),
                          tooltip: _labelForTab(tab),
                          selected: selectedTab == tab,
                          onTap: () => onSelected(tab),
                          theme: theme,
                        )
                      : ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          selected: selectedTab == tab,
                          selectedTileColor:
                              theme.colorScheme.primary.withValues(alpha: 0.12),
                          leading: Icon(_iconForTab(tab)),
                          title: Text(_labelForTab(tab)),
                          onTap: () => onSelected(tab),
                        ),
                ),

              // ── Spacer + User card + Sign out ────────────────────────
              const Spacer(),
              const Divider(),
              if (collapsed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Tooltip(
                    message: userName,
                    preferBelow: false,
                    child: _UserAvatar(name: userName, size: 36),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      _UserAvatar(name: userName, size: 36),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (userRoleLabel.isNotEmpty)
                              Text(
                                userRoleLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              collapsed
                  ? _CollapsedNavItem(
                      icon: Icons.logout_rounded,
                      tooltip: 'Sign out',
                      selected: false,
                      onTap: onSignOut,
                      theme: theme,
                    )
                  : ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out'),
                      onTap: onSignOut,
                    ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForTab(ShellTab tab) {
    switch (tab) {
      case ShellTab.dashboard:
        return Icons.space_dashboard_rounded;
      case ShellTab.projects:
        return Icons.folder_copy_rounded;
      case ShellTab.calendar:
        return Icons.calendar_month_rounded;
      case ShellTab.assignees:
        return Icons.people_rounded;
    }
  }

  String _labelForTab(ShellTab tab) {
    switch (tab) {
      case ShellTab.dashboard:
        return 'Dashboard';
      case ShellTab.projects:
        return 'Projects';
      case ShellTab.calendar:
        return 'Calendar';
      case ShellTab.assignees:
        return 'Assignees';
    }
  }
}

/// Single icon-only nav button used in collapsed sidebar mode.
class _CollapsedNavItem extends StatelessWidget {
  const _CollapsedNavItem({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      preferBelow: false,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: selected ? theme.colorScheme.primary : null,
          ),
        ),
      ),
    );
  }
}

class _BodySwitcher extends StatelessWidget {
  const _BodySwitcher({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    switch (controller.viewState.activeTab) {
      case ShellTab.dashboard:
        return DashboardScreen(controller: controller);
      case ShellTab.projects:
        return ProjectsScreen(controller: controller);
      case ShellTab.calendar:
        return CalendarScreen(controller: controller);
      case ShellTab.assignees:
        return AssigneesScreen(controller: controller);
    }
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.name, this.size = 36});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initials(name);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _ImpersonationBanner extends StatelessWidget {
  const _ImpersonationBanner({
    required this.assignee,
    required this.roleLabel,
    required this.onStop,
  });

  final AssigneeModel assignee;
  final String roleLabel;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF3CD),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFFFD54F), width: 1.5),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.visibility_rounded,
                size: 18, color: Color(0xFF7B5700)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Viewing as ${assignee.name} ($roleLabel)',
                style: const TextStyle(
                  color: Color(0xFF7B5700),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            TextButton(
              onPressed: onStop,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF7B5700),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: const Text('Stop impersonating'),
            ),
          ],
        ),
      ),
    );
  }
}
