import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfilGuruController extends GetxController {
  final supabase = Supabase.instance.client;

  var isLoading = false.obs;
  var isFetching = true.obs;

  var namaController = TextEditingController();
  var alamatController = TextEditingController();
  var noTelpController = TextEditingController();
  var jabatanController = TextEditingController();

  var currentFotoUrl = RxnString();
  var newImageFile = Rxn<File>();

  @override
  void onInit() {
    super.onInit();
    fetchProfile();
  }

  Future<void> fetchProfile() async {
    isFetching.value = true;
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final profileRes = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();

        namaController.text = profileRes['nama_lengkap'] ?? '';
        alamatController.text = profileRes['alamat'] ?? '';
        noTelpController.text = profileRes['no_telp'] ?? '';
        jabatanController.text = profileRes['jabatan'] ?? '';
        currentFotoUrl.value = profileRes['foto_url'];
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data: $e');
    } finally {
      isFetching.value = false;
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
      newImageFile.value = File(pickedFile.path);
    }
  }

  Future<void> simpanProfile() async {
    if (namaController.text.isEmpty) {
      Get.snackbar('Peringatan', 'Nama lengkap tidak boleh kosong');
      return;
    }

    isLoading.value = true;
    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      String? updatedFotoUrl = currentFotoUrl.value;

      // Upload new image if exists
      if (newImageFile.value != null) {
        final file = newImageFile.value!;
        final fileName =
            'profil_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage.from('profil').upload(fileName, file);
        updatedFotoUrl = supabase.storage.from('profil').getPublicUrl(fileName);
      }

      await supabase
          .from('profiles')
          .update({
            'nama_lengkap': namaController.text,
            'alamat': alamatController.text,
            'no_telp': noTelpController.text,
            'jabatan': jabatanController.text,
            'foto_url': updatedFotoUrl,
          })
          .eq('id', user.id);

      Get.back(result: true); // go back to profile page
      Get.snackbar(
        'Sukses',
        'Profil berhasil diperbarui',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Gagal menyimpan profil: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class EditProfilGuruPage extends StatelessWidget {
  const EditProfilGuruPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(EditProfilGuruController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isFetching.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                            image:
                                controller.newImageFile.value != null
                                    ? DecorationImage(
                                      image: FileImage(
                                        controller.newImageFile.value!,
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                    : (controller.currentFotoUrl.value != null
                                        ? DecorationImage(
                                          image: NetworkImage(
                                            controller.currentFotoUrl.value!,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                        : null),
                          ),
                          child:
                              (controller.newImageFile.value == null &&
                                  controller.currentFotoUrl.value == null)
                              ? Icon(
                                Icons.person,
                                size: 50,
                                color: Colors.grey.shade400,
                              )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: () => controller.pickImage(),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Colors.indigo,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildLabel('Nama Lengkap'),
                  TextField(
                    controller: controller.namaController,
                    decoration: InputDecoration(
                      hintText: 'Nama lengkap...',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Alamat'),
                  TextField(
                    controller: controller.alamatController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Alamat...',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Nomor Telepon'),
                  TextField(
                    controller: controller.noTelpController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'Nomor telepon...',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Jabatan / Posisi'),
                  TextField(
                    controller: controller.jabatanController,
                    decoration: InputDecoration(
                      hintText: 'Contoh: Guru Matematika, Wali Kelas...',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  const SizedBox(height: 100), // spacing for bottom button
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MainColor.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.simpanProfile(),
                  child: controller.isLoading.value
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      : Text(
                          'Simpan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: 14,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
      ),
    );
  }
}
