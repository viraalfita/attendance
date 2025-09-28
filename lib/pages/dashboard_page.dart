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
    _bootstrap(); // jangan langsung call _loadCompanyHours()
  }

  String _formatToLocal(String isoString) {
    try {
      final utcTime = DateTime.parse(isoString); // otomatis UTC karena ada 'Z'
      final localTime = utcTime.toLocal(); // konversi sesuai zona device
      return DateFormat('HH:mm').format(localTime);
    } catch (e) {
      debugPrint('Error parsing time: $e');
      return '-';
    }
  }

  Future<void> _bootstrap() async {
    // Tarik token, userId, companyCode dari SharedPreferences
    await ApiService.loadSession();

    // (Optional) parallel load biar cepat
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // === scrollable content ===
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HEADER
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundImage: AssetImage("assets/att_avatar.png"),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Good ${_greeting()}",
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              _username.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // SCHEDULE
                    Row(
                      children: [
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.login,
                            title: "Check In",
                            value: _timeStart,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _InfoCard(
                            icon: Icons.logout,
                            title: "Check Out",
                            value: _timeEnd,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // STATISTICS CARD
                    Card(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatItem(
                              color: Colors.green,
                              icon: Icons.check_circle,
                              count: onTimeCount,
                              label: "On Time",
                            ),
                            _StatItem(
                              color: Colors.red,
                              icon: Icons.watch_later,
                              count: lateCount,
                              label: "Late",
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ACTIVITY HEADER
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Your Activity Today",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            _loadTodayAttendances();
                            _loadMyAttendances();
                          },
                          child: const Text(
                            "Refresh",
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (todayAttendances.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          "No activities today",
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      ...todayAttendances.map(
                        (attendance) => ActivityItem(
                          icon: attendance.type == 'checkin'
                              ? Icons.login
                              : Icons.logout,
                          title: attendance.type == 'checkin'
                              ? "Check In"
                              : "Check Out",
                          time: _formatTime(attendance.time),
                          date: _formatDate(attendance.time),
                          status: _getStatus(attendance),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // === FIXED SLIDER ===
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SlideAction(
                key: _sliderKey,
                borderRadius: 16,
                elevation: 0,
                outerColor: AppColors.primary,
                innerColor: Colors.white,
                height: 56,
                sliderButtonIcon: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.primary,
                  size: 24,
                ),
                text: !hasCheckedIn
                    ? "Swipe to Check In"
                    : "Swipe to Check Out",
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

  String _formatTime(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat("HH:mm").format(local);
  }

  String _formatDate(DateTime timestamp) {
    final local = timestamp.toLocal();
    return DateFormat("MMMM dd, yyyy").format(local);
  }

  String _getStatus(Attendance attendance) {
    if (attendance.type == 'checkin') {
      return attendance.late == true ? "Late" : "On Time";
    }
    return "On Time";
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Morning";
    if (hour < 17) return "Afternoon";
    if (hour < 19) return "Evening";
    return "Night";
  }
}

// ===== Stat Item Widget =====
class _StatItem extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int count;
  final String label;

  const _StatItem({
    required this.color,
    required this.icon,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ===== Info Card =====
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
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
      ),
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

  const ActivityItem({
    super.key,
    required this.icon,
    required this.title,
    required this.time,
    required this.date,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 12,
                    color: status == "Late" ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
