import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/dashboard_widgets.dart';
import '../widgets/order_management_widgets.dart';
import '../services/web_notification_helper.dart';

class HomeScreenWeb extends StatefulWidget {
  const HomeScreenWeb({super.key});

  @override
  State<HomeScreenWeb> createState() => _HomeScreenWebState();
}

class _HomeScreenWebState extends State<HomeScreenWeb> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestWebNotificationPermission();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AttendanceProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1350),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 24.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header (Reference image layout: Title on left, Download + Coral Pill on right)
                  _buildHeader(context, provider, isDark),
                  const SizedBox(height: 28),

                  // Top Metric Cards Row (Reference image layout: 3 metric cards + 1 wide completion card)
                  _buildMetricCards(context, provider, isDark),
                  const SizedBox(height: 28),

                  // Attendance Dashboard Widgets
                  _buildDashboardWidgets(context, provider),

                  // Bottom padding
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final userName = provider.userName.split(' ').first;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left Title & Subtitle
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: isDark ? Colors.white : const Color(0xFF1E2022),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Good morning, $userName! 👋 Here\'s what\'s happening with your team today.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCards(
    BuildContext context,
    AttendanceProvider provider,
    bool isDark,
  ) {
    final totalEmployees = provider.employees.length;
    final now = DateTime.now();

    final presentIds = provider.allCompanyRecords
        .where(
          (r) =>
              r.checkIn.year == now.year &&
              r.checkIn.month == now.month &&
              r.checkIn.day == now.day &&
              r.employeeId != null,
        )
        .map((r) => r.employeeId!)
        .toSet();

    final onLeaveIds = provider.allCompanyRequests
        .where((req) => req.status == 'Approved' && req.employeeId != null)
        .where((req) {
          final todayStr = DateFormat('MMMM d').format(now);
          return req.date.contains(todayStr);
        })
        .map((req) => req.employeeId!)
        .toSet();

    final actuallyOnLeaveIds = onLeaveIds.difference(presentIds);
    final presentToday = presentIds.length;
    final onLeave = actuallyOnLeaveIds.length;
    final absent = (totalEmployees - presentToday - onLeave).clamp(
      0,
      totalEmployees,
    );

    final screenWidth = MediaQuery.of(context).size.width;

    final staffCard = OrderMetricCard(
      title: 'Total Staff Members',
      value: '$totalEmployees',
      icon: Icons.groups_outlined,
    );

    final presentCard = OrderMetricCard(
      title: 'Present Today ($absent absent)',
      value: '$presentToday',
      icon: Icons.check_circle_outline_rounded,
    );

    final leaveCard = OrderMetricCard(
      title: 'On Approved Leave',
      value: '$onLeave',
      icon: Icons.flight_takeoff_rounded,
    );

    final completionCard = OrderCompletionCard(
      title: 'Today Attendance Complete',
      completedCount: presentToday,
      totalCount: totalEmployees > 0 ? totalEmployees : 1,
    );

    if (screenWidth >= 1150) {
      // 4-card wide layout matching reference image
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 1, child: staffCard),
          const SizedBox(width: 18),
          Expanded(flex: 1, child: presentCard),
          const SizedBox(width: 18),
          Expanded(flex: 1, child: leaveCard),
          const SizedBox(width: 18),
          Expanded(flex: 2, child: completionCard),
        ],
      );
    } else if (screenWidth >= 760) {
      // 2x2 tablet layout
      return Column(
        children: [
          Row(
            children: [
              Expanded(child: staffCard),
              const SizedBox(width: 16),
              Expanded(child: presentCard),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: leaveCard),
              const SizedBox(width: 16),
              Expanded(child: completionCard),
            ],
          ),
        ],
      );
    } else {
      // Single column
      return Column(
        children: [
          staffCard,
          const SizedBox(height: 14),
          presentCard,
          const SizedBox(height: 14),
          leaveCard,
          const SizedBox(height: 14),
          completionCard,
        ],
      );
    }
  }

  Widget _buildDashboardWidgets(
    BuildContext context,
    AttendanceProvider provider,
  ) {
    final isWide = MediaQuery.of(context).size.width > 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pending Approvals (for HR, Admins, and Supervisors)
        const PendingApprovalsCard(),
        const SizedBox(height: 24),

        // Row 2: Attendance Overview Chart & Quick Actions
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 2, child: AttendanceOverviewChart()),
              SizedBox(width: 24),
              Expanded(flex: 1, child: QuickActionsList()),
            ],
          )
        else
          Column(
            children: const [
              AttendanceOverviewChart(),
              SizedBox(height: 24),
              QuickActionsList(),
            ],
          ),
        const SizedBox(height: 24),

        // Row 3: Department Attendance Chart & Recent Activities
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Expanded(flex: 1, child: DepartmentAttendanceChart()),
              SizedBox(width: 24),
              Expanded(flex: 1, child: RecentActivitiesList()),
            ],
          )
        else
          Column(
            children: const [
              DepartmentAttendanceChart(),
              SizedBox(height: 24),
              RecentActivitiesList(),
            ],
          ),
      ],
    );
  }
}
