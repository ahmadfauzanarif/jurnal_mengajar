import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:jurnal_mengajar/app/about_page.dart';
import 'package:jurnal_mengajar/app/dashboard_guru.dart';
import 'package:jurnal_mengajar/app/jadwal_mengajar_guru_page.dart';
import 'package:jurnal_mengajar/app/jurnal_mengajar_guru_page.dart';

class DrawerGuru extends StatelessWidget {
  const DrawerGuru({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.white),
            child: Center(
              child: Image.asset(
                'assets/image/LogoJr.png',
                width: 150,
                errorBuilder: (context, error, stackTrace) =>
                    const Text('Logo'),
              ),
            ),
          ),
          const Divider(),
          _buildMenuItem(Icons.dashboard, 'Dashboard', onTap: () {
            Get.back();
            Get.offAll(() => const DashboardGuru());
          }),
          _buildMenuItem(Icons.event_note, 'Jadwal Mengajar', onTap: () {
            Get.back();
            Get.to(() => const JadwalMengajarGuruPage());
          }),
          _buildMenuItem(
            Icons.library_books_outlined,
            'Jurnal Mengajar',
            onTap: () {
              Get.back();
              Get.to(() => const JurnalMengajarGuruPage());
            },
          ),
          _buildMenuItem(
            Icons.help_outline,
            'Tentang Aplikasi',
            onTap: () {
              Get.back(); // close drawer
              Get.to(() => const AboutPage());
            },
          ),
          const Divider(),
          _buildMenuItem(
            Icons.exit_to_app,
            'Keluar',
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              Get.offAll(() => const Login());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String title, {
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: MainColor.secondaryText),
      title: Text(
        title,
        style: TextStyle(
          color: MainColor.primaryText,
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
