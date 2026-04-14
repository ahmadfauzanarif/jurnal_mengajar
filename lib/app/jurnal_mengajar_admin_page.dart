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

  JurnalMengajarAdminController({DateTime? initialDate, bool pendingOnly = false}) {
    if (initialDate != null) {
      selectedDate.value = initialDate;
    }
    showPendingOnly.value = pendingOnly;

    // Listen to search query change to filter locally
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
      
      final response = await supabase
          .from('jurnal_harian')
          .select('*, jadwal:jadwal_mengajar!inner(*, profiles:guru_id(nama_lengkap,foto_url), master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*)), profiles:validated_by(nama_lengkap)')
          .eq('tanggal', dateStr);
          
      if (showPendingOnly.value) {
        journals.assignAll(response
            .where((j) =>
                j['status'] != 'approved' && j['is_verified'] != true)
            .toList());
      } else {
        journals.assignAll(response);
      }
      filterLocal();
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void filterLocal() {
    if (searchQuery.isEmpty) {
      filteredJournals.assignAll(journals);
    } else {
      final query = searchQuery.value.toLowerCase();
      filteredJournals.assignAll(journals.where((j) {
        final materi = (j['materi'] ?? "").toString().toLowerCase();
        final catatan = (j['catatan'] ?? "").toString().toLowerCase();
        final guru = (j['jadwal']?['profiles']?['nama_lengkap'] ?? "")
            .toString()
            .toLowerCase();
        final mapel = (j['jadwal']?['master_mata_pelajaran']
                    ?['nama_mata_pelajaran'] ??
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
      }).toList());
    }
  }

  Future<void> validateJurnal(int id, String status) async {
    isLoading.value = true;
    try {
      // Assuming 'status' is either 'approved' or 'rejected', and 'validated_by'
      // Based on UI screenshot, validation flips it to checked, but let's use status or is_verified boolean
      // Let's assume table has 'status' (pending, approved, rejected) or 'is_verified' (bool)
      // I will update status. Since Postman mentioned "status": "pending", let's use 'status': 'approved'.
      
      final userId = supabase.auth.currentUser?.id;
      
      await supabase.from('jurnal_harian').update({
        'status': status,
        'validated_by': userId,
      }).eq('id', id);
      
      await fetchDataByDate(selectedDate.value);
      Get.snackbar('Sukses', 'Jurnal berhasil $status');
    } catch (e) {
      Get.snackbar('Error', 'Gagal memvalidasi jurnal: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class JurnalMengajarAdminPage extends StatelessWidget {
  final DateTime? initialDate;
  final bool showPendingOnly;

  const JurnalMengajarAdminPage({super.key, this.initialDate, this.showPendingOnly = false});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(JurnalMengajarAdminController(initialDate: initialDate, pendingOnly: showPendingOnly));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Jurnal Mengajar',
          style: TextStyle(
            color: Colors.white,
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
                hintText: 'Cari Guru, Materi, Mapel, atau Kelas...',
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
                return const Center(child: Text('Tidak ada jurnal ditemukan'));
              }

              return ListView.builder(
                itemCount: controller.filteredJournals.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final j = controller.filteredJournals[index];
                  return _buildJurnalCard(context, j, controller);
                },
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
                  icon: Icon(Icons.arrow_back_ios, size: 18, color: MainColor.primaryColor),
                  onPressed: () => controller.changeDate(controller.selectedDate.value.subtract(const Duration(days: 1))),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(controller.selectedDate.value),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: MainColor.primaryColor,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 18, color: MainColor.primaryColor),
                  onPressed: () => controller.changeDate(controller.selectedDate.value.add(const Duration(days: 1))),
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
                bool isSelected = DateFormat('yyyy-MM-dd').format(day) ==
                    DateFormat('yyyy-MM-dd').format(controller.selectedDate.value);

                return Expanded(
                  child: GestureDetector(
                    onTap: () => controller.changeDate(day),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? MainColor.primaryColor : Colors.transparent,
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
                              color: isSelected ? Colors.white : MainColor.primaryText,
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
    });
  }

  Widget _buildJurnalCard(BuildContext context, Map<String, dynamic> j, JurnalMengajarAdminController controller) {
    final schedule = j['jadwal'] ?? {};
    final guru = schedule['profiles'] ?? {};
    final kelas = schedule['master_kelas'] != null ? schedule['master_kelas']['nama_kelas'] : '-';
    final mapel = schedule['master_mata_pelajaran'] != null ? schedule['master_mata_pelajaran']['nama_mata_pelajaran'] : '-';
    final String guruName = guru['nama_lengkap'] ?? '-';
    
    // Status Logic
    bool isValidated = j['status'] == 'approved' || j['is_verified'] == true;
    bool isLate = j['istelat'] == true; // from user requirement

    Color bgColor = isValidated ? MainColor.validateColor : MainColor.secondaryColor;
    if (isLate && !isValidated) {
      // Late styling. User said "warna khusus" when late filling
      bgColor = Colors.redAccent.shade100;
    }

    Color textColor = isValidated ? MainColor.secondaryText : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: isLate ? Border.all(color: Colors.red, width: 1.5) : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // Show Detail Sheet for Validation
            _showDetailSheet(context, j, controller);
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundImage: NetworkImage(
                    guru['foto_url'] != null && guru['foto_url'].isNotEmpty
                        ? guru['foto_url']
                        : 'https://ui-avatars.com/api/?name=$guruName&background=random',
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
                                color: isValidated ? MainColor.primaryColor : Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.check_circle,
                            color: isValidated ? MainColor.sudahValidasiCheckColor : Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        kelas,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      Text(
                        mapel,
                        style: TextStyle(
                          color: isValidated ? MainColor.secondaryText : Colors.white70,
                          fontSize: 12,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      if (isLate) 
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            'Telat Mengisi',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              fontStyle: FontStyle.italic
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  color: isValidated ? MainColor.secondaryText : Colors.white,
                  size: 16,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDetailSheet(BuildContext context, Map<String, dynamic> j, JurnalMengajarAdminController controller) {
    final schedule = j['jadwal'] ?? {};
    final jam = schedule['master_jam'] ?? {};
    final guru = schedule['profiles'] ?? {};
    final mapel = schedule['master_mata_pelajaran'] != null ? schedule['master_mata_pelajaran']['nama_mata_pelajaran'] : '-';
    final kelas = schedule['master_kelas'] != null ? schedule['master_kelas']['nama_kelas'] : '-';
    
    // Default attendance placeholder or decode if exists
    final sakit = j['sakit'] ?? 0;
    final izin = j['izin'] ?? 0;
    final alpha = j['alpha'] ?? 0;

    bool isValidated = j['status'] == 'approved' || j['is_verified'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.85,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Image
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.grey.shade200,
                  image: j['foto_url'] != null 
                    ? DecorationImage(
                        image: NetworkImage(j['foto_url']),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: j['foto_url'] == null 
                  ? const Center(child: Icon(Icons.image, size: 50, color: Colors.grey))
                  : null,
              ),
              const SizedBox(height: 16),
              
              Text(
                guru['nama_lengkap'] ?? '-',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: MainColor.primaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              Text(
                kelas,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: MainColor.primaryColor,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              Text(
                mapel,
                style: TextStyle(
                  fontSize: 14,
                  color: MainColor.secondaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: MainColor.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(DateTime.parse(j['tanggal'])),
                    style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily)
                  ),
                  const SizedBox(width: 24),
                  Icon(Icons.access_time, size: 16, color: MainColor.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    jam['waktu_reguler'] ?? '-',
                    style: TextStyle(fontFamily: GoogleFonts.poppins().fontFamily)
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: MainColor.validateColor),
              const SizedBox(height: 12),
              
              Text(
                'Materi: ${j['materi'] ?? '-'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: MainColor.primaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                j['catatan'] ?? 'Tidak ada catatan tambahan',
                style: TextStyle(
                  color: MainColor.secondaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 24),

              // Attendance
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildAbsenBox('Sakit', sakit.toString()),
                  _buildAbsenBox('Izin', izin.toString()),
                  _buildAbsenBox('Alpha', alpha.toString(), isOutline: true),
                ],
              ),
              const Spacer(),

              if (!isValidated)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: MainColor.accentColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Get.back();
                      controller.validateJurnal(j['id'], 'approved');
                    },
                    child: Text(
                      'Validasi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    color: MainColor.sudahValidasiCheckColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15)
                  ),
                  child: Center(
                    child: Text(
                      'Sudah Divalidasi',
                      style: TextStyle(
                        color: MainColor.sudahValidasiCheckColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildAbsenBox(String title, String count, {bool isOutline = false}) {
    return Container(
      width: 70,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isOutline ? Colors.white : MainColor.alternateColor,
        borderRadius: BorderRadius.circular(10),
        border: isOutline ? Border.all(color: MainColor.primaryColor, width: 2) : null,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: MainColor.primaryText,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: TextStyle(
              color: MainColor.primaryColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
