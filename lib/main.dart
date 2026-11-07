import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'audio/sfx.dart';
import 'core/settings.dart';
import 'push/push.dart';
import 'ui/menu_page.dart';
import 'ui/online_page.dart';
import 'ui/profile_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  final st = await Settings.load();
  Sfx.i.enabled = st.sound;
  Push.myDid = st.deviceId;
  Push.onInvite = (room) {
    if (!st.profileDone) return;
    if (Push.online > 0) {
      Push.toast('أنت داخل أونلاين حالياً، اطلع أول ثم اضغط الإشعار');
      return;
    }
    Push.navKey.currentState?.push(MaterialPageRoute(builder: (_) => OnlinePage(st: st, autoJoin: room)));
  };
  runApp(DominoApp(st: st));
  Push.init(); // بعد فتح اللعبة حتى لا يؤخرها
}

class DominoApp extends StatelessWidget {
  final Settings st;
  const DominoApp({super.key, required this.st});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: Push.messenger,
      navigatorKey: Push.navKey,
      title: 'Iraqe Domeno',
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kGold, brightness: Brightness.dark),
      ),
      builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
      home: st.profileDone ? MenuPage(st: st) : ProfilePage(st: st, first: true),
    );
  }
}
