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
  static const int _daysToShow = 7; // ubah sesuai kebutuhan
  static const double _dateItemWidth =
      68.0; // lebar item + margin kanan (60 + 8)

  @override
  void initState() {
    super.initState();
    _loadData();

    // setelah frame selesai, coba scroll ke posisi hari ini.
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

  // coba scroll ke "today" dengan retry singkat kalau maxScrollExtent belum siap
  Future<void> _scrollToTodayWithRetry({int attempt = 0}) async {
    // batas retry untuk menghindari loop tak berujung
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
    // index hari ini = last item
    final int todayIndex = _daysToShow - 1;
    final double rawOffset = todayIndex * _dateItemWidth;
    final double target = rawOffset > maxExtent ? maxExtent : rawOffset;

    // kalau maxExtent masih 0, coba lagi beberapa kali
    if (maxExtent == 0 && attempt < maxAttempts) {
      await Future.delayed(retryDelay);
      return _scrollToTodayWithRetry(attempt: attempt + 1);
    }

    // lakukan animate/jump
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
        // fallback ke jumpTo kalau animateTo gagal
        _dateScrollController.jumpTo(target);
      }
    }
  }

  // saat user tap tanggal, kita center-kan item tersebut untuk UX lebih baik
  void _onDateTap(int index, DateTime date) {
    setState(() {
      _selectedDate = date;
      _filteredRecords = _filterRecordsByDate(date);
    });

    // center target index
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

    return Scaffold(
      appBar: buildCustomAppBar(title: "Attendance History", centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Donut Chart
                  Card(
                    color: AppColors.selectedBg,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: AppColors.primary, width: 0.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 150,
                              child: SfCircularChart(
                                series: <CircularSeries>[
                                  DoughnutSeries<ChartData, String>(
                                    dataSource: [
                                      ChartData(
                                        'On Time',
                                        _onTimeCount,
                                        Colors.green,
                                      ),
                                      ChartData('Late', _lateCount, Colors.red),
                                    ],
                                    xValueMapper: (ChartData data, _) => data.x,
                                    yValueMapper: (ChartData data, _) => data.y,
                                    pointColorMapper: (ChartData data, _) =>
                                        data.color,
                                    innerRadius: '70%',
                                    dataLabelSettings: const DataLabelSettings(
                                      isVisible: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _legendItem(
                                  Colors.green,
                                  'On Time',
                                  _onTimeCount,
                                ),
                                const SizedBox(height: 8),
                                _legendItem(Colors.red, 'Late', _lateCount),
                                const SizedBox(height: 8),
                                _legendItem(Colors.grey, 'Total', total),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Horizontal date selector
                  SizedBox(
                    height: 80,
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

                        return GestureDetector(
                          onTap: () => _onDateTap(index, date),
                          child: Container(
                            width: 60,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.blue : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat('dd').format(date),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('EEE').format(date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Attendance List
                  Expanded(
                    child: _filteredRecords.isEmpty
                        ? const Expanded(
                            child: Text(
                              "No attendance records for the selected date.",
                              style: TextStyle(fontSize: 12),
                              textAlign: TextAlign.center,
                              selectionColor: Colors.grey,
                            ),
                          )
                        : ListView.builder(
                            itemCount: _filteredRecords.length,
                            itemBuilder: (context, index) {
                              final item = _filteredRecords[index];
                              final isCheckIn = item.type == "checkin";
                              final status = _getStatus(item);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withOpacity(0.1),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isCheckIn
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.blue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCheckIn ? Icons.login : Icons.logout,
                                        color: isCheckIn
                                            ? Colors.green
                                            : Colors.blue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
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
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: status == "Late"
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    ),
                                  ],
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

  Widget _legendItem(Color color, String text, int count) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$text: $count', style: const TextStyle(fontSize: 12)),
      ],
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
