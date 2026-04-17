import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/login.dart';
import 'package:jurnal_mengajar/app/splash.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnal_mengajar/app/dashboard_admin.dart';
import 'package:jurnal_mengajar/app/dashboard_guru.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Muat file .env terlebih dahulu
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  await initializeDateFormatting('id_ID', null);
  Intl.defaultLocale = 'id_ID';

  // Tangkap deep link OAuth saat app sudah berjalan (foreground/background)
  _initDeepLinkListener();

  runApp(const MyApp());
}

/// Mendengarkan deep link masuk dari OAuth callback Google
void _initDeepLinkListener() {
  final appLinks = AppLinks();
  final supabase = Supabase.instance.client;

  Future<void> handleUri(Uri uri) async {
    if (uri.toString().contains('login-callback')) {
      try {
        debugPrint('Deep link diterima: $uri');
        await supabase.auth.getSessionFromUrl(uri);
        debugPrint('Session berhasil diambil dari deep link');
      } catch (e) {
        debugPrint('Deep link error: $e');
      }
    }
  }

  // Cek initial link (ketika app di-resume dari background via deep link)
  appLinks.getInitialLink().then((uri) {
    if (uri != null) handleUri(uri);
  }).catchError((e) => debugPrint('getInitialLink error: $e'));

  // Listen untuk deep link yang datang saat app aktif
  appLinks.uriLinkStream.listen(
    (uri) => handleUri(uri),
    onError: (e) => debugPrint('uriLinkStream error: $e'),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _getInitialScreen() async {
    await Future.delayed(const Duration(seconds: 3));

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? role = prefs.getString('role');

      if (role == 'admin') {
        return const DashboardAdmin();
      } else if (role == 'guru') {
        return const DashboardGuru();
      }
    }
    return const Login();
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jurnal Mengajar',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: MainColor.primaryColor,
      ),
      home: FutureBuilder<Widget>(
        future: _getInitialScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          } else {
            return snapshot.data ?? const Login();
          }
        },
      ),
    );
  }
}
