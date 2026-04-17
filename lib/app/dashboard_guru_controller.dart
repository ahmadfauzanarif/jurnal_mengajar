import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardGuruController extends GetxController {
  final supabase = Supabase.instance.client;

  var isLoading = true.obs;
  var userProfile = {}.obs;
  var selectedDate = DateTime.now().obs;
  
  // List of maps for schedules and journals
  var schedules = [].obs;
  var groupedSchedules = <List<Map<String, dynamic>>>[].obs;
  var journals = [].obs;

  @override
  void onInit() {
    super.onInit();
    fetchInitialData();
  }

  Future<void> fetchInitialData() async {
    isLoading.value = true;
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Fetch profile
        final profileRes = await supabase
            .from('profiles')
            .select()
            .eq('id', user.id)
            .single();
        userProfile.value = profileRes;

        await fetchDataByDate(selectedDate.value);
      }
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchDataByDate(DateTime date) async {
    selectedDate.value = date;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    isLoading.value = true;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      // Fetch schedules
      // Need to find if a journal exists to determine status (blue vs grey)
      final scheduleRes = await supabase
          .from('jadwal_mengajar')
          .select('*, master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*), jurnal_harian(id, status)')
          .eq('guru_id', user.id)
          .eq('tanggal', dateStr)
          .eq('is_active', true)
          .order('jam_id', ascending: true);

      schedules.value = scheduleRes;

      // Group consecutive schedules with same kelas_id + mata_pelajaran_id
      List<List<Map<String, dynamic>>> groups = [];
      for (var s in scheduleRes) {
        final sMap = Map<String, dynamic>.from(s);
        if (groups.isNotEmpty) {
          final lastGroup = groups.last;
          final lastItem = lastGroup.last;
          if (lastItem['kelas_id'] == sMap['kelas_id'] &&
              lastItem['mata_pelajaran_id'] == sMap['mata_pelajaran_id']) {
            lastGroup.add(sMap);
            continue;
          }
        }
        groups.add([sMap]);
      }
      groupedSchedules.value = groups;

      final journalRes = await supabase
          .from('jurnal_harian')
          .select('*, presensi_siswa(*), jadwal_mengajar!inner(*, master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*))')
          .eq('jadwal_mengajar.guru_id', user.id)
          .eq('tanggal', dateStr);

      // Grouping Journals to prevent duplicates for consecutive periods
      List<Map<String, dynamic>> distinctJournals = [];
      for (var j in journalRes) {
        final jMap = Map<String, dynamic>.from(j);
        final jadwal = jMap['jadwal_mengajar'];
        
        bool isDuplicate = false;
        for (var existing in distinctJournals) {
          final existingJadwal = existing['jadwal_mengajar'];
          if (existingJadwal['kelas_id'] == jadwal['kelas_id'] &&
              existingJadwal['mata_pelajaran_id'] == jadwal['mata_pelajaran_id'] &&
              existing['tanggal'] == jMap['tanggal']) {
            isDuplicate = true;
            break;
          }
        }
        
        if (!isDuplicate) {
          distinctJournals.add(jMap);
        }
      }

      journals.value = distinctJournals;
    } catch (e) {
      print('Fetch Data Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void changeDate(DateTime date) {
    fetchDataByDate(date);
  }
}
