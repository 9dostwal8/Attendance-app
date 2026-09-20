import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/attendance_provider.dart';
import '../widgets/dashboard_widgets.dart';
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

    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background gradient is on the shell
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // Header
              Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good morning, ${provider.userName.split(' ').first}! 👋',
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Here\'s what\'s happening with your team today.',
                            style: TextStyle(
                              color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black).withValues(alpha: 0.6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),

                    ],
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Dashboard Stats (Web specific)
              _buildWebDashboardStats(context, provider),
              const SizedBox(height: 32),

              // Extra padding to scroll above bottom nav bar
              const SizedBox(height: 100),
            ],
          ),
        ),
        ),
        ),
      ),
    );
  }





  Widget _buildWebDashboardStats(BuildContext context, AttendanceProvider provider) {
    final totalEmployees = provider.employees.length;
    final now = DateTime.now();

    final presentIds = provider.allCompanyRecords
        .where((r) =>
            r.checkIn.year == now.year &&
            r.checkIn.month == now.month &&
            r.checkIn.day == now.day &&
            r.employeeId != null)
        .map((r) => r.employeeId!)
        .toSet();
        
    final onLeaveIds = provider.allCompanyRequests
        .where((req) => req.status == 'Approved' && req.employeeId != null)
        .where((req) {
          // req.date is often "May 14, 2026" or "June 15 - June 18, 2026"
          final todayStr = DateFormat('MMMM d').format(now);
          return req.date.contains(todayStr);
        })
        .map((req) => req.employeeId!)
        .toSet();

    // Ensure an employee is not double counted
    final actuallyOnLeaveIds = onLeaveIds.difference(presentIds);

    final presentToday = presentIds.length;
    final onLeave = actuallyOnLeaveIds.length;
    final absent = (totalEmployees - presentToday - onLeave).clamp(0, totalEmployees);

    final isWide = MediaQuery.of(context).size.width > 1000;

    final presentPerc = totalEmployees > 0 ? (presentToday / totalEmployees * 100).toStringAsFixed(1) : '0.0';
    final absentPerc = totalEmployees > 0 ? (absent / totalEmployees * 100).toStringAsFixed(1) : '0.0';
    final onLeavePerc = totalEmployees > 0 ? (onLeave / totalEmployees * 100).toStringAsFixed(1) : '0.0';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Metric Cards
        GridView.count(
          crossAxisCount: isWide ? 4 : 2,
          crossAxisSpacing: 24,
          mainAxisSpacing: 24,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: isWide ? 1.25 : 1.5, // Decreased from 1.8 to give more height
          children: [
            MetricCard(
              title: 'Total Staff',
              value: '$totalEmployees',
              icon: Icons.people,
              color: const Color(0xFF3B82F6),
              trend: 'All Employees',
              isPositiveTrend: true,
            ),
            MetricCard(
              title: 'Present',
              value: '$presentToday',
              icon: Icons.check_circle,
              color: const Color(0xFF10B981),
              trend: '$presentPerc%',
              isPositiveTrend: true,
            ),
            MetricCard(
              title: 'Absent',
              value: '$absent',
              icon: Icons.cancel,
              color: const Color(0xFFEF4444),
              trend: '$absentPerc%',
              isPositiveTrend: false,
            ),
            MetricCard(
              title: 'On Leave',
              value: '$onLeave',
              icon: Icons.flight_takeoff,
              color: const Color(0xFFF59E0B),
              trend: '$onLeavePerc%',
              isPositiveTrend: true,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Pending Approvals (for HR, Admins, and Supervisors)
        const PendingApprovalsCard(),
        const SizedBox(height: 24),
        
        // Row 2: Charts and Quick Actions
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 2, child: const AttendanceOverviewChart()),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: const QuickActionsList()),
            ],
          )
        else
          Column(
            children: [
              const AttendanceOverviewChart(),
              const SizedBox(height: 24),
              const QuickActionsList(),
            ],
          ),
        const SizedBox(height: 24),
        
        // Row 3: Department and Recent Activities
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: const DepartmentAttendanceChart()),
              const SizedBox(width: 24),
              Expanded(flex: 1, child: const RecentActivitiesList()),
            ],
          )
        else
          Column(
            children: [
              const DepartmentAttendanceChart(),
              const SizedBox(height: 24),
              const RecentActivitiesList(),
            ],
          ),
      ],
    );
  }
}
