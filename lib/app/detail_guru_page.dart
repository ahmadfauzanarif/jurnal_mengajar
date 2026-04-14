import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class DetailGuruController extends GetxController {
  final String guruId;
  final supabase = Supabase.instance.client;

  var isLoading = false.obs;
  var guruProfile = {}.obs;
  var selectedDate = DateTime.now().obs;
  var schedules = [].obs;
  var journals = [].obs;

  DetailGuruController(this.guruId);

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      // 1. Fetch Profile
      final profileRes = await supabase
          .from('profiles')
          .select()
          .eq('id', guruId)
          .single();
      guruProfile.value = profileRes;

      // 2. Fetch Data for selected date
      await fetchDataByDate(selectedDate.value);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchDataByDate(DateTime date) async {
    selectedDate.value = date;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    try {
      // Fetch Schedule including journal status
      final scheduleRes = await supabase
          .from('jadwal_mengajar')
          .select(
            '*, master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*), jurnal_harian(id, status)',
          )
          .eq('guru_id', guruId)
          .eq('tanggal', dateStr)
          .eq('is_active', true);
      schedules.value = scheduleRes;

      // Fetch Journals including attendance
      final journalRes = await supabase
          .from('jurnal_harian')
          .select(
            '*, presensi_siswa(*), jadwal:jadwal_mengajar!inner(*, master_kelas(*), master_mata_pelajaran(*), master_jam(*))',
          )
          .eq('jadwal.guru_id', guruId)
          .eq('tanggal', dateStr);

      journals.value = journalRes;
    } catch (e) {
      print('Fetch Error: $e');
    }
  }

  void changeDate(DateTime date) {
    fetchDataByDate(date);
  }

  Future<void> validateJurnal(
    int id,
    String status, {
    String? catatanAdmin,
  }) async {
    isLoading.value = true;
    try {
      final userId = supabase.auth.currentUser?.id;
      await supabase
          .from('jurnal_harian')
          .update({
            'status': status,
            'validated_by': userId,
            'validated_at': DateTime.now().toIso8601String(),
            'catatan_admin': catatanAdmin,
          })
          .eq('id', id);

      await fetchDataByDate(selectedDate.value);
      Get.snackbar('Berhasil', 'Status jurnal diperbarui menjadi $status');
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal memperbarui jurnal: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class DetailGuruPage extends StatelessWidget {
  final String guruId;
  const DetailGuruPage({super.key, required this.guruId});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DetailGuruController(guruId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Detail Guru',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = controller.guruProfile;
        if (profile.isEmpty) {
          return const Center(child: Text('Data tidak ditemukan'));
        }

        return SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(profile),
              const SizedBox(height: 20),
              _buildHorizontalCalendar(controller),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Divider(thickness: 1, color: Color(0xFFEEDBCB)),
              ),
              _buildScheduleList(context, controller),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Divider(thickness: 1, color: Color(0xFFEEDBCB)),
              ),
              _buildJournalList(context, controller),
              const SizedBox(height: 30),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildHeader(Map profile) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundImage: NetworkImage(
              profile['foto_url'] != null && profile['foto_url'].isNotEmpty
                  ? profile['foto_url']
                  : 'https://ui-avatars.com/api/?name=${profile['nama_lengkap']}&background=random',
            ),
          ),
          const SizedBox(height: 16),
          Text(
            profile['nama_lengkap'] ?? '-',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.poppins().fontFamily,
              color: MainColor.primaryText,
            ),
          ),
          Text(
            profile['jabatan'] ?? '-',
            style: TextStyle(
              fontSize: 16,
              color: MainColor.secondaryText,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          Text(
            DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now()),
            style: TextStyle(
              fontStyle: FontStyle.italic,
              fontSize: 14,
              color: Colors.grey,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.phone, profile['no_telp'] ?? '-'),
          _buildInfoRow(Icons.email, profile['email'] ?? '-'),
          _buildInfoRow(Icons.location_on, profile['alamat'] ?? '-'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: MainColor.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: MainColor.primaryText,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(DetailGuruController controller) {
    // Current week representation
    DateTime now = controller.selectedDate.value;
    DateTime startOfWeek = now.subtract(Duration(days: now.weekday % 7));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: MainColor.primaryColor,
                ),
                onPressed: () => controller.changeDate(
                  controller.selectedDate.value.subtract(
                    const Duration(days: 1),
                  ),
                ),
              ),
              Text(
                DateFormat(
                  'MMMM yyyy',
                  'id_ID',
                ).format(controller.selectedDate.value),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MainColor.primaryColor,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: MainColor.primaryColor,
                ),
                onPressed: () => controller.changeDate(
                  controller.selectedDate.value.add(const Duration(days: 1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Row(
            children: List.generate(7, (index) {
              DateTime day = startOfWeek.add(Duration(days: index));
              bool isSelected =
                  DateFormat('yyyy-MM-dd').format(day) ==
                  DateFormat(
                    'yyyy-MM-dd',
                  ).format(controller.selectedDate.value);

              return Expanded(
                child: GestureDetector(
                  onTap: () => controller.changeDate(day),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? MainColor.primaryColor
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E', 'id_ID').format(day).toLowerCase(),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey,
                            fontSize: 12,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          day.day.toString(),
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : MainColor.primaryText,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleList(
    BuildContext context,
    DetailGuruController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jadwal Mengajar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          if (controller.schedules.isEmpty)
            const Text('Tidak ada jadwal hari ini')
          else
            ...controller.schedules.map(
              (s) => _buildScheduleCard(
                context,
                s as Map<String, dynamic>,
                controller,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(
    BuildContext context,
    Map<String, dynamic> s,
    DetailGuruController controller,
  ) {
    final jam = s['master_jam'] ?? {};
    final kelas = s['master_kelas'] != null
        ? s['master_kelas']['nama_kelas']
        : '-';
    final mapel = s['master_mata_pelajaran'] != null
        ? s['master_mata_pelajaran']['nama_mata_pelajaran']
        : '-';
    final journals = s['jurnal_harian'] as List? ?? [];
    final hasJournal = journals.isNotEmpty;
    final journalData = hasJournal ? journals[0] : null;
    final journalStatus = journalData != null ? journalData['status'] : null;

    String timeRange = jam['waktu_reguler'] ?? '-';

    Color bgColor = MainColor.secondaryColor;
    Color textColor = Colors.white;
    IconData icon = Icons.arrow_forward_ios;

    if (journalStatus == 'approved' || journalStatus == 'disetujui') {
      bgColor = MainColor.validateColor;
      textColor = MainColor.secondaryColor;
      icon = Icons.check_circle;
    } else if (journalStatus == 'rejected' || journalStatus == 'ditolak') {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      icon = Icons.cancel;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        onTap: () {
          if (hasJournal) {
            // Find full journal data from journals list or fetch it
            final j =
                controller.journals.firstWhereOrNull(
                      (j) => j['id'] == journalData['id'],
                    )
                    as Map<String, dynamic>?;
            if (j != null) {
              _showDetailSheet(context, j, controller);
            } else {
              Get.snackbar(
                'Info',
                'Mohon tunggu, sedang memuat detail jurnal...',
              );
            }
          } else {
            Get.snackbar('Info', 'Guru belum mengisi jurnal untuk jadwal ini.');
          }
        },
        title: Text(
          '$timeRange   $kelas',
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          mapel,
          style: TextStyle(color: textColor.withOpacity(0.7)),
        ),
        trailing: Icon(icon, color: textColor, size: 20),
      ),
    );
  }

  Widget _buildJournalList(
    BuildContext context,
    DetailGuruController controller,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Jurnal Mengajar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          const SizedBox(height: 12),
          if (controller.journals.isEmpty)
            const Text('Belum ada jurnal hari ini')
          else
            ...controller.journals.map(
              (j) => _buildJournalCard(
                context,
                j as Map<String, dynamic>,
                controller,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJournalCard(
    BuildContext context,
    Map<String, dynamic> j,
    DetailGuruController controller,
  ) {
    final schedule = j['jadwal'] ?? {};
    final String status = j['status'] ?? 'pending';
    final bool isApproved = status == 'approved' || status == 'disetujui';
    final bool isRejected = status == 'rejected' || status == 'ditolak';

    final List presensi = j['presensi_siswa'] as List? ?? [];
    int sCount = presensi
        .where((p) => p['status'].toString().toUpperCase().startsWith('S'))
        .length;
    int iCount = presensi
        .where((p) => p['status'].toString().toUpperCase().startsWith('I'))
        .length;
    int aCount = presensi
        .where((p) => p['status'].toString().toUpperCase().startsWith('A'))
        .length;
    String attendance = 'S:$sCount I:$iCount A:$aCount';

    Color bgColor = MainColor.secondaryColor;
    Color textColor = Colors.white;
    IconData icon = Icons.hourglass_empty;
    Color iconColor = Colors.white70;

    if (isApproved) {
      bgColor = MainColor.validateColor;
      textColor = MainColor.secondaryColor;
      icon = Icons.check_circle;
      iconColor = Colors.green;
    } else if (isRejected) {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      icon = Icons.cancel;
      iconColor = Colors.orange;
    }

    return GestureDetector(
      onTap: () => _showDetailSheet(context, j, controller),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule['master_kelas'] != null
                        ? schedule['master_kelas']['nama_kelas']
                        : '-',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                  Text(
                    schedule['master_mata_pelajaran'] != null
                        ? schedule['master_mata_pelajaran']['nama_mata_pelajaran']
                        : '-',
                    style: TextStyle(
                      color: textColor.withOpacity(0.7),
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                Text(
                  attendance,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(icon, color: iconColor, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    Map<String, dynamic> j,
    DetailGuruController controller,
  ) {
    final schedule = j['jadwal'] ?? {};
    final guru = controller.guruProfile;
    final List presensi = j['presensi_siswa'] as List? ?? [];

    final String photoStr = j['foto_lampiran_url']?.toString() ?? "";
    final List<String> photoList = photoStr.isNotEmpty
        ? photoStr.split(',').map((e) => e.trim()).toList()
        : [];

    final sakit = presensi
        .where((p) => p['status'].toString().toUpperCase().startsWith('S'))
        .toList();
    final izin = presensi
        .where((p) => p['status'].toString().toUpperCase().startsWith('I'))
        .toList();
    final alpha = presensi
        .where((p) => p['status'].toString().toUpperCase().startsWith('A'))
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final rejectNoteController = TextEditingController();
        return Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                if (photoList.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoList.length,
                      itemBuilder: (context, idx) {
                        return Container(
                          width: MediaQuery.of(context).size.width * 0.7,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(photoList[idx]),
                              fit: BoxFit.cover,
                            ),
                            color: Colors.grey.shade100,
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('Tidak ada foto lampiran')),
                  ),

                const SizedBox(height: 24),
                Text(
                  guru['nama_lengkap'] ?? '-',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "${schedule['master_kelas']?['nama_kelas'] ?? '-'} | ${schedule['master_mata_pelajaran']?['nama_mata_pelajaran'] ?? '-'}",
                  style: TextStyle(
                    color: MainColor.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                const Text(
                  'Materi Pembelajaran:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(j['materi'] ?? '-'),
                const SizedBox(height: 16),
                const Text(
                  'Catatan Guru:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  j['catatan'] ?? '-',
                  style: const TextStyle(color: Colors.grey),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatAbsen(
                      'SAKIT',
                      sakit.length.toString(),
                      Colors.orange,
                    ),
                    _buildStatAbsen(
                      'IZIN',
                      izin.length.toString(),
                      Colors.blue,
                    ),
                    _buildStatAbsen(
                      'ALPHA',
                      alpha.length.toString(),
                      Colors.red,
                    ),
                  ],
                ),

                const SizedBox(height: 24),
                const Text(
                  'Daftar Siswa Tidak Hadir:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (presensi.isEmpty)
                  const Text(
                    'Semua siswa hadir.',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  )
                else
                  ...presensi.map(
                    (p) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 4,
                        backgroundColor:
                            p['status'].toString().toUpperCase().startsWith('S')
                            ? Colors.orange
                            : (p['status'].toString().toUpperCase().startsWith(
                                    'I',
                                  )
                                  ? Colors.blue
                                  : Colors.red),
                      ),
                      title: Text(
                        p['master_siswa']?['nama_siswa'] ??
                            'Siswa Tidak Dikenal',
                        style: const TextStyle(fontSize: 14),
                      ),
                      trailing: Text(
                        p['status'].toString().toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                const SizedBox(height: 32),
                if (j['status'] == 'pending') ...[
                  TextField(
                    controller: rejectNoteController,
                    decoration: InputDecoration(
                      hintText:
                          'Tambahkan catatan admin (wajib jika ditolak)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            if (rejectNoteController.text.isEmpty) {
                              Get.snackbar(
                                'Gagal',
                                'Catatan wajib diisi untuk menolak',
                              );
                              return;
                            }
                            Get.back();
                            controller.validateJurnal(
                              j['id'],
                              'rejected',
                              catatanAdmin: rejectNoteController.text,
                            );
                          },
                          child: const Text(
                            'TOLAK',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            Get.back();
                            controller.validateJurnal(
                              j['id'],
                              'approved',
                              catatanAdmin: rejectNoteController.text,
                            );
                          },
                          child: const Text(
                            'SETUJUI',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                          (j['status'] == 'approved' ||
                              j['status'] == 'disetujui')
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      (j['status'] == 'approved' || j['status'] == 'disetujui')
                          ? "Sudah Disetujui"
                          : "Ditolak: ${j['catatan_admin'] ?? '-'}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            (j['status'] == 'approved' ||
                                j['status'] == 'disetujui')
                            ? Colors.green
                            : Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatAbsen(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.6),
          ),
        ),
      ],
    );
  }
}
