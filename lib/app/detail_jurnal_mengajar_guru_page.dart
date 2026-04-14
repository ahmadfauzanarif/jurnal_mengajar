import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jurnal_mengajar/app/form_jurnal_mengajar_guru_page.dart';

class DetailJurnalGuruController extends GetxController {
  final int jurnalId;
  final supabase = Supabase.instance.client;

  var isLoading = true.obs;
  var jurnal = {}.obs;

  DetailJurnalGuruController(this.jurnalId);

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    try {
      final res = await supabase
          .from('jurnal_harian')
          .select('*, jadwal_mengajar(*, master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*)), profiles:validated_by(nama_lengkap)')
          .eq('id', jurnalId)
          .single();
      jurnal.value = res;
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat detail: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class DetailJurnalMengajarGuruPage extends StatelessWidget {
  final int jurnalId;
  const DetailJurnalMengajarGuruPage({super.key, required this.jurnalId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DetailJurnalGuruController(jurnalId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail Jurnal',
          style: TextStyle(color: Colors.white, fontFamily: GoogleFonts.poppins().fontFamily),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = controller.jurnal.value;
        if (data.isEmpty) return const Center(child: Text('Data tidak ditemukan'));

        final status = data['status'] ?? 'pending';
        final jadwal = data['jadwal_mengajar'];
        String className = jadwal['master_kelas']['nama_kelas'] ?? '-';
        String subject = jadwal['master_mata_pelajaran']['nama_mata_pelajaran'] ?? '-';
        String jamStr = '${jadwal['master_jam']['waktu_reguler']}';
        String dateStr = DateFormat('dd MMMM yyyy').format(DateTime.parse(data['tanggal']));

        bool isVerified = (status == 'validated' || status == 'approved' || status == 'disetujui');
        bool isRejected = (status == 'rejected' || status == 'ditolak');

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: isVerified ? const Color(0xFFEBE0C8) : (isRejected ? Colors.orange.shade100 : const Color(0xFFCDD8F0)),
                child: Center(
                  child: Text(
                    isVerified ? 'Sudah diverifikasi oleh Admin' 
                      : (isRejected ? 'Ditolak oleh Admin: ${data['catatan_admin'] ?? '-'}' : 'Belum diverifikasi oleh Admin'),
                    style: TextStyle(
                      color: isVerified ? Colors.green.shade800 : (isRejected ? Colors.red.shade800 : MainColor.primaryColor),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                Supabase.instance.client.auth.currentUser?.email ?? 'Guru',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                className,
                style: TextStyle(
                  fontSize: 16,
                  color: MainColor.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subject,
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
                  ),
                  const SizedBox(width: 24),
                  const Icon(Icons.access_time, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    jamStr,
                    style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              
              _buildLabel('Materi'),
              Text(
                data['materi'] ?? '-',
                style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
              ),
              const SizedBox(height: 16),

              _buildLabel('Catatan'),
              Text(
                data['catatan'] ?? '-',
                style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily),
              ),
              const SizedBox(height: 16),

              // Placeholder for attendance info
              _buildLabel('Absensi (S, I, A)'),
              const Row(
                children: [
                  // This should be populated perfectly but for detail it might just show total counts
                  Text('S: 0, I: 0, A: 0')
                ],
              ),
              const SizedBox(height: 24),

              if (!isVerified)
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
                      Get.to(() => FormJurnalMengajarGuruPage(
                        schedule: data['jadwal_mengajar'],
                        isEdit: true,
                        jurnalId: data['id'],
                      ))?.then((value) {
                         if (value == true) controller.fetchDetail();
                      });
                    },
                    child: Text(
                      'Edit Jurnal',
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
        );
      }),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
      ),
    );
  }
}
