// ApiService.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/attendance.dart';
import '../models/leave.dart';

class ApiService {
  static const String baseUrl =
      "http://localhost:5001/api"; // Android emulator; sesuaikan
  static String? token;
  static String? userId;
  static String? companyCode;
  static String? deviceTimezone; // <-- cache TZ

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString("token");
    userId = prefs.getString("userId");
    companyCode = prefs.getString("companyCode");

    // Ambil & cache timezone device bila belum ada
    deviceTimezone ??= await _getLocalTimezoneSafe();
  }

  static Future<String?> _getLocalTimezoneSafe() async {
    try {
      return await FlutterNativeTimezone.getLocalTimezone(); // contoh: "Asia/Jakarta"
    } catch (e) {
      debugPrint('[ApiService] getLocalTimezone error: $e');
      return null;
    }
  }

  static Future<bool> register(
    String username,
    String password,
    String companyCodeParam,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/users/register/employee"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
        "companyCode": companyCodeParam,
      }),
    );
    return res.statusCode == 201;
  }

  static Future<bool> login(
    String username,
    String password,
    String companyCodeParam,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/users/login"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "username": username,
        "password": password,
        "companyCode": companyCodeParam,
      }),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      token = data["token"];
      try {
        final payload = JwtDecoder.decode(token!);
        userId = payload["id"] as String?;

        if (userId == null) return false;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("username", username);
        await prefs.setString("token", token!);
        await prefs.setString("userId", userId!);
        await prefs.setString("companyCode", companyCodeParam);

        // cache timezone
        deviceTimezone = await _getLocalTimezoneSafe();
        if (deviceTimezone != null) {
          await prefs.setString("deviceTimezone", deviceTimezone!);
        }

        companyCode = companyCodeParam;
        return true;
      } catch (e) {
        debugPrint('Error decoding token: $e');
        return false;
      }
    }
    return false;
  }

  static Future<Map<String, String>> getCompanyHours() async {
    if (companyCode == null || token == null) {
      await loadSession();
      if (companyCode == null || token == null) return {};
    }

    final url = Uri.parse("$baseUrl/companies/hours/$companyCode");
    final res = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final start = (data['time_start'] ?? data['timeStart'] ?? '').toString();
      final end = (data['time_end'] ?? data['timeEnd'] ?? '').toString();
      return {'time_start': start, 'time_end': end};
    }
    return {};
  }

  static Future<List<Attendance>> getAttendanceByUser() async {
    if (userId == null) return [];
    final res = await http.get(
      Uri.parse("$baseUrl/attendance/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Attendance.fromJson(e)).toList();
    }
    return [];
  }

  static Future<List<Attendance>> getMyAttendance() async =>
      getAttendanceByUser();

  static Future<List<Attendance>> getAttendanceByDay() async {
    if (userId == null) return [];
    final res = await http.get(
      Uri.parse("$baseUrl/attendance/today/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Attendance.fromJson(e)).toList();
    }
    return [];
  }

  // === Kirim timezone device di check-in / check-out ===
  static Future<bool> checkIn(double lat, double lng) async {
    if (userId == null) return false;
    deviceTimezone ??= await _getLocalTimezoneSafe();

    final res = await http.post(
      Uri.parse("$baseUrl/attendance/checkin"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "userId": userId,
        "latitude": lat,
        "longitude": lng,
        "clientTimezone": deviceTimezone, // <--- penting
      }),
    );
    debugPrint("[checkIn] ${res.statusCode} ${res.body}");
    return res.statusCode == 201;
  }

  static Future<bool> checkOut(double lat, double lng) async {
    if (userId == null) return false;
    deviceTimezone ??= await _getLocalTimezoneSafe();

    final res = await http.post(
      Uri.parse("$baseUrl/attendance/checkout"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "userId": userId,
        "latitude": lat,
        "longitude": lng,
        "clientTimezone": deviceTimezone, // <--- penting
      }),
    );
    debugPrint("[checkOut] ${res.statusCode} ${res.body}");
    return res.statusCode == 201;
  }

  static Future<bool> requestLeave(
    String reason,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (userId == null) return false;
    final res = await http.post(
      Uri.parse("$baseUrl/leaves"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode({
        "userId": userId,
        "reason": reason,
        "startDate": startDate.toIso8601String(),
        "endDate": endDate.toIso8601String(),
      }),
    );
    return res.statusCode == 201;
  }

  static Future<List<Leave>> getMyLeaves() async {
    if (userId == null) return [];
    final res = await http.get(
      Uri.parse("$baseUrl/leaves/$userId"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => Leave.fromJson(e)).toList();
    }
    return [];
  }

  static Future<Map<String, dynamic>> getCompanyProfile() async {
    if (companyCode == null || token == null) {
      await loadSession();
      if (companyCode == null || token == null) return {};
    }

    final url = Uri.parse("$baseUrl/companies/$companyCode");
    final res = await http.get(
      url,
      headers: {
        "Authorization": "Bearer $token",
        "Content-Type": "application/json",
      },
    );
    debugPrint('[getCompanyProfile] ${res.statusCode} ${res.body}');
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    }
    return {};
  }

  static Future<void> logout() async {
    token = null;
    userId = null;
    deviceTimezone = null;
  }
}
