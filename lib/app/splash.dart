import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MainColor.primaryColorLight,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              MainColor.primaryColorLight,
              MainColor.secondaryBackground,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo section
            Image.asset(
              'assets/image/logoApp.png',
              width: 200,
              fit: BoxFit.contain,
            ), // App Name
            Text(
              'Jurnal Mengajar',
              style: TextStyle(
                fontSize: 28,
                fontFamily: GoogleFonts.poppins().fontFamily,
                fontWeight: FontWeight.w800,
                color: MainColor.primaryColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            // Tagline or secondary text
            Text(
              'Pelatihan Mobile Apps KPTK 2026 Angkatan 1',
              style: TextStyle(
                fontSize: 14,
                fontFamily: GoogleFonts.poppins().fontFamily,
                color: MainColor.secondaryText,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),
            // Loading indicator at the bottom
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(MainColor.primaryColor),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
