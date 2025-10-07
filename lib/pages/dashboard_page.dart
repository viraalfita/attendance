import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:slide_to_act/slide_to_act.dart';

import '../models/attendance.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String? checkInTime;
  String? checkOutTime;
  List<Attendance> todayAttendances = [];
  List<Attendance> myAttendances = [];
  bool isLoading = true;
  int onTimeCount = 0;
  int lateCount = 0;
  String _username = "";
  String _timeStart = "";
  String _timeEnd = "";

  final GlobalKey<SlideActionState> _sliderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  String _formatToLocal(String isoString) {
    try {
      final utcTime = DateTime.parse(isoString);
      final localTime = utcTime.toLocal();
      return DateFormat('HH:mm').format(localTime);
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return '-';
    }
  }

  Future<void> _bootstrap() async {
    await ApiService.loadSession();
    await Future.wait([
      _loadProfile(),
      _loadCompanyHours(),
      _loadTodayAttendances(),
      _loadMyAttendances(),
    ]);
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = prefs.getString("username") ?? "Unknown";
    });
  }

  Future<void> _loadCompanyHours() async {
    try {
      final hours = await ApiService.getCompanyHours();
      debugPrint('Company hours: $hours');
      if (hours.isNotEmpty) {
        setState(() {
          _timeStart = _formatToLocal(hours['time_start'] ?? '');
          _timeEnd = _formatToLocal(hours['time_end'] ?? '');
        });
      }
    } catch (e) {
      debugPrint('Error loading company hours: $e');
    }
  }

  Future<void> _loadTodayAttendances() async {
    try {
      final attendances = await ApiService.getAttendanceByDay();
      setState(() {
        todayAttendances = attendances;
      });
    } catch (e) {
      debugPrint('Error loading today attendances: $e');
    }
  }

  Future<void> _loadMyAttendances() async {
    try {
      final attendances = await ApiService.getMyAttendance();
      setState(() {
        myAttendances = attendances;
        _calculateStats();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error loading my attendances: $e');
    }
  }

  void _calculateStats() {
    int onTime = 0;
    int late = 0;

    for (var attendance in myAttendances) {
      if (attendance.type == 'checkin') {
        if (attendance.late == true) {
          late++;
        } else {
          onTime++;
        }
      }
    }

    setState(() {
      onTimeCount = onTime;
      lateCount = late;
    });
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _handleCheckIn() async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    bool success = await ApiService.checkIn(
      position.latitude,
      position.longitude,
    );
    if (success) {
      await _loadTodayAttendances();
      await _loadMyAttendances();
      setState(() {
        checkInTime = DateFormat("HH:mm").format(DateTime.now());
      });
    }
  }

  Future<void> _handleCheckOut() async {
    final position = await _getCurrentLocation();
    if (position == null) return;

    bool success = await ApiService.checkOut(
      position.latitude,
      position.longitude,
    );
    if (success) {
      await _loadTodayAttendances();
      await _loadMyAttendances();
      setState(() {
        checkOutTime = DateFormat("HH:mm").format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasCheckedIn = todayAttendances.any((att) => att.type == 'checkin');
    final totalAttendances = onTimeCount + lateCount;
    final onTimePercentage = totalAttendances > 0
        ? (onTimeCount / totalAttendances * 100)
        : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // === Header Section (Putih) ===
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                        image: const DecorationImage(
                          image: AssetImage("assets/att_avatar.png"),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Good ${_greeting()}!",
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _username.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        DateFormat('EEE, MMM d').format(DateTime.now()),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // === Scrollable Content ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === Schedule Cards ===
                    Row(
                      children: [
                        Expanded(
                          child: _ScheduleCard(
                            icon: Icons.login_rounded,
                            title: "Check In Time",
                            value: _timeStart,
                            color: Colors.green.shade500,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ScheduleCard(
                            icon: Icons.logout_rounded,
                            title: "Check Out Time",
                            value: _timeEnd,
                            color: Colors.orange.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // === Statistics Card ===
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Colors.white, Colors.grey.shade50],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Attendance Overview",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(
                                color: Colors.green.shade500,
                                icon: Icons.check_circle_outline_outlined,
                                count: onTimeCount,
                                label: "On Time",
                                percentage: totalAttendances > 0
                                    ? '${(onTimeCount / totalAttendances * 100).toStringAsFixed(0)}%'
                                    : '0%',
                              ),
                              _StatItem(
                                color: Colors.orange.shade500,
                                icon: Icons.schedule_rounded,
                                count: lateCount,
                                label: "Late",
                                percentage: totalAttendances > 0
                                    ? '${(lateCount / totalAttendances * 100).toStringAsFixed(0)}%'
                                    : '0%',
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (totalAttendances > 0) ...[
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: onTimePercentage / 100,
                              backgroundColor: Colors.grey.shade300,
                              color: Colors.green.shade500,
                              borderRadius: BorderRadius.circular(10),
                              minHeight: 6,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "On Time Rate",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  "${onTimePercentage.toStringAsFixed(1)}%",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // === Activity Header ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Today's Activity",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            _loadTodayAttendances();
                            _loadMyAttendances();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.refresh_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  "Refresh",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // === Activity List ===
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      )
                    else if (todayAttendances.isEmpty)
                      _buildEmptyActivity()
                    else
                      ...todayAttendances.map(
                        (attendance) => ActivityItem(
                          icon: attendance.type == 'checkin'
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          title: attendance.type == 'checkin'
                              ? "Check In"
                              : "Check Out",
                          time: _formatTime(attendance.time),
                          date: _formatDate(attendance.time),
                          status: _getStatus(attendance),
                          isCheckIn: attendance.type == 'checkin',
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // === Fixed Slider ===
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SlideAction(
                key: _sliderKey,
                borderRadius: 16,
                elevation: 0,
                outerColor: !hasCheckedIn
                    ? Colors.green.shade500
                    : AppColors.primary,
                innerColor: Colors.white,
                height: 56,
                sliderButtonIcon: Icon(
                  !hasCheckedIn ? Icons.login_rounded : Icons.logout_rounded,
                  color: !hasCheckedIn
                      ? Colors.green.shade500
                      : AppColors.primary,
                  size: 24,
                ),
                text: !hasCheckedIn
                    ? "Slide to Check In"
                    : "Slide to Check Out",
                textStyle: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                onSubmit: () async {
                  if (!hasCheckedIn) {
                    await _handleCheckIn();
                  } else {
                    await _handleCheckOut();
                  }
                  Future.delayed(const Duration(milliseconds: 500), () {
                    _sliderKey.currentState?.reset();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyActivity() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 64,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            "No Activities Today",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your activities will appear here",
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat("HH:mm").format(local);
  }

  String _formatDate(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat("MMM dd, yyyy").format(local);
  }

  String _getStatus(Attendance attendance) {
    if (attendance.type == 'checkin') {
      return attendance.late == true ? "Late" : "On Time";
    }
    return "Completed";
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Morning";
    if (hour < 17) return "Afternoon";
    if (hour < 19) return "Evening";
    return "Night";
  }
}

// ===== Schedule Card =====
class _ScheduleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _ScheduleCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== Stat Item Widget =====
class _StatItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int count;
  final String label;
  final String percentage;

  const _StatItem({
    required this.color,
    required this.icon,
    required this.count,
    required this.label,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          percentage,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ===== Activity Item =====
class ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String time;
  final String date;
  final String status;
  final bool isCheckIn;

  const ActivityItem({
    super.key,
    required this.icon,
    required this.title,
    required this.time,
    required this.date,
    required this.status,
    required this.isCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isCheckIn
                  ? Colors.green.shade50
                  : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isCheckIn ? Colors.green.shade600 : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: status == "Late"
                      ? Colors.orange.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: status == "Late"
                        ? Colors.orange.shade200
                        : Colors.green.shade200,
                    width: 1,
                  ),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: status == "Late"
                        ? Colors.orange.shade600
                        : Colors.green.shade600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
