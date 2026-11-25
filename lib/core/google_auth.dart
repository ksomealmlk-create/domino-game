import 'package:google_sign_in/google_sign_in.dart';

/// تسجيل الدخول بجوجل (يرجع توكن يتحقق منه السيرفر، ما نخزن كلمة سر ولا نشوفها).
class GoogleAuth {
  static const webClientId = '156665803904-2p7ssql8ishe43udrh7k6h05g730baj3.apps.googleusercontent.com';
  static final GoogleSignIn _gs = GoogleSignIn(scopes: const ['email'], serverClientId: webClientId);

  /// يرجع idToken، أو null إذا اللاعب لغى.
  static Future<String?> idToken() async {
    try {
      await _gs.signOut(); // حتى تطلع له قائمة اختيار الحساب كل مرة
    } catch (_) {}
    final acc = await _gs.signIn();
    if (acc == null) return null;
    final auth = await acc.authentication;
    return auth.idToken;
  }
}
