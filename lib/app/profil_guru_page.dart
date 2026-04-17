import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jurnal_mengajar/app/edit_profil_guru_page.dart';

class ProfilGuruController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = true.obs;
  var profile = {}.obs;

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isLoading.value = true;
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profileRes = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        profile.value = profileRes;
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat profil: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class ProfilGuruPage extends StatelessWidget {
  const ProfilGuruPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ProfilGuruController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Get.to(() => const EditProfilGuruPage())?.then((_) {
                 final controller = Get.find<ProfilGuruController>();
                 controller.fetchProfile();
              });
            },
          )
        ],
        elevation: 0,
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final prof = controller.profile.value;
        String nama = prof['nama_lengkap'] ?? 'Nama Lengkap';
        String jabatan = prof['jabatan'] ?? 'Guru';
        String? fotoUrl = prof['foto_url'];
        String alamat = prof['alamat'] ?? '-';
        String noTelp = prof['no_telp'] ?? '-';
        String email = supabaseEmail() ?? '-';

        return Column(
          children: [
            Container(
              width: double.infinity,
              color: MainColor.primaryColor,
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: fotoUrl != null ? NetworkImage(fotoUrl) : null,
                    child: fotoUrl == null
                        ? Icon(Icons.person, size: 50, color: MainColor.primaryColor)
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    nama,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    jabatan,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildProfileItem(Icons.location_on, 'Alamat', alamat),
                    const Divider(),
                    _buildProfileItem(Icons.phone, 'No Telp', noTelp),
                    const Divider(),
                    _buildProfileItem(Icons.email, 'Email', email),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MainColor.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () {
                          Get.to(() => const EditProfilGuruPage())?.then((_) {
                             final controller = Get.find<ProfilGuruController>();
                             controller.fetchProfile();
                          });
                        },
                        child: Text(
                          'Edit Profile',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  String? supabaseEmail() {
    return Supabase.instance.client.auth.currentUser?.email;
  }

  Widget _buildProfileItem(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black87),
          const SizedBox(width: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: MainColor.primaryColor,
              fontWeight: FontWeight.w500,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
