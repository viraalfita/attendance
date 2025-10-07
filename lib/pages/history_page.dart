import 'package:attendance/models/attendance.dart';
import 'package:attendance/theme/app_colors.dart';
import 'package:attendance/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../services/api_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<Attendance> _records = [];
  List<Attendance> _filteredRecords = [];
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  int _onTimeCount = 0;
  int _lateCount = 0;

  // controller untuk horizontal date list
  final ScrollController _dateScrollController = ScrollController();

  // konfigurasi
  static const int _daysToShow = 7;
  static const double _dateItemWidth = 72.0;

  @override
  void initState() {
    super.initState();
    _loadData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTodayWithRetry();
    });
  }

  @override
  void dispose() {
    _dateScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final data = await ApiService.getMyAttendance();
      setState(() {
        _records = data;
        _filteredRecords = _filterRecordsByDate(_selectedDate);
        _calculateStats();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Error loading attendance data: $e');
    }
  }

  void _calculateStats() {
    int onTime = 0;
    int late = 0;

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentRecords = _records
        .where((r) => r.time.isAfter(thirtyDaysAgo))
        .toList();

    for (var record in recentRecords) {
      if (record.type == 'checkin') {
        final checkInTime = record.time;
        final expectedTime = DateTime(
          checkInTime.year,
          checkInTime.month,
          checkInTime.day,
          8,
          0,
        );
        if (checkInTime.isAfter(
          expectedTime.add(const Duration(minutes: 15)),
        )) {
          late++;
        } else {
          onTime++;
        }
      }
    }

    setState(() {
      _onTimeCount = onTime;
      _lateCount = late;
    });
  }

  List<Attendance> _filterRecordsByDate(DateTime date) {
    return _records.where((record) {
      final recordDate = DateTime(
        record.time.year,
        record.time.month,
        record.time.day,
      );
      final filterDate = DateTime(date.year, date.month, date.day);
      return recordDate == filterDate;
    }).toList();
  }

  Future<void> _scrollToTodayWithRetry({int attempt = 0}) async {
    const int maxAttempts = 6;
    const Duration retryDelay = Duration(milliseconds: 100);

    if (!_dateScrollController.hasClients) {
      if (attempt < maxAttempts) {
        await Future.delayed(retryDelay);
        return _scrollToTodayWithRetry(attempt: attempt + 1);
      } else {
        return;
      }
    }

    final maxExtent = _dateScrollController.position.maxScrollExtent;
    final int todayIndex = _daysToShow - 1;
    final double rawOffset = todayIndex * _dateItemWidth;
    final double target = rawOffset > maxExtent ? maxExtent : rawOffset;

    if (maxExtent == 0 && attempt < maxAttempts) {
      await Future.delayed(retryDelay);
      return _scrollToTodayWithRetry(attempt: attempt + 1);
    }

    if (target <= 0) {
      _dateScrollController.jumpTo(0);
    } else {
      try {
        await _dateScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      } catch (_) {
        _dateScrollController.jumpTo(target);
      }
    }
  }

  void _onDateTap(int index, DateTime date) {
    setState(() {
      _selectedDate = date;
      _filteredRecords = _filterRecordsByDate(date);
    });

    if (!_dateScrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final double centeredOffset =
        (index * _dateItemWidth) - (screenWidth / 2 - _dateItemWidth / 2);
    final double maxExtent = _dateScrollController.position.maxScrollExtent;
    final double target = centeredOffset.clamp(0.0, maxExtent);

    _dateScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _onTimeCount + _lateCount;
    final onTimePercentage = total > 0 ? (_onTimeCount / total * 100) : 0;
    final latePercentage = total > 0 ? (_lateCount / total * 100) : 0;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: buildCustomAppBar(title: "Attendance History", centerTitle: true),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Statistics Card dengan gradient yang lebih modern
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.blue.shade300, Colors.blue.shade500],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Chart Section
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 120,
                            child: SfCircularChart(
                              margin: EdgeInsets.zero,
                              series: <CircularSeries>[
                                DoughnutSeries<ChartData, String>(
                                  dataSource: [
                                    ChartData(
                                      'On Time',
                                      _onTimeCount,
                                      Colors.green.shade400,
                                    ),
                                    ChartData(
                                      'Late',
                                      _lateCount,
                                      Colors.orange.shade400,
                                    ),
                                  ],
                                  xValueMapper: (ChartData data, _) => data.x,
                                  yValueMapper: (ChartData data, _) => data.y,
                                  pointColorMapper: (ChartData data, _) =>
                                      data.color,
                                  innerRadius: '75%',
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Statistics Info
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildStatItem(
                                "On Time",
                                "$_onTimeCount",
                                "${onTimePercentage.toStringAsFixed(1)}%",
                                Colors.green.shade400,
                              ),
                              const SizedBox(height: 12),
                              _buildStatItem(
                                "Late",
                                "$_lateCount",
                                "${latePercentage.toStringAsFixed(1)}%",
                                Colors.orange.shade400,
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  "Total: $total",
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section Title untuk Date Selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      "Select Date",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horizontal date selector yang lebih stylish
                  SizedBox(
                    height: 90,
                    child: ListView.builder(
                      controller: _dateScrollController,
                      scrollDirection: Axis.horizontal,
                      itemCount: _daysToShow,
                      itemBuilder: (context, index) {
                        final date = DateTime.now().subtract(
                          Duration(days: _daysToShow - 1 - index),
                        );
                        final isSelected =
                            date.year == _selectedDate.year &&
                            date.month == _selectedDate.month &&
                            date.day == _selectedDate.day;
                        final isToday =
                            date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;

                        return GestureDetector(
                          onTap: () => _onDateTap(index, date),
                          child: Container(
                            width: 64,
                            margin: EdgeInsets.only(
                              right: 8,
                              left: index == 0 ? 4 : 0,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.primary.withOpacity(0.8),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : isToday
                                  ? LinearGradient(
                                      colors: [
                                        Colors.blue.shade50,
                                        Colors.white,
                                      ],
                                    )
                                  : null,
                              color: isSelected || isToday
                                  ? null
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: isToday && !isSelected
                                  ? Border.all(
                                      color: AppColors.primary.withOpacity(0.3),
                                      width: 1.5,
                                    )
                                  : null,
                              boxShadow: [
                                if (!isSelected)
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.transparent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      DateFormat('dd').format(date),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: isSelected
                                            ? AppColors.primary
                                            : isToday
                                            ? AppColors.primary
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('EEE').format(date),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : isToday
                                        ? AppColors.primary
                                        : Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section Title untuk Attendance List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withOpacity(0.6),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Attendance Records",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedDate),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attendance List
                  Expanded(
                    child: _filteredRecords.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            itemCount: _filteredRecords.length,
                            itemBuilder: (context, index) {
                              final item = _filteredRecords[index];
                              final isCheckIn = item.type == "checkin";
                              final status = _getStatus(item);
                              final isLate = status == "Late";

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {},
                                    borderRadius: BorderRadius.circular(16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        children: [
                                          // Icon dengan gradient
                                          Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: isCheckIn
                                                    ? [
                                                        Colors.green.shade100,
                                                        Colors.green.shade50,
                                                      ]
                                                    : [
                                                        Colors.blue.shade100,
                                                        Colors.blue.shade50,
                                                      ],
                                              ),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isCheckIn
                                                  ? Icons.login_rounded
                                                  : Icons.logout_rounded,
                                              color: isCheckIn
                                                  ? Colors.green.shade600
                                                  : Colors.blue.shade600,
                                              size: 22,
                                            ),
                                          ),
                                          const SizedBox(width: 16),

                                          // Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isCheckIn
                                                      ? "Check In"
                                                      : "Check Out",
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  DateFormat('HH:mm').format(
                                                    item.time.toUtc().add(
                                                      const Duration(hours: 7),
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Status Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isLate
                                                  ? Colors.orange.shade50
                                                  : Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                              border: Border.all(
                                                color: isLate
                                                    ? Colors.orange.shade200
                                                    : Colors.green.shade200,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isLate
                                                      ? Icons.schedule
                                                      : Icons.check_circle,
                                                  size: 14,
                                                  color: isLate
                                                      ? Colors.orange.shade600
                                                      : Colors.green.shade600,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isLate
                                                        ? Colors.orange.shade600
                                                        : Colors.green.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(
    String title,
    String count,
    String percentage,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              percentage,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.grey.shade100, Colors.grey.shade50],
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today,
              size: 48,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "No Records Found",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "No attendance records for the selected date",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  String _getStatus(Attendance attendance) {
    if (attendance.type == 'checkin') {
      final checkInTime = attendance.time;
      final expectedTime = DateTime(
        checkInTime.year,
        checkInTime.month,
        checkInTime.day,
        8,
        0,
      );
      if (checkInTime.isAfter(expectedTime.add(const Duration(minutes: 15)))) {
        return "Late";
      }
    }
    return "On Time";
  }
}

class ChartData {
  final String x;
  final int y;
  final Color color;
  ChartData(this.x, this.y, this.color);
}
