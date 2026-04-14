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
  var jurnal = <String, dynamic>{}.obs;

  DetailJurnalGuruController(this.jurnalId);

  @override
  void onInit() {
    super.onInit();
    fetchDetail();
  }

  Future<void> fetchDetail() async {
    isLoading.value = true;
    try {
      // Menggunakan query yang sangat eksplisit untuk memastikan join terbaca
      final res = await supabase
          .from('jurnal_harian')
          .select('''
            *,
            presensi_siswa (
              *,
              master_siswa (*)
            ),
            jadwal_mengajar (
              *,
              master_kelas (*),
              master_mata_pelajaran (*),
              master_jam (*),
              guru:profiles!guru_id (
                id,
                nama_lengkap,
                foto_url
              )
            )
          ''')
          .eq('id', jurnalId)
          .single();
      
      jurnal.value = res;
      print("Debug Data Detail: $res");
    } catch (e) {
      print("Error Detail: $e");
      Get.snackbar('Error', 'Gagal memuat detail jurnal: $e');
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
    // Gunakan tag unik atau pastikan controller terupdate
    final controller = Get.put(DetailJurnalGuruController(jurnalId), tag: jurnalId.toString());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail Jurnal',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.poppins().fontFamily),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = controller.jurnal;
        if (data.isEmpty) return const Center(child: Text('Data tidak ditemukan'));

        final status = data['status'] ?? 'pending';
        final jadwal = data['jadwal_mengajar'] ?? {};
        final guru = jadwal['guru'] ?? {}; // Menggunakan alias 'guru' dari select
        
        String guruName = guru['nama_lengkap'] ?? 'Nama Guru Tidak Tersedia';
        String className = jadwal['master_kelas']?['nama_kelas'] ?? '-';
        String subject = jadwal['master_mata_pelajaran']?['nama_mata_pelajaran'] ?? '-';
        String jamStr = jadwal['master_jam']?['waktu_reguler'] ?? '-';
        String dateStr = data['tanggal'] != null 
            ? DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(data['tanggal'])) 
            : '-';

        bool isVerified = (status == 'approved' || status == 'disetujui');
        bool isRejected = (status == 'rejected' || status == 'ditolak');

        // Parse presensi
        final List presensi = data['presensi_siswa'] as List? ?? [];
        int sakitCount = presensi.where((p) => p['status'].toString().toUpperCase().startsWith('S')).length;
        int izinCount = presensi.where((p) => p['status'].toString().toUpperCase().startsWith('I')).length;
        int alphaCount = presensi.where((p) => p['status'].toString().toUpperCase().startsWith('A')).length;

        // Parse foto lampiran
        final String photoUrlsRaw = data['foto_lampiran_url']?.toString() ?? "";
        final List<String> listPhotos = photoUrlsRaw.isNotEmpty ? photoUrlsRaw.split(',').map((e) => e.trim()).toList() : [];

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner Verification
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isVerified ? Colors.green.shade50 : (isRejected ? Colors.red.shade50 : Colors.blue.shade50),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    isVerified ? 'Sudah diverifikasi oleh Admin' 
                      : (isRejected ? 'Ditolak: ${data['catatan_admin'] ?? '-'}' : 'Belum diverifikasi oleh Admin'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isVerified ? Colors.green : (isRejected ? Colors.red : Colors.blue),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Foto Carousel (PageView agar bisa digeser per-halaman)
              if (listPhotos.isNotEmpty)
                SizedBox(
                  height: 240,
                  child: PageView.builder(
                    itemCount: listPhotos.length,
                    controller: PageController(viewportFraction: 0.9),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            listPhotos[index],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image)),
                          ),
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('Tidak ada gambar lampiran')),
                ),
              
              const SizedBox(height: 24),
              
              Text(
                guruName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: MainColor.primaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                className,
                style: TextStyle(fontSize: 18, color: MainColor.primaryColor, fontWeight: FontWeight.bold, fontFamily: GoogleFonts.poppins().fontFamily),
              ),
              Text(
                subject,
                style: TextStyle(fontSize: 15, color: MainColor.secondaryText, fontFamily: GoogleFonts.poppins().fontFamily),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: MainColor.primaryColor),
                  const SizedBox(width: 10),
                  Text(dateStr, style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily)),
                  const SizedBox(width: 30),
                  Icon(Icons.access_time, size: 18, color: MainColor.primaryColor),
                  const SizedBox(width: 10),
                  Text(jamStr, style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily)),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 20),
              
              _buildSectionTitle('Materi Pembelajaran'),
              Text(data['materi'] ?? '-', style: const TextStyle(height: 1.5)),
              const SizedBox(height: 20),

              _buildSectionTitle('Catatan Guru'),
              Text(data['catatan'] ?? 'Tidak ada catatan tambahan', style: const TextStyle(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 24),

              // Absensi Section
              _buildSectionTitle('Rekap Absensi (S, I, A)'),
              const SizedBox(height: 12),
              Row(
                children: [
                   _buildAbsenChip('Sakit', sakitCount, Colors.orange),
                   const SizedBox(width: 12),
                   _buildAbsenChip('Izin', izinCount, Colors.blue),
                   const SizedBox(width: 12),
                   _buildAbsenChip('Alpha', alphaCount, Colors.red),
                ],
              ),
              const SizedBox(height: 20),

              // Daftar Nama Siswa
              if (presensi.isNotEmpty) ...[
                Text(
                  'Daftar Siswa Tidak Hadir:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontFamily: GoogleFonts.poppins().fontFamily),
                ),
                const SizedBox(height: 12),
                ...presensi.map((p) {
                   final s = p['master_siswa'] ?? {};
                   final String sName = s['nama_siswa'] ?? 'Siswa Tidak Ditemukan';
                   final String sStatus = p['status'].toString();
                   Color sColor = sStatus.startsWith('S') ? Colors.orange : (sStatus.startsWith('I') ? Colors.blue : Colors.red);
                   
                   return Container(
                     margin: const EdgeInsets.only(bottom: 8),
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
                     child: Row(
                       children: [
                         Container(width: 12, height: 12, decoration: BoxDecoration(color: sColor, shape: BoxShape.circle)),
                         const SizedBox(width: 12),
                         Expanded(child: Text(sName, style: const TextStyle(fontWeight: FontWeight.w500))),
                         Text(sStatus, style: TextStyle(fontWeight: FontWeight.bold, color: sColor)),
                       ],
                     ),
                   );
                }),
              ] else
                const Text('Seluruh siswa hadir.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),

              const SizedBox(height: 40),

              if (!isVerified)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MainColor.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
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
                    child: const Text('Edit Jurnal', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: MainColor.primaryText,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          fontFamily: GoogleFonts.poppins().fontFamily,
        ),
      ),
    );
  }

  Widget _buildAbsenChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }
}
