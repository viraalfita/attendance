import 'package:attendance/widgets/app_bar.dart';
import 'package:flutter/material.dart';

import '../models/leave.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';

class LeavesPage extends StatefulWidget {
  const LeavesPage({super.key});

  @override
  State<LeavesPage> createState() => _LeavesPageState();
}

class _LeavesPageState extends State<LeavesPage> {
  List<Leave> _leaves = [];

  @override
  void initState() {
    super.initState();
    _loadLeaves();
  }

  Future<void> _loadLeaves() async {
    final data = await ApiService.getMyLeaves();
    setState(() {
      _leaves = data;
    });
  }

  Future<void> _showLeaveForm() async {
    final reasonController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
          title: const Text(
            "Request Leave",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reason TextField
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    labelText: "Reason",
                    labelStyle: const TextStyle(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.background,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 0.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.secondary,
                        width: 2,
                      ),
                    ),
                  ),
                  maxLines: 2,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 16),

                // Start Date Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => startDate = picked);
                    }
                  },
                  icon: const Icon(
                    Icons.calendar_today,
                    color: AppColors.primary,
                  ),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      startDate != null
                          ? "Start Date: ${startDate!.toLocal().toString().split(' ')[0]}"
                          : "Pick Start Date",
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.background,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 12),

                // End Date Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() => endDate = picked);
                    }
                  },
                  icon: const Icon(
                    Icons.calendar_month,
                    color: AppColors.primary,
                  ),
                  label: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      endDate != null
                          ? "End Date: ${endDate!.toLocal().toString().split(' ')[0]}"
                          : "Pick End Date",
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300, width: 0.5),
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: AppColors.background,
                    alignment: Alignment.centerLeft,
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ),
          actions: [
            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),

            // Submit button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                if (reasonController.text.isNotEmpty &&
                    startDate != null &&
                    endDate != null) {
                  final success = await ApiService.requestLeave(
                    reasonController.text,
                    startDate!,
                    endDate!,
                  );
                  if (success) {
                    Navigator.pop(context);
                    _loadLeaves();
                  }
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final approved = _leaves.where((l) => l.status == "approved").length;
    final pending = _leaves.where((l) => l.status == "waiting").length;
    final declined = _leaves.where((l) => l.status == "declined").length;

    return Scaffold(
      appBar: buildCustomAppBar(
        title: "All Leaves",
        centerTitle: false,
        titleSpacing: 8,
        action: IconButton(
          onPressed: _showLeaveForm,
          icon: const Icon(Icons.add_circle, size: 24, color: Colors.blue),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 🔹 Summary Cards lebih kecil
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: _summaryCard("Approved", approved, Colors.green),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryCard("Pending", pending, Colors.orange),
                ),
                const SizedBox(width: 8),
                Expanded(child: _summaryCard("Declined", declined, Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            // 🔹 List leaves compact
            Expanded(
              child: _leaves.isEmpty
                  ? const Center(child: Text("No leave requests yet"))
                  : ListView.builder(
                      itemCount: _leaves.length,
                      itemBuilder: (context, index) {
                        final leave = _leaves[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      leave.reason,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "${leave.startDate.toLocal().toString().split(' ')[0]} - ${leave.endDate.toLocal().toString().split(' ')[0]}",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // status
                              Text(
                                leave.status.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: leave.status == "approved"
                                      ? Colors.green
                                      : leave.status == "declined"
                                      ? Colors.red
                                      : Colors.orange,
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

  Widget _summaryCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      height: 80,
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
          const Spacer(),
          Text(
            "$count",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
