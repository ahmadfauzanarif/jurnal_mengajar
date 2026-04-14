import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FormJurnalGuruController extends GetxController {
  final supabase = Supabase.instance.client;

  final Map<String, dynamic> schedule;
  final List<Map<String, dynamic>> groupedSchedules; // all jadwal in the group
  final bool isEdit;
  final int? jurnalId;

  FormJurnalGuruController({
    required this.schedule,
    this.groupedSchedules = const [],
    this.isEdit = false,
    this.jurnalId,
  });

  var isLoading = false.obs;
  var jurnalStatus = "pending".obs;
  var catatanAdmin = "".obs;

  var isHadirSemua = false.obs;

  var selectedTanggal = DateTime.now().obs;
  var materiController = TextEditingController();
  var catatanController = TextEditingController();

  var siswaList = [].obs;
  // Key: siswa id, Value: 'S', 'I', 'A', or null
  var absensiMap = <int, String?>{}.obs;

  var selectedImages = <File>[].obs;
  var existingImagesUrl = <String>[].obs; // For edit mode later if needed

  var maxDate = DateTime.now().obs;
  var minDate = DateTime.now().subtract(const Duration(days: 3)).obs;

  @override
  void onInit() {
    super.onInit();
    // Default selectedDate is from schedule
    selectedTanggal.value = DateTime.parse(schedule['tanggal']);

    // Set max and min dates based on schedule date
    maxDate.value = DateTime.parse(schedule['tanggal']);
    minDate.value = maxDate.value.subtract(const Duration(days: 3));

    _initForm();
  }

  Future<void> _initForm() async {
    await fetchSiswa();
    if (isEdit && jurnalId != null) {
      await fetchJournalData();
    }
  }

  Future<void> fetchJournalData() async {
    isLoading.value = true;
    try {
      final res = await supabase
          .from('jurnal_harian')
          .select()
          .eq('id', jurnalId!)
          .single();

      materiController.text = res['materi'] ?? '';
      catatanController.text = res['catatan'] ?? '';
      jurnalStatus.value = res['status'] ?? 'pending';
      catatanAdmin.value = res['catatan_admin'] ?? '';
      
      if (res['tanggal'] != null) {
        selectedTanggal.value = DateTime.parse(res['tanggal']);
      }

      if (res['foto_lampiran_url'] != null &&
          res['foto_lampiran_url'].toString().isNotEmpty) {
        existingImagesUrl.value = res['foto_lampiran_url']
            .toString()
            .split(',')
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Fetch presensi
      final presensiRes = await supabase
          .from('presensi_siswa')
          .select()
          .eq('jurnal_id', jurnalId!);

      for (var p in presensiRes) {
        final siswaId = p['siswa_id'] as int;
        final status = p['status'] as String;
        // Normalize status to single char if needed, though DB seems to support both
        String normalizedStatus = status;
        if (status == 'Hadir')
          normalizedStatus = 'H';
        else if (status == 'Sakit')
          normalizedStatus = 'S';
        else if (status == 'Izin')
          normalizedStatus = 'I';
        else if (status == 'Alpha')
          normalizedStatus = 'A';

        absensiMap[siswaId] = normalizedStatus;
      }

      // Update isHadirSemua
      if (absensiMap.isNotEmpty) {
        isHadirSemua.value = absensiMap.values.every((v) => v == 'H');
      }

      absensiMap.refresh();
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data jurnal: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchSiswa() async {
    isLoading.value = true;
    try {
      final kelasId = schedule['kelas_id'];
      final res = await supabase
          .from('master_siswa')
          .select()
          .eq('kelas_id', kelasId)
          .order('nama_siswa', ascending: true);

      siswaList.value = res;
      for (var s in res) {
        final id = s['id'] as int;
        // Default to 'H' (Hadir) as per user request to optimize storage
        absensiMap[id] = 'H';
      }
      isHadirSemua.value = true;
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat daftar siswa: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedTanggal.value,
      firstDate: minDate.value,
      lastDate: maxDate.value,
    );
    if (picked != null) {
      selectedTanggal.value = picked;
    }
  }

  void toggleHadirSemua(bool? value) {
    if (value == true) {
      isHadirSemua.value = true;
      for (var s in siswaList) {
        final id = s['id'] as int;
        absensiMap[id] = 'H';
      }
      absensiMap.refresh(); // Force UI rebuild
    } else {
      isHadirSemua.value = false;
      for (var s in siswaList) {
        final id = s['id'] as int;
        absensiMap[id] = null;
      }
      absensiMap.refresh(); // Force UI rebuild
    }
  }

  void setAbsensiSiswa(int id, String status) {
    absensiMap[id] = status;
    absensiMap.refresh(); // Force UI rebuild

    // Check if all are 'H'
    bool allHadir = absensiMap.values.every((s) => s == 'H');
    isHadirSemua.value = allHadir;
  }

  Future<void> pickPhotos() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      imageQuality: 50,
      maxWidth: 1080,
    );

    if (images.isNotEmpty) {
      for (var img in images) {
        selectedImages.add(File(img.path));
      }
    }
  }

  void removePhoto(int index) {
    selectedImages.removeAt(index);
  }

  void removeExistingPhoto(int index) {
    existingImagesUrl.removeAt(index);
  }

  Future<void> simpanJurnal() async {
    if (materiController.text.isEmpty) {
      Get.snackbar('Peringatan', 'Materi tidak boleh kosong');
      return;
    }
    if (selectedImages.length + existingImagesUrl.length < 3) {
      Get.snackbar('Peringatan', 'Pilih minimal 3 foto kegiatan');
      return;
    }

    isLoading.value = true;
    try {
      final supabase = Supabase.instance.client;

      // 1. Upload images
      List<String> uploadedUrls = [...existingImagesUrl];
      for (var file in selectedImages) {
        final fileName =
            'jurnal_${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        await supabase.storage.from('jurnalimage').upload(fileName, file);
        final url = supabase.storage.from('jurnalimage').getPublicUrl(fileName);
        uploadedUrls.add(url);
      }
      String finalPhotoUrl = uploadedUrls.join(',');

      // 2. Tentukan semua jadwal ID dalam grup ini
      List<int> allJadwalIds = [];
      if (groupedSchedules.isNotEmpty) {
        allJadwalIds = groupedSchedules.map<int>((s) => s['id'] as int).toList();
      } else {
        allJadwalIds = [schedule['id'] as int];
      }

      // 3. Simpan Jurnal untuk setiap jadwal_id
      // Gunakan list untuk menampung ID jurnal yang baru dibuat/diupdate
      List<int> savedJurnalIds = [];

      final jurnalData = {
        'tanggal': DateFormat('yyyy-MM-dd').format(selectedTanggal.value),
        'materi': materiController.text,
        'catatan': catatanController.text,
        'foto_lampiran_url': finalPhotoUrl,
        'status': 'pending',
      };

      if (isEdit && jurnalId != null) {
        // Mode Edit (asumsi hanya satu jurnal yang diedit)
        final res = await supabase
            .from('jurnal_harian')
            .update({...jurnalData, 'jadwal_id': allJadwalIds.first})
            .eq('id', jurnalId!)
            .select()
            .single();
        savedJurnalIds.add(res['id']);
      } else {
        // Mode Baru (bisa berkelompok)
        for (int jId in allJadwalIds) {
          final res = await supabase
              .from('jurnal_harian')
              .insert({...jurnalData, 'jadwal_id': jId})
              .select()
              .single();
          savedJurnalIds.add(res['id']);
        }
      }

      // 4. Proses Presensi - HANYA status S, I, A yang disimpan
      // Siswa yang Hadir (H) tidak perlu disimpan di database untuk menghemat payload dan storage
      List<Map<String, dynamic>> presensiList = [];
      final kelasId = schedule['kelas_id'];

      absensiMap.forEach((siswaId, status) {
        // Normalisasi status dan hanya masukkan jika S, I, atau A
        if (status != null && status != 'H' && status != 'Hadir') {
          for (int sJurnalId in savedJurnalIds) {
            presensiList.add({
              'jurnal_id': sJurnalId,
              'siswa_id': siswaId,
              'status': status,
              'kelas_id': kelasId,
            });
          }
        }
      });

      // 5. Bersihkan data presensi lama jika sedang edit
      if (isEdit) {
        for (int sJurnalId in savedJurnalIds) {
          await supabase
              .from('presensi_siswa')
              .delete()
              .eq('jurnal_id', sJurnalId);
        }
      }

      // 6. Bulk Insert Presensi (jika ada yang tidak hadir)
      if (presensiList.isNotEmpty) {
        await supabase.from('presensi_siswa').insert(presensiList);
      }

      Get.back(result: true);
      Get.snackbar(
        'Sukses',
        'Jurnal berhasil disimpan',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar('Error', 'Gagal menyimpan jurnal: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class FormJurnalMengajarGuruPage extends StatelessWidget {
  final Map<String, dynamic> schedule;
  final List<Map<String, dynamic>> groupedSchedules;
  final bool isEdit;
  final int? jurnalId;

  const FormJurnalMengajarGuruPage({
    super.key,
    required this.schedule,
    this.groupedSchedules = const [],
    this.isEdit = false,
    this.jurnalId,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      FormJurnalGuruController(
        schedule: schedule,
        groupedSchedules: groupedSchedules,
        isEdit: isEdit,
        jurnalId: jurnalId,
      ),
    );

    // Build jam ke string from grouped schedules
    String jamKeStr;
    String waktuStr;
    if (groupedSchedules.isNotEmpty) {
      List<String> jamKeList = groupedSchedules
          .map((s) => s['master_jam']['jam_ke'].toString())
          .toList();
      jamKeStr = jamKeList.join(', ');
      String firstTime =
          groupedSchedules.first['master_jam']['waktu_reguler']
              ?.split('-')[0]
              .trim() ??
          '';
      String lastTime =
          groupedSchedules.last['master_jam']['waktu_reguler']
              ?.split('-')[1]
              .trim() ??
          '';
      waktuStr = '$firstTime - $lastTime';
    } else {
      jamKeStr = schedule['master_jam']['jam_ke'].toString();
      waktuStr = schedule['master_jam']['waktu_reguler'] ?? '';
    }
    String kelasStr = schedule['master_kelas']['nama_kelas'] ?? '';
    String mapelStr =
        schedule['master_mata_pelajaran']['nama_mata_pelajaran'] ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Jurnal' : 'Jurnal Mengajar',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value && controller.siswaList.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (controller.isEdit && controller.jurnalStatus.value == 'rejected')
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Jurnal ditolak, silahkan diperbarui',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Catatan Admin:',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade100),
                            ),
                            child: Text(
                              controller.catatanAdmin.value.isEmpty 
                                  ? 'Tidak ada catatan khusus dari admin.' 
                                  : controller.catatanAdmin.value,
                              style: TextStyle(
                                color: Colors.red.shade800,
                                fontSize: 13,
                                height: 1.5,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  _buildLabel('Tanggal'),
                  GestureDetector(
                    onTap: () => controller.pickDate(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat(
                              'dd MMMM yyyy',
                            ).format(controller.selectedTanggal.value),
                            style: TextStyle(
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today,
                            size: 20,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Jam Ke'),
                            _buildDisabledField(jamKeStr),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLabel('Kelas'),
                            _buildDisabledField(kelasStr),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Waktu'),
                  _buildDisabledField(waktuStr),
                  const SizedBox(height: 16),

                  _buildLabel('Pelajaran'),
                  _buildDisabledField(mapelStr),
                  const SizedBox(height: 16),

                  _buildLabel('Materi'),
                  TextField(
                    controller: controller.materiController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'Masukkan materi...',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Absensi (H, S, I, A)'),
                      Obx(
                        () => Row(
                          children: [
                            Checkbox(
                              value: controller.isHadirSemua.value,
                              onChanged: controller.toggleHadirSemua,
                              activeColor: Colors.indigo,
                            ),
                            Text(
                              'Hadir Semua',
                              style: TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Absensi List
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Obx(() {
                      // IMPORTANT: Read absensiMap here so Obx subscribes to changes.
                      // itemBuilder runs lazily during layout (after Obx tracking ends),
                      // so without this, Obx never detects absensiMap mutations.
                      final _ = controller.absensiMap.entries.toList();

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: controller.siswaList.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final siswa = controller.siswaList[index];
                          final siswaId = siswa['id'] as int;
                          final absensi = controller.absensiMap[siswaId];

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    siswa['nama_siswa'],
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                _buildAbsensiCircle(
                                  controller,
                                  siswaId,
                                  'H',
                                  absensi == 'H',
                                ),
                                const SizedBox(width: 8),
                                _buildAbsensiCircle(
                                  controller,
                                  siswaId,
                                  'S',
                                  absensi == 'S',
                                ),
                                const SizedBox(width: 8),
                                _buildAbsensiCircle(
                                  controller,
                                  siswaId,
                                  'I',
                                  absensi == 'I',
                                ),
                                const SizedBox(width: 8),
                                _buildAbsensiCircle(
                                  controller,
                                  siswaId,
                                  'A',
                                  absensi == 'A',
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                  ),
                  const SizedBox(height: 16),

                  _buildLabel('Catatan'),
                  TextField(
                    controller: controller.catatanController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Tambahkan catatan jika ada...',
                      hintStyle: TextStyle(
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabel('Lampiran (min. 3 foto)'),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.indigo,
                          size: 28,
                        ),
                        onPressed: () => controller.pickPhotos(),
                      ),
                    ],
                  ),
                  // Image grid
                  Obx(
                    () => Column(
                      children: [
                        if (controller.existingImagesUrl.isNotEmpty ||
                            controller.selectedImages.isNotEmpty)
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount:
                                controller.existingImagesUrl.length +
                                controller.selectedImages.length,
                            itemBuilder: (context, index) {
                              bool isExisting =
                                  index < controller.existingImagesUrl.length;
                              if (isExisting) {
                                final url = controller.existingImagesUrl[index];
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: NetworkImage(url),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () => controller
                                            .removeExistingPhoto(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                final fileIndex =
                                    index - controller.existingImagesUrl.length;
                                final file =
                                    controller.selectedImages[fileIndex];
                                return Stack(
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        image: DecorationImage(
                                          image: FileImage(file),
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: GestureDetector(
                                        onTap: () =>
                                            controller.removePhoto(fileIndex),
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.close,
                                            color: Colors.white,
                                            size: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 100), // bottom padding for button
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
                    backgroundColor: const Color(
                      0xFF4DB6E1,
                    ), // Light blue from design
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: controller.isLoading.value
                      ? null
                      : () => controller.simpanJurnal(),
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

  Widget _buildDisabledField(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100, // disabled style
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
      ),
    );
  }

  Widget _buildAbsensiCircle(
    FormJurnalGuruController controller,
    int siswaId,
    String type,
    bool isSelected,
  ) {
    Color selectedColor;
    if (type == 'H') {
      selectedColor = Colors.green;
    } else if (type == 'S')
      selectedColor = Colors.orange;
    else if (type == 'I')
      selectedColor = Colors.blue;
    else
      selectedColor = Colors.red;

    return GestureDetector(
      onTap: () => controller.setAbsensiSiswa(siswaId, type),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : Colors.white,
          border: Border.all(
            color: isSelected ? selectedColor : Colors.grey.shade400,
          ),
          borderRadius: BorderRadius.circular(8), // matching design
        ),
        child: Center(
          child: Text(
            type,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}
