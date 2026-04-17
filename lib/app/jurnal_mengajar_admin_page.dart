import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class JurnalMengajarAdminController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;

  var selectedDate = DateTime.now().obs;
  var journals = [].obs;
  var filteredJournals = [].obs;
  var showPendingOnly = false.obs;
  var searchQuery = "".obs;

  JurnalMengajarAdminController({
    DateTime? initialDate,
    bool pendingOnly = false,
  }) {
    if (initialDate != null) {
      selectedDate.value = initialDate;
    }
    showPendingOnly.value = pendingOnly;

    debounce(
      searchQuery,
      (_) => filterLocal(),
      time: const Duration(milliseconds: 300),
    );
  }

  @override
  void onInit() {
    super.onInit();
    fetchDataByDate(selectedDate.value);
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
    fetchDataByDate(date);
  }

  Future<void> fetchDataByDate(DateTime date) async {
    isLoading.value = true;
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // Mengambil data jurnal dengan join presensi_siswa secara mendalam
      final response = await supabase
          .from('jurnal_harian')
          .select('''
            *,
            presensi_siswa (
              *,
              master_siswa (
                nama_siswa
              )
            ),
            jadwal:jadwal_mengajar!inner (
              *,
              profiles:guru_id (nama_lengkap, foto_url),
              master_kelas (nama_kelas),
              master_mata_pelajaran (nama_mata_pelajaran),
              master_jam (*)
            ),
            validated_by_profile:profiles!validated_by (nama_lengkap)
          ''')
          .eq('tanggal', dateStr)
          .order('created_at', ascending: false);

      // Grouping Journals for Admin view
      List<Map<String, dynamic>> distinctJournals = [];
      for (var j in response) {
        final jMap = Map<String, dynamic>.from(j);
        final jadwal = jMap['jadwal'];

        bool isDuplicate = false;
        for (var existing in distinctJournals) {
          final existingJadwal = existing['jadwal'];
          // Group by Guru, Kelas, Mapel, Materi, Tanggal
          if (existingJadwal['guru_id'] == jadwal['guru_id'] &&
              existingJadwal['kelas_id'] == jadwal['kelas_id'] &&
              existingJadwal['mata_pelajaran_id'] ==
                  jadwal['mata_pelajaran_id'] &&
              existing['materi'] == jMap['materi'] &&
              existing['tanggal'] == jMap['tanggal']) {
            isDuplicate = true;
            // Add ID to group
            if (existing['group_ids'] == null) {
              existing['group_ids'] = [existing['id']];
            }
            existing['group_ids'].add(jMap['id']);
            break;
          }
        }

        if (!isDuplicate) {
          jMap['group_ids'] = [jMap['id']];
          distinctJournals.add(jMap);
        }
      }

      if (showPendingOnly.value) {
        journals.assignAll(
          distinctJournals.where((j) => j['status'] == 'pending').toList(),
        );
      } else {
        journals.assignAll(distinctJournals);
      }
      filterLocal();
    } catch (e) {
      print('Fetch Data Admin Error: $e');
      Get.snackbar('Error', 'Gagal memuat data jurnal: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void filterLocal() {
    if (searchQuery.isEmpty) {
      filteredJournals.assignAll(journals);
    } else {
      final query = searchQuery.value.toLowerCase();
      filteredJournals.assignAll(
        journals.where((j) {
          final materi = (j['materi'] ?? "").toString().toLowerCase();
          final catatan = (j['catatan'] ?? "").toString().toLowerCase();
          final guru = (j['jadwal']?['profiles']?['nama_lengkap'] ?? "")
              .toString()
              .toLowerCase();
          final mapel =
              (j['jadwal']?['master_mata_pelajaran']?['nama_mata_pelajaran'] ??
                      "")
                  .toString()
                  .toLowerCase();
          final kelas = (j['jadwal']?['master_kelas']?['nama_kelas'] ?? "")
              .toString()
              .toLowerCase();
          return materi.contains(query) ||
              catatan.contains(query) ||
              guru.contains(query) ||
              mapel.contains(query) ||
              kelas.contains(query);
        }).toList(),
      );
    }
  }

  Future<void> validateJurnal(
    List<int> ids,
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
          .filter('id', 'in', ids);

      await fetchDataByDate(selectedDate.value);
      Get.snackbar('Berhasil', 'Status jurnal diperbarui menjadi $status');
    } catch (e) {
      Get.snackbar('Gagal', 'Gagal memperbarui jurnal: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class JurnalMengajarAdminPage extends StatelessWidget {
  final DateTime? initialDate;
  final bool showPendingOnly;

  const JurnalMengajarAdminPage({
    super.key,
    this.initialDate,
    this.showPendingOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      JurnalMengajarAdminController(
        initialDate: initialDate,
        pendingOnly: showPendingOnly,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Jurnal Mengajar',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          _buildHorizontalCalendar(controller),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
            child: Divider(thickness: 1, color: Color(0xFFEEDBCB)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              onChanged: (val) => controller.searchQuery.value = val,
              decoration: InputDecoration(
                hintText: 'Cari guru, materi, ksl...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                fillColor: MainColor.primaryBackground,
                filled: true,
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              if (controller.filteredJournals.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_late_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak ada data jurnal hari ini',
                        style: TextStyle(color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                );
              }
              return RefreshIndicator(
                onRefresh: () =>
                    controller.fetchDataByDate(controller.selectedDate.value),
                child: ListView.builder(
                  itemCount: controller.filteredJournals.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final j = controller.filteredJournals[index];
                    return _buildJurnalCard(context, j, controller);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(JurnalMengajarAdminController controller) {
    return Obx(() {
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
          const SizedBox(height: 12),
        ],
      );
    });
  }

  Widget _buildJurnalCard(
    BuildContext context,
    Map<String, dynamic> j,
    JurnalMengajarAdminController controller,
  ) {
    final schedule = j['jadwal'] ?? {};
    final guru = schedule['profiles'] ?? {};
    final guruName = (guru['nama_lengkap'] ?? '-').toString();
    final status = (j['status'] ?? 'pending').toString().toLowerCase();

    Color cardBg;
    Color textColor;
    Color subTextColor;
    Color labelBg;
    Color labelText;

    if (status == 'approved' || status == 'disetujui') {
      cardBg = const Color(0xFFF5F5F5); // Abu-abu halus
      textColor = MainColor.primaryText;
      subTextColor = Colors.grey.shade600;
      labelBg = Colors.green.withOpacity(0.1);
      labelText = Colors.green;
    } else if (status == 'rejected') {
      cardBg = const Color(0xFFFFF3E0); // Orange halus
      textColor = const Color(0xFFE65100);
      subTextColor = const Color(0xFFEF6C00).withOpacity(0.7);
      labelBg = const Color(0xFFE65100).withOpacity(0.1);
      labelText = const Color(0xFFE65100);
    } else {
      // PENDING
      cardBg = MainColor.accentColor; // Biru
      textColor = Colors.white;
      subTextColor = Colors.white.withOpacity(0.8);
      labelBg = Colors.white.withOpacity(0.2);
      labelText = Colors.white;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: (status == 'approved' || status == 'disetujui')
            ? Border.all(color: Colors.grey.shade300)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showDetailSheet(context, j, controller),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(
                    guru['foto_url'] ??
                        'https://ui-avatars.com/api/?name=$guruName&background=random',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              guruName,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: labelBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                color: labelText,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${schedule['master_kelas']?['nama_kelas'] ?? '-'} • ${schedule['master_mata_pelajaran']?['nama_mata_pelajaran'] ?? '-'}",
                        style: TextStyle(
                          color: textColor.withOpacity(0.9),
                          fontSize: 13,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Builder(
                        builder: (context) {
                          final List presensi =
                              j['presensi_siswa'] as List? ?? [];
                          int sCount = presensi
                              .where(
                                (p) => p['status']
                                    .toString()
                                    .toUpperCase()
                                    .startsWith('S'),
                              )
                              .length;
                          int iCount = presensi
                              .where(
                                (p) => p['status']
                                    .toString()
                                    .toUpperCase()
                                    .startsWith('I'),
                              )
                              .length;
                          int aCount = presensi
                              .where(
                                (p) => p['status']
                                    .toString()
                                    .toUpperCase()
                                    .startsWith('A'),
                              )
                              .length;
                          return Text(
                            "Ketidakhadiran - S:$sCount I:$iCount A:$aCount",
                            style: TextStyle(
                              fontSize: 11,
                              color: subTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(
    BuildContext context,
    Map<String, dynamic> j,
    JurnalMengajarAdminController controller,
  ) {
    final schedule = j['jadwal'] ?? {};
    final guru = schedule['profiles'] ?? {};
    final List presensi = j['presensi_siswa'] as List? ?? [];

    // Parse foto lampiran
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
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
          ),
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

                // CAROUSEL FOTO
                if (photoList.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoList.length,
                      itemBuilder: (context, idx) {
                        return Container(
                          width: 300,
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

                // ABSENSI SUMMARY
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

                // LIST DETAIL SISWA
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

                // ACTION BUTTONS
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
                              List<int>.from(j['group_ids'] ?? [j['id']]),
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
                              List<int>.from(j['group_ids'] ?? [j['id']]),
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
                      color: j['status'] == 'approved'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      j['status'] == 'approved'
                          ? "Sudah Disetujui"
                          : "Ditolak: ${j['catatan_admin'] ?? '-'}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: j['status'] == 'approved'
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
