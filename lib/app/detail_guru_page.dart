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
      // Fetch Schedule
      final scheduleRes = await supabase
          .from('jadwal_mengajar')
          .select(
            '*, master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*)',
          )
          .eq('guru_id', guruId)
          .eq('tanggal', dateStr)
          .eq('is_active', true);
      schedules.value = scheduleRes;

      // Fetch Journals
      final journalRes = await supabase
          .from('jurnal_harian')
          .select(
            '*, jadwal:jadwal_mengajar!inner(*, master_kelas(*), master_mata_pelajaran(*), master_jam(*))',
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
              _buildScheduleList(controller),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Divider(thickness: 1, color: Color(0xFFEEDBCB)),
              ),
              _buildJournalList(controller),
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

  Widget _buildScheduleList(DetailGuruController controller) {
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
            ...controller.schedules.map((s) => _buildScheduleCard(s)),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map s) {
    final jam = s['master_jam'] ?? {};
    final kelas = s['master_kelas'] != null
        ? s['master_kelas']['nama_kelas']
        : '-';
    final mapel = s['master_mata_pelajaran'] != null
        ? s['master_mata_pelajaran']['nama_mata_pelajaran']
        : '-';

    String timeRange = jam['waktu_reguler'] ?? '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MainColor.secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        title: Text(
          '$timeRange   $kelas',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(mapel, style: const TextStyle(color: Colors.white70)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white,
          size: 16,
        ),
      ),
    );
  }

  Widget _buildJournalList(DetailGuruController controller) {
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
            ...controller.journals.map((j) => _buildJournalCard(j)),
        ],
      ),
    );
  }

  Widget _buildJournalCard(Map j) {
    final schedule = j['jadwal'] ?? {};
    final bool isValidated = j['is_verified'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isValidated ? MainColor.validateColor : MainColor.secondaryColor,
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
                    color: isValidated
                        ? MainColor.secondaryColor
                        : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                Text(
                  schedule['master_mata_pelajaran'] != null
                      ? schedule['master_mata_pelajaran']['nama_mata_pelajaran']
                      : '-',
                  style: TextStyle(
                    color: isValidated
                        ? MainColor.secondaryColor.withOpacity(0.7)
                        : Colors.white70,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                'S:1 I:0 A:1', // Static placeholder as per design
                style: TextStyle(
                  color: isValidated ? MainColor.secondaryColor : Colors.white,
                  fontSize: 12,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.check_circle,
                color: isValidated ? Colors.green : Colors.white70,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
