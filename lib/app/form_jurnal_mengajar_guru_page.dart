import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

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
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
      maxWidth: 1080,
    );

    if (image != null) {
      selectedImages.add(File(image.path));
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

      final jurnalData = {
        'tanggal': DateFormat('yyyy-MM-dd').format(selectedTanggal.value),
        'materi': materiController.text,
        'catatan': catatanController.text,
        'foto_lampiran_url': finalPhotoUrl,
        'status': 'pending',
      };

      List<int> savedJurnalIds = [];

      if (isEdit && jurnalId != null) {
        // === MODE EDIT ===
        // Cari jurnal asli untuk mendapatkan info jadwal
        final originalJurnal = await supabase
            .from('jurnal_harian')
            .select(
              'id, jadwal_id, tanggal, jadwal_mengajar!inner(guru_id, kelas_id, mata_pelajaran_id, tanggal)',
            )
            .eq('id', jurnalId!)
            .single();

        final jadwalInfo = originalJurnal['jadwal_mengajar'];
        final guruId = jadwalInfo['guru_id'];
        final kelasId2 = jadwalInfo['kelas_id'];
        final mapelId = jadwalInfo['mata_pelajaran_id'];
        final tanggalJadwal = jadwalInfo['tanggal'];

        // Step 1: Cari semua jadwal_mengajar yang cocok (guru, kelas, mapel, tanggal sama)
        final matchingJadwal = await supabase
            .from('jadwal_mengajar')
            .select('id')
            .eq('guru_id', guruId)
            .eq('kelas_id', kelasId2)
            .eq('mata_pelajaran_id', mapelId)
            .eq('tanggal', tanggalJadwal);

        List<int> matchingJadwalIds = matchingJadwal
            .map<int>((j) => j['id'] as int)
            .toList();

        // Step 2: Cari semua jurnal_harian yang terhubung ke jadwal-jadwal tersebut
        List<int> siblingIds = [];
        if (matchingJadwalIds.isNotEmpty) {
          final siblingJournals = await supabase
              .from('jurnal_harian')
              .select('id')
              .inFilter('jadwal_id', matchingJadwalIds)
              .eq('tanggal', originalJurnal['tanggal']);

          for (var sj in siblingJournals) {
            siblingIds.add(sj['id'] as int);
          }
        }

        // Jika tidak ditemukan sibling, minimal update jurnal yang diketahui
        if (siblingIds.isEmpty) {
          siblingIds = [jurnalId!];
        }

        // Update SEMUA jurnal saudara sekaligus
        for (int sjId in siblingIds) {
          final res = await supabase
              .from('jurnal_harian')
              .update(jurnalData)
              .eq('id', sjId)
              .select()
              .single();
          savedJurnalIds.add(res['id']);
        }
      } else {
        // === MODE BARU (INSERT) ===
        List<int> allJadwalIds = [];
        if (groupedSchedules.isNotEmpty) {
          allJadwalIds = groupedSchedules
              .map<int>((s) => s['id'] as int)
              .toList();
        } else {
          allJadwalIds = [schedule['id'] as int];
        }

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

        // 7. Kirim Notifikasi WhatsApp ke Orang Tua
        _sendWhatsappNotifications();
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

  Future<void> _sendWhatsappNotifications() async {
    final token = dotenv.env['NOBOXAI_TOKEN'];
    if (token == null || token.isEmpty) {
      debugPrint(
        'WhatsApp notification skipped: NOBOXAI_TOKEN not found in .env',
      );
      return;
    }

    // Ambil info jam dan mapel
    String jamKeStr;
    if (groupedSchedules.isNotEmpty) {
      jamKeStr = groupedSchedules
          .map((s) => s['master_jam']['jam_ke'].toString())
          .join(', ');
    } else {
      jamKeStr = schedule['master_jam']['jam_ke'].toString();
    }
    final mapelStr =
        schedule['master_mata_pelajaran']['nama_mata_pelajaran'] ?? '';
    final tanggalStr = DateFormat(
      'dd MMMM yyyy',
      'id_ID',
    ).format(selectedTanggal.value);

    int countSent = 0;

    for (var siswa in siswaList) {
      final id = siswa['id'] as int;
      final status = absensiMap[id];
      final noHp = siswa['no_hp_ortu']?.toString().trim();

      // Hanya kirim jika tidak hadir (S/I/A) dan ada nomor HP
      if (status != null &&
          status != 'H' &&
          status != 'Hadir' &&
          noHp != null &&
          noHp.isNotEmpty) {
        String statusFull = '';
        if (status == 'S')
          statusFull = 'Sakit';
        else if (status == 'I')
          statusFull = 'Izin';
        else if (status == 'A')
          statusFull = 'Alpha (Tanpa Keterangan)';
        else
          statusFull = status;

        final bodyMsg =
            "*Notifikasi Kehadiran Siswa*\n\n"
            "Yth. Orang Tua/Wali dari *${siswa['nama_siswa']}*,\n\n"
            "Menginformasikan bahwa putra/putri Bapak/Ibu tercatat *${statusFull}* pada:\n"
            "📅 Tanggal: ${tanggalStr}\n"
            "⏰ Jam Ke: ${jamKeStr}\n"
            "📖 Mata Pelajaran: ${mapelStr}\n\n"
            "Terima kasih.\n"
            "_Pesan otomatis dari Jurnal Mengajar_";

        try {
          final response = await http.post(
            Uri.parse('https://id.nobox.ai/Inbox/Send'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              "ExtId": noHp.replaceAll(
                RegExp(r'[^0-9]'),
                '',
              ), // Bersihkan nomor
              "ChannelId": "1",
              "AccountIds": "664334723301381",
              "BodyType": "Text",
              "Body": bodyMsg,
              "Attachment": "",
            }),
          );

          if (response.statusCode == 200) {
            final resData = jsonDecode(response.body);
            if (resData['IsError'] == false) {
              countSent++;
            }
          }
        } catch (e) {
          debugPrint('Gagal mengirim WA ke $noHp: $e');
        }
      }
    }

    if (countSent > 0) {
      Get.snackbar(
        'WhatsApp Terkirim',
        '$countSent notifikasi ketidakhadiran telah dikirim ke orang tua siswa.',
        backgroundColor: Colors.blue.shade700,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        icon: FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
      );
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
                  if (controller.isEdit &&
                      controller.jurnalStatus.value == 'rejected')
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
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.red.shade700,
                                size: 20,
                              ),
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
                  _buildDisabledField(
                    DateFormat(
                      'dd MMMM yyyy',
                    ).format(controller.selectedTanggal.value),
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

                  _buildLabel('Foto Kegiatan (Minimal 3 Foto)'),
                  const SizedBox(height: 8),
                  Obx(
                    () => Column(
                      children: [
                        // Large box if no images selected
                        if (controller.existingImagesUrl.isEmpty &&
                            controller.selectedImages.isEmpty)
                          GestureDetector(
                            onTap: () => controller.pickPhotos(),
                            child: Container(
                              width: double.infinity,
                              height: 220,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 2,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.camera_alt_rounded,
                                      size: 48,
                                      color: MainColor.primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Buka Kamera untuk Foto',
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Wajib ambil minimal 3 foto langsung',
                                    style: TextStyle(
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1,
                                ),
                            itemCount:
                                controller.existingImagesUrl.length +
                                controller.selectedImages.length +
                                1, // +1 for the add button
                            itemBuilder: (context, index) {
                              // If it's the last item, show "Add more" button
                              if (index ==
                                  controller.existingImagesUrl.length +
                                      controller.selectedImages.length) {
                                return GestureDetector(
                                  onTap: () => controller.pickPhotos(),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        style: BorderStyle.solid,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Colors.grey.shade600,
                                      size: 28,
                                    ),
                                  ),
                                );
                              }

                              bool isExisting =
                                  index < controller.existingImagesUrl.length;
                              if (isExisting) {
                                final url = controller.existingImagesUrl[index];
                                return _buildImageItem(
                                  url: url,
                                  onDelete: () =>
                                      controller.removeExistingPhoto(index),
                                );
                              } else {
                                final fileIndex =
                                    index - controller.existingImagesUrl.length;
                                final file =
                                    controller.selectedImages[fileIndex];
                                return _buildImageItem(
                                  file: file,
                                  onDelete: () =>
                                      controller.removePhoto(fileIndex),
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

  Widget _buildImageItem({
    String? url,
    File? file,
    required VoidCallback onDelete,
  }) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            image: DecorationImage(
              image: url != null
                  ? NetworkImage(url)
                  : FileImage(file!) as ImageProvider,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    );
  }
}
