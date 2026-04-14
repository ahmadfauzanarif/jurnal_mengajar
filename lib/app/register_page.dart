import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RegisterController extends GetxController {
  final supabase = Supabase.instance.client;

  var isLoading = false.obs;
  var obscurePassword = true.obs;
  var obscureConfirmPassword = true.obs;

  final namaController = TextEditingController();
  final jabatanController = TextEditingController();
  final alamatController = TextEditingController();
  final noTelpController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  var profileImage = Rxn<File>();

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile != null) {
      profileImage.value = File(pickedFile.path);
    }
  }

  Future<void> register() async {
    // Validation
    if (namaController.text.isEmpty ||
        jabatanController.text.isEmpty ||
        alamatController.text.isEmpty ||
        noTelpController.text.isEmpty ||
        emailController.text.isEmpty ||
        passwordController.text.isEmpty) {
      Get.snackbar('Error', 'Semua field harus diisi',
          backgroundColor: Colors.red, colorText: Colors.white);
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      Get.snackbar('Error', 'Password tidak cocok',
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
      // 1. Sign Up to Supabase
      final AuthResponse res = await supabase.auth.signUp(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        data: {
          'full_name': namaController.text.trim(),
        },
      );

      final user = res.user;
      if (user == null) throw Exception('Registrasi gagal');

      String? photoUrl;

      // 2. Upload Profile Image
      if (profileImage.value != null) {
        final file = profileImage.value!;
        final fileName = 'profil_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await supabase.storage.from('profil').upload(fileName, file);
        photoUrl = supabase.storage.from('profil').getPublicUrl(fileName);
      }

      // 3. Update Profile Record (Trigger already created a basic record)
      await supabase.from('profiles').update({
        'nama_lengkap': namaController.text.trim(),
        'jabatan': jabatanController.text.trim(),
        'alamat': alamatController.text.trim(),
        'no_telp': noTelpController.text.trim(),
        'foto_url': photoUrl,
        'email': emailController.text.trim(),
        'role': 'guru',
      }).eq('id', user.id);

      Get.back(); // Return to Login
      Get.snackbar(
        'Sukses',
        'Registrasi berhasil! Silakan cek email Anda untuk verifikasi akun.',
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } on AuthException catch (e) {
      Get.snackbar('Error', e.message,
          backgroundColor: Colors.red, colorText: Colors.white);
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
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.onClose();
  }
}

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RegisterController());

    return Scaffold(
      backgroundColor: MainColor.primaryColor,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
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
                  const SizedBox(height: 24),

                  // Profile Photo
                  Obx(() => Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade200, width: 4),
                              image: controller.profileImage.value != null
                                  ? DecorationImage(
                                      image: FileImage(controller.profileImage.value!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: controller.profileImage.value == null
                                ? Icon(Icons.person, size: 80, color: Colors.grey.shade400)
                                : null,
                          ),
                        ],
                      )),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => controller.pickImage(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFECDAC7),
                      foregroundColor: Colors.black87,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: Text(
                      'Upload Foto',
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
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.jabatanController,
                    hint: 'Jabatan',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.alamatController,
                    hint: 'Alamat',
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.noTelpController,
                    hint: 'No Telp',
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: controller.emailController,
                    hint: 'Email',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  Obx(() => _buildField(
                        controller: controller.passwordController,
                        hint: 'Password',
                        obscureText: controller.obscurePassword.value,
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.obscurePassword.value ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => controller.obscurePassword.toggle(),
                        ),
                      )),
                  const SizedBox(height: 12),
                  Obx(() => _buildField(
                        controller: controller.confirmPasswordController,
                        hint: 'Konfirmasi Password',
                        obscureText: controller.obscureConfirmPassword.value,
                        suffixIcon: IconButton(
                          icon: Icon(
                            controller.obscureConfirmPassword.value ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => controller.obscureConfirmPassword.toggle(),
                        ),
                      )),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: Obx(() => ElevatedButton(
                          onPressed: controller.isLoading.value ? null : () => controller.register(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3F67AF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: controller.isLoading.value
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  'Buat Akun',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.poppins().fontFamily,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        )),
                  ),
                  const SizedBox(height: 20),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Sudah Punya Akun? ',
                        style: TextStyle(
                          color: MainColor.secondaryText,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Get.back(),
                        child: Text(
                          'Login Disini',
                          style: TextStyle(
                            fontFamily: GoogleFonts.poppins().fontFamily,
                            color: const Color(0xFF3F67AF),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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
        filled: true,
        fillColor: const Color(0xFFF0F3F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(
          color: Colors.grey.shade500,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
