import 'dart:convert';
import 'package:http/http.dart' as http;

class OTPService {
  final String apiKey = "b53477c2821c1bf0da5d40e57b870d35";

  Future<String> sendOTP(String phone, String otp) async {
    final url = Uri.parse("https://sms.renflair.in/V1.php");
    final response = await http.get(url.replace(queryParameters: {
      "API": apiKey,
      "PHONE": phone,
      "OTP": otp,
    }));

    if (response.statusCode == 200) {
      var data = jsonDecode(response.body);
      if (data['status'] == "success") {
        return "OTP sent successfully!";
      } else {
        return "Error: ${data['message']}";
      }
    } else {
      return "Failed to send OTP!";
    }
  }
}
