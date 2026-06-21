// ============================================================
// SmartAttend — Admin Dashboard
// ============================================================

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../models/models.dart';
import '../../widgets/glassmorphism_card.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/stat_card.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = Get.find<AdminController>();
    final auth = Get.find<AuthController>();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
          child: SafeArea(
            child: Column(
              children: [
                // ─── Header ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.admin_panel_settings_rounded,
                            color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Admin Console',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              'SmartAttend',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded,
                            color: AppTheme.error),
                        onPressed: auth.logout,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ─── Stat Grid ─────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Obx(() => GridView.count(
                        shrinkWrap: true,
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.3,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          StatCard(
                            label: 'Total Students',
                            value: '${admin.totalStudents.value}',
                            icon: Icons.school_rounded,
                            color: AppTheme.primary,
                          ),
                          StatCard(
                            label: 'Faculty',
                            value: '${admin.totalFaculty.value}',
                            icon: Icons.person_rounded,
                            color: AppTheme.accent,
                          ),
                          StatCard(
                            label: 'Departments',
                            value: '${admin.totalDepartments.value}',
                            icon: Icons.business_rounded,
                            color: AppTheme.success,
                          ),
                          StatCard(
                            label: 'Classrooms',
                            value: '${admin.totalClassrooms.value}',
                            icon: Icons.meeting_room_rounded,
                            color: AppTheme.warning,
                            subtitle: 'ESP32 Beacons',
                          ),
                        ],
                      )),
                ),

                const SizedBox(height: 12),

                // ─── System Attendance Rate ─────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Obx(() => GlassmorphismCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.analytics_rounded,
                                color: AppTheme.primary, size: 22),
                            const SizedBox(width: 12),
                            const Text(
                              'System Attendance Rate',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${admin.systemAttendanceRate.value.toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: admin.systemAttendanceRate.value >= 75
                                    ? AppTheme.success
                                    : AppTheme.warning,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ],
                        ),
                      )),
                ),

                const SizedBox(height: 12),

                // ─── Tabs ──────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.bgCard,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const TabBar(
                      tabs: [
                        Tab(text: 'Students'),
                        Tab(text: 'Faculty'),
                        Tab(text: 'Rooms'),
                        Tab(text: 'Subjects'),
                      ],
                      indicator: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: AppTheme.textSecondary,
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      dividerColor: Colors.transparent,
                      padding: EdgeInsets.all(4),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: TabBarView(
                    children: [
                      _StudentsTab(admin: admin),
                      _FacultyTab(admin: admin),
                      _ClassroomsTab(admin: admin),
                      _SubjectsTab(admin: admin),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Students Tab ─────────────────────────────────────────────
class _StudentsTab extends StatefulWidget {
  final AdminController admin;
  const _StudentsTab({required this.admin});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.admin.fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search students...',
              prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear, color: AppTheme.textHint),
                onPressed: () {
                  _searchCtrl.clear();
                  widget.admin.fetchStudents();
                },
              ),
            ),
            onSubmitted: (v) => widget.admin.fetchStudents(search: v),
          ),
        ),
        const SizedBox(height: 12),
        // List
        Expanded(
          child: Obx(() {
            if (widget.admin.isLoading.value && widget.admin.students.isEmpty) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary));
            }
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: widget.admin.students.length,
              itemBuilder: (context, i) {
                final s = widget.admin.students[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassmorphismCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              s.name[0].toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.name,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                '${s.regNo} • ${s.department} • Yr ${s.year}${s.section}',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Face ID indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: s.hasFaceRegistered
                                ? AppTheme.success.withValues(alpha: 0.1)
                                : AppTheme.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            s.hasFaceRegistered ? '✓ Face' : '✗ Face',
                            style: TextStyle(
                              color: s.hasFaceRegistered
                                  ? AppTheme.success
                                  : AppTheme.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded,
                              color: AppTheme.error, size: 18),
                          onPressed: () => _confirmDelete(context, s),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _confirmDelete(BuildContext context, StudentModel s) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Student',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Remove ${s.name} from the system?',
            style: const TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.admin.deleteStudent(s.id);
            },
            child: const Text('Delete',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
  }
}

// ─── Faculty Tab ──────────────────────────────────────────────
class _FacultyTab extends StatefulWidget {
  final AdminController admin;
  const _FacultyTab({required this.admin});

  @override
  State<_FacultyTab> createState() => _FacultyTabState();
}

class _FacultyTabState extends State<_FacultyTab> {
  @override
  void initState() {
    super.initState();
    widget.admin.fetchFaculty();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          itemCount: widget.admin.faculty.length,
          itemBuilder: (context, i) {
            final f = widget.admin.faculty[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GlassmorphismCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          f.name[0].toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            f.name,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            f.email,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        color: AppTheme.textHint, size: 18),
                  ],
                ),
              ),
            );
          },
        ));
  }
}

// ─── Classrooms Tab ───────────────────────────────────────────
class _ClassroomsTab extends StatefulWidget {
  final AdminController admin;
  const _ClassroomsTab({required this.admin});

  @override
  State<_ClassroomsTab> createState() => _ClassroomsTabState();
}

class _ClassroomsTabState extends State<_ClassroomsTab> {
  @override
  void initState() {
    super.initState();
    widget.admin.fetchClassrooms();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() => Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: widget.admin.classrooms.length,
                itemBuilder: (context, i) {
                  final c = widget.admin.classrooms[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GlassmorphismCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.meeting_room_rounded,
                                color: AppTheme.warning, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.roomName,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'UUID: ${c.bleUuid}',
                                  style: const TextStyle(
                                    color: AppTheme.textHint,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.bluetooth,
                              color: AppTheme.primary, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: GradientButton(
                text: 'Add Classroom',
                icon: Icons.add_rounded,
                onPressed: () => _showAddClassroomDialog(context),
              ),
            ),
          ],
        ));
  }

  void _showAddClassroomDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final uuidCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Add Classroom',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Room Name (e.g. CLASSROOM_A101)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: uuidCtrl,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: const InputDecoration(
                labelText: 'ESP32 BLE UUID',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.admin.addClassroom(
                nameCtrl.text.trim().toUpperCase(),
                uuidCtrl.text.trim(),
              );
            },
            child: const Text('Add',
                style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }
}

// ─── Subjects Tab ─────────────────────────────────────────────
class _SubjectsTab extends StatefulWidget {
  final AdminController admin;
  const _SubjectsTab({required this.admin});

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  @override
  void initState() {
    super.initState();
    // Reuse classrooms fetch to get subjects from faculty data
  }

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_rounded, color: AppTheme.textHint, size: 48),
          SizedBox(height: 12),
          Text(
            'Subject management via\nAdmin API endpoint',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}
