import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/login.dart';
import 'package:jurnal_mengajar/app/splash.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: 'https://xfucaxclnsugqmtbqdqj.supabase.co',
    anonKey: 'sb_publishable_k-hHcizY39DUjnGhJPFyzw_YOk6ghLW',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jurnal Mengajar',
      theme: ThemeData(
        useMaterial3: true,
        primaryColor: MainColor.primaryColor,
      ),
      home: FutureBuilder(
        future: Future.wait([
          Future.delayed(const Duration(seconds: 3)),
          // You can also add more initialization logic here
        ]),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SplashScreen();
          } else {
            Session? session;
            try {
              session = Supabase.instance.client.auth.currentSession;
            } catch (e) {
              // Handle error if somehow not initialized
            }

            if (session != null) {
              // User is already logged in
              return const Login(); 
            } else {
              return const Login();
            }
          }
        },
      ),
    );
  }
}
