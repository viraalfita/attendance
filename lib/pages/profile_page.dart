import 'package:attendance/pages/login_page.dart';
import 'package:attendance/services/api_service.dart';
import 'package:attendance/theme/app_colors.dart';
import 'package:attendance/widgets/app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
// OPSIONAL: aktifkan kalau mau tombol "Open in Maps"
import 'package:url_launcher/url_launcher.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _username = "";
  final String _password = "********";

  // Company fields
  String _companyName = "-";
  String _companyCode = "-";
  String _companyAddress = "-";
  String _companyTimezone = "-";
  String _workHourRange = "-";
  double? _lat;
  double? _lng;
  int? _radius;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([_loadProfile(), _loadCompany()]);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _username = (prefs.getString("username") ?? "Unknown");
    });
  }

  Future<void> _loadCompany() async {
    try {
      final data = await ApiService.getCompanyProfile();
      if (data.isEmpty) return;

      final name = (data['name'] ?? '-') as String;
      final code = (data['companyCode'] ?? '-') as String;
      final address = (data['address'] ?? '-') as String;
      final tz = (data['timezone'] ?? '-') as String;

      // timeStart/timeEnd bisa ISO (contoh yang kamu pakai)
      final timeStart = data['timeStart'] ?? data['time_start'];
      final timeEnd = data['timeEnd'] ?? data['time_end'];

      final range = _formatWorkHoursToLocal(timeStart, timeEnd);

      final loc = data['location'] as Map<String, dynamic>?;

      setState(() {
        _companyName = name;
        _companyCode = code;
        _companyAddress = address;
        _companyTimezone = tz;
        _workHourRange = range;

        if (loc != null) {
          _lat = (loc['latitude'] as num?)?.toDouble();
          _lng = (loc['longitude'] as num?)?.toDouble();
          _radius = (loc['radius'] as num?)?.toInt();
        }
      });
    } catch (e) {
      debugPrint('[ProfilePage] _loadCompany error: $e');
    }
  }

  String _formatWorkHoursToLocal(dynamic start, dynamic end) {
    final s = _formatOneToLocal(start);
    final e = _formatOneToLocal(end);
    if (s == '-' && e == '-') return '-';
    return '$s - $e';
    // Contoh: "20:00 - 20:15" (kalau device timezone = UTC+7)
  }

  /// Menerima:
  /// - ISO datetime (contoh: "2025-09-28T13:00:00.493Z") -> toLocal() -> "HH:mm"
  /// - "HH:mm" -> tampilkan apa adanya
  /// - null/invalid -> "-"
  String _formatOneToLocal(dynamic v) {
    if (v == null) return '-';
    if (v is String && v.isNotEmpty) {
      // Deteksi sederhana ISO
      if (v.contains('T')) {
        try {
          final dt = DateTime.parse(v).toLocal();
          return DateFormat('HH:mm').format(dt);
        } catch (_) {
          return '-';
        }
      }
      // Kalau bukan ISO dan ada ':', anggap "HH:mm"
      if (v.contains(':')) return v;
    }
    return '-';
  }

  Future<void> _showLogoutDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
            side: BorderSide(color: Colors.grey.shade300, width: 0.5),
          ),
          title: const Text(
            "Logout",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text("Are you sure you want to logout?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () async {
                await ApiService.logout();
                if (!mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              child: const Text("Logout", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openInMaps() async {
    final uri = Uri.parse('https://www.google.com/maps?q=$_lat,$_lng');
    final ok = await canLaunchUrl(uri);
    if (!ok) {}
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open Maps')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildCustomAppBar(title: "Profile", centerTitle: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // ===== Account Card =====
                  _SectionCard(
                    title: "Account Information",
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar kecil di sisi kiri
                          Container(
                            margin: const EdgeInsets.only(right: 16),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary,
                                width: 1.0,
                              ),
                            ),
                            child: const CircleAvatar(
                              radius: 28, // kecil
                              backgroundImage: AssetImage(
                                "assets/att_avatar.png",
                              ),
                            ),
                          ),

                          // Detail akun
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _InfoTile(
                                  icon: Icons.person,
                                  label: "Username",
                                  value: _username,
                                  trailing: IconButton(
                                    icon: const Icon(Icons.copy, size: 18),
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: _username),
                                      );
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text("Username copied"),
                                          duration: Duration(milliseconds: 800),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _InfoTile(
                                  icon: Icons.lock,
                                  label: "Password",
                                  value: _password,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Company Card =====
                  _SectionCard(
                    title: "Company Information",
                    accent: AppColors.primary,
                    children: [
                      _InfoTile(
                        icon: Icons.apartment,
                        label: "Company",
                        value: _companyName,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.qr_code_2,
                        label: "Company Code",
                        value: _companyCode,
                        trailing: IconButton(
                          icon: const Icon(Icons.copy, size: 18),
                          onPressed: () {
                            Clipboard.setData(
                              ClipboardData(text: _companyCode),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Company code copied"),
                                duration: Duration(milliseconds: 800),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.location_on_outlined,
                        label: "Address",
                        value: _companyAddress,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.schedule,
                        label: "Working Hours",
                        value: _workHourRange, // dari ISO -> local HH:mm
                      ),
                      const SizedBox(height: 12),
                      _InfoTile(
                        icon: Icons.public,
                        label: "Timezone",
                        value: _companyTimezone == '-'
                            ? 'Device Local Time'
                            : _companyTimezone,
                      ),
                      if (_radius != null || _lat != null) ...[
                        const SizedBox(height: 12),
                        _InfoTile(
                          icon: Icons.safety_divider,
                          label: "Geofence",
                          value:
                              "${_radius ?? '-'} m • ${_lat?.toStringAsFixed(6) ?? '-'}, ${_lng?.toStringAsFixed(6) ?? '-'}",
                          trailing: (_lat != null && _lng != null)
                              ? TextButton.icon(
                                  onPressed: _openInMaps,
                                  icon: const Icon(Icons.map, size: 18),
                                  label: const Text("Open in Maps"),
                                )
                              : null,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  // ===== Logout Button =====
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showLogoutDialog,
                      icon: const Icon(Icons.logout),
                      label: const Text(
                        "Logout",
                        style: TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/* ================== Reusable UI widgets ================== */

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Color? accent;
  const _SectionCard({
    required this.title,
    required this.children,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(
          color: (accent ?? AppColors.primary).withOpacity(0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent ?? AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 1,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
