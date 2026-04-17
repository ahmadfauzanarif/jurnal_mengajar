import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/dashboard_guru.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterGoogleController extends GetxController {
  final supabase = Supabase.instance.client;

  var isLoading = false.obs;
  var profileImage = Rxn<dynamic>(); // File on mobile, Uint8List on web

  final namaController = TextEditingController();
  final jabatanController = TextEditingController();
  final alamatController = TextEditingController();
  final noTelpController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    // Pre-fill nama dari Google metadata jika tersedia
    final user = supabase.auth.currentUser;
    if (user != null) {
      final fullName = user.userMetadata?['full_name'] ?? '';
      namaController.text = fullName;
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 70,
    );
    if (pickedFile != null) {
      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        profileImage.value = bytes;
      } else {
        profileImage.value = File(pickedFile.path);
      }
    }
  }

  Future<void> simpan() async {
    if (namaController.text.isEmpty ||
        jabatanController.text.isEmpty ||
        alamatController.text.isEmpty ||
        noTelpController.text.isEmpty) {
      Get.snackbar('Error', 'Semua field harus diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (profileImage.value == null) {
      Get.snackbar('Peringatan', 'Silakan pilih foto profil terlebih dahulu',
          backgroundColor: Colors.orange, colorText: Colors.white);
      return;
    }

    isLoading.value = true;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('Sesi tidak ditemukan');

      String? photoUrl;

      // Upload foto profil
      final fileName =
          'profil_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (kIsWeb) {
        final bytes = profileImage.value as Uint8List;
        await supabase.storage.from('profil').uploadBinary(fileName, bytes);
      } else {
        final file = profileImage.value as File;
        await supabase.storage.from('profil').upload(fileName, file);
      }
      photoUrl = supabase.storage.from('profil').getPublicUrl(fileName);

      // Upsert profil guru
      await supabase.from('profiles').upsert({
        'id': user.id,
        'nama_lengkap': namaController.text.trim(),
        'jabatan': jabatanController.text.trim(),
        'alamat': alamatController.text.trim(),
        'no_telp': noTelpController.text.trim(),
        'foto_url': photoUrl,
        'email': user.email,
        'role': 'guru',
      });

      // Simpan session ke SharedPreferences
      final session = supabase.auth.currentSession;
      if (session != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', session.accessToken);
        await prefs.setString('role', 'guru');
      }

      Get.offAll(() => const DashboardGuru());
      Get.snackbar('Sukses', 'Profil berhasil disimpan!',
          backgroundColor: Colors.green, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', 'Terjadi kesalahan: $e',
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    namaController.dispose();
    jabatanController.dispose();
    alamatController.dispose();
    noTelpController.dispose();
    super.onClose();
  }
}

class RegisterGooglePage extends StatelessWidget {
  const RegisterGooglePage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RegisterGoogleController());

    return Scaffold(
      backgroundColor: MainColor.primaryColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo
                  Image.asset(
                    'assets/image/LogoJr.png',
                    width: 180,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lengkapi Profil Anda',
                    style: TextStyle(
                      fontFamily: GoogleFonts.poppins().fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: MainColor.primaryText,
                    ),
                  ),
                  Text(
                    'Isi data berikut untuk melanjutkan',
                    style: TextStyle(
                      fontFamily: GoogleFonts.poppins().fontFamily,
                      fontSize: 13,
                      color: MainColor.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile Photo
                  Obx(() {
                    Widget imgWidget;
                    if (controller.profileImage.value != null) {
                      if (kIsWeb) {
                        imgWidget = Image.memory(
                          controller.profileImage.value as Uint8List,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        );
                      } else {
                        imgWidget = Image.file(
                          controller.profileImage.value as File,
                          fit: BoxFit.cover,
                          width: 120,
                          height: 120,
                        );
                      }
                    } else {
                      imgWidget = Icon(Icons.person,
                          size: 80, color: Colors.grey.shade400);
                    }

                    return Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.grey.shade200, width: 4),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: controller.profileImage.value != null
                              ? imgWidget
                              : Center(child: imgWidget),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => controller.pickImage(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFECDAC7),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 8),
                    ),
                    child: Text(
                      'Ambil Foto',
                      style: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Fields
                  _buildField(
                    controller: controller.namaController,
                    hint: 'Nama Lengkap',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.jabatanController,
                    hint: 'Jabatan',
                    icon: Icons.work_outline,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.alamatController,
                    hint: 'Alamat',
                    icon: Icons.location_on_outlined,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.noTelpController,
                    hint: 'No Telp',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 32),

                  // Simpan Button
                  SizedBox(
                    width: double.infinity,
                    child: Obx(() => ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : () => controller.simpan(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F67AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Simpan',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.poppins().fontFamily,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        )),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(
        fontFamily: GoogleFonts.poppins().fontFamily,
        fontSize: 14,
      ),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon:
            icon != null ? Icon(icon, color: Colors.grey.shade500) : null,
        filled: true,
        fillColor: const Color(0xFFF0F3F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
