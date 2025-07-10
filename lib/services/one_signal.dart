import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class OneSignalApiKeys {
  static const String appId = '6ebc33e0-21f7-4380-867f-9a6c8c9220e9';
  static const String oneSignalId =
      'os_v2_app_n26dhybb65bybbt7tjwizera5fllwdlgaz2eaiec67i7a2tiw74qyhmtuqyhngu572tiwztiw4p6mzggpcbs4cxjrwy7fhfxcaavrpy';
}

class NotificationService {
  String url = "https://api.onesignal.com/notifications";

  Future<void> sendNotificationToAllUsers(
    String title,
    String description,
    String? imageUrl,
  ) async {
    try {
      final userCollection = FirebaseFirestore.instance.collection('user');
      final querySnapshot = await userCollection.get();
      List<String> playerIds = [];

      for (var doc in querySnapshot.docs) {
        var data = doc.data();
        if (data['onId'] != null && data['onId'] is List) {
          playerIds.addAll(List<String>.from(data['onId']));
        } else if (data['onId'] != null && data['onId'] is String) {
          playerIds.add(data['onId']);
        }
      }

      if (playerIds.isNotEmpty) {
        final notificationPayload = {
          "app_id": OneSignalApiKeys.appId,
          "contents": {"en": description},
          "headings": {"en": title},
          "include_player_ids": playerIds,
        };
        if (imageUrl != null) {
          notificationPayload["big_picture"] = imageUrl;
          notificationPayload["ios_attachments"] = {"image": imageUrl};
        }

        var response = await http.post(
          Uri.parse(url),
          headers: {
            "Content-Type": "application/json",
            "Authorization": "Basic ${OneSignalApiKeys.oneSignalId}",
          },
          body: jsonEncode(notificationPayload),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          print("Notification sent successfully to all users.");
        } else {
          print("Failed to send notification: ${response.body}");
        }
      } else {
        print("No valid playerIds found.");
      }
    } on Exception catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> sentNotificationtoUser(
      {required String title,
      required String description,
      required List<String> onIds}) async {
    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Basic ${OneSignalApiKeys.oneSignalId}',
        },
        body: jsonEncode({
          'app_id': OneSignalApiKeys.appId,
          'include_player_ids': onIds,
          'headings': {'en': title},
          'contents': {'en': description},
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("Notification sent successfully.");
      } else {
        print("Failed to send notification: ${response.body}");
      }
    } on Exception catch (e) {
      print("Error sending notification: $e");
    }
  }

  Future<void> sendOtpNotificationToUser({
    required String title,
    required String otp,
    required String playerId,
  }) async {
    try {
      final url = Uri.parse('https://onesignal.com/api/v1/notifications');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Basic ${OneSignalApiKeys.oneSignalId}',
        },
        body: jsonEncode({
          'app_id': OneSignalApiKeys.appId,
          'include_player_ids': [playerId],
          'headings': {'en': title},
          'contents': {'en': 'Your OTP is $otp'},
        }),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print("OTP notification sent successfully.");
      } else {
        print("Failed to send OTP notification: ${response.body}");
      }
    } on Exception catch (e) {
      print("Error sending OTP notification: $e");
    }
  }
}