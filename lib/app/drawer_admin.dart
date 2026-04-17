import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/login.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jurnal_mengajar/app/master_periode_page.dart';
import 'package:jurnal_mengajar/app/master_siswa_page.dart';
import 'package:jurnal_mengajar/app/master_guru_page.dart';
import 'package:jurnal_mengajar/app/about_page.dart';
import 'package:jurnal_mengajar/app/master_mapel_page.dart';
import 'package:jurnal_mengajar/app/master_kelas_page.dart';
import 'package:jurnal_mengajar/app/master_jam_page.dart';
import 'package:jurnal_mengajar/app/pengaturan_page.dart';
import 'package:jurnal_mengajar/app/jadwal_mengajar_admin_page.dart';
import 'package:jurnal_mengajar/app/jurnal_mengajar_admin_page.dart';

class DrawerAdmin extends StatelessWidget {
  const DrawerAdmin({super.key});

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
          _buildMenuItem(Icons.dashboard, 'Dashboard', onTap: () {}),
          _buildMenuItem(
            Icons.check_circle_outline,
            'Jurnal Mengajar',
            onTap: () {
              Get.back(); // close drawer
              Get.to(() => const JurnalMengajarAdminPage());
            },
          ),
          _buildMenuItem(Icons.event_note, 'Jadwal Mengajar', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const JadwalMengajarAdminPage());
          }),
          _buildMenuItem(Icons.settings, 'Pengaturan', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const PengaturanPage());
          }),
          _buildMenuItem(Icons.help_outline, 'Tentang Aplikasi', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const AboutPage());
          }),

          Padding(
            padding: const EdgeInsets.only(left: 16, top: 24, bottom: 8),
            child: Text(
              'Master Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: MainColor.primaryText,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
          ),
          _buildMenuItem(Icons.label_outline, 'Periode', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const MasterPeriodePage());
          }),
          _buildMenuItem(Icons.access_time, 'Jam Pelajaran', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const MasterJamPage());
          }),
          _buildMenuItem(Icons.home_outlined, 'Kelas', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const MasterKelasPage());
          }),
          _buildMenuItem(Icons.book_outlined, 'Mata Pelajaran', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const MasterMapelPage());
          }),
          _buildMenuItem(Icons.person_outline, 'Siswa', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const MasterSiswaPage());
          }),
          _buildMenuItem(Icons.school_outlined, 'Guru', onTap: () {
            Get.back(); // close drawer
            Get.to(() => const MasterGuruPage());
          }),
          const Divider(),
          _buildMenuItem(
            Icons.exit_to_app,
            'Keluar',
            onTap: () async {
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.clear();
              await Supabase.instance.client.auth.signOut();
              Get.deleteAll(force: true); // Reset state controller saat logout
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
