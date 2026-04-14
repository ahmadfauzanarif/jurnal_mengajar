import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Tentang Aplikasi',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/image/LogoJr.png',
              width: 250,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.school,
                size: 154,
                color: Color(0xFF345EA8),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'jurnalmengajar.id',
              style: TextStyle(
                fontSize: 18,
                color: MainColor.primaryColor,
                fontWeight: FontWeight.w500,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Versi 1 (1.1.0)',
              style: TextStyle(
                fontSize: 14,
                color: MainColor.secondaryText,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
            const SizedBox(height: 100), // Push slightly up from center bottom
          ],
        ),
      ),
    );
  }
}
