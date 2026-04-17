import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/drawer_admin.dart';
import 'package:jurnal_mengajar/app/jadwal_mengajar_admin_page.dart';
import 'package:jurnal_mengajar/app/jurnal_mengajar_admin_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class DashboardAdminController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;
  
  var selectedDate = DateTime.now().obs;
  
  var totalJadwal = 0.obs;
  var totalJurnal = 0.obs;
  var totalApproved = 0.obs;
  var totalBelumInput = 0.obs;
  
  var userName = 'Administrator'.obs;
  var userProfileUrl = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUserProfile();
    fetchStats(selectedDate.value);
  }

  Future<void> fetchUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final res = await supabase
            .from('profiles')
            .select('nama_lengkap, foto_url')
            .eq('id', user.id)
            .single();
        
        userName.value = res['nama_lengkap'] ?? 'Administrator';
        userProfileUrl.value = res['foto_url'] ?? '';
      }
    } catch (e) {
      print('Failed to fetch admin profile: $e');
    }
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
    fetchStats(date);
  }

  Future<void> fetchStats(DateTime date) async {
    isLoading.value = true;
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);

      // 1. Get all jadwal for the date with necessary fields for grouping
      final resJadwal = await supabase
          .from('jadwal_mengajar')
          .select('guru_id, kelas_id, mata_pelajaran_id')
          .eq('tanggal', dateStr)
          .eq('is_active', true);

      // Group jadwal by Guru, Kelas, Mapel
      Set<String> groupedJadwalKeys = {};
      for (var s in resJadwal) {
        String key =
            "${s['guru_id']}_${s['kelas_id']}_${s['mata_pelajaran_id']}";
        groupedJadwalKeys.add(key);
      }
      totalJadwal.value = groupedJadwalKeys.length;

      // 2. Get all jurnal entries joined with jadwal for grouping
      final resJurnal = await supabase
          .from('jurnal_harian')
          .select(
            'status, jadwal:jadwal_mengajar!inner(guru_id, kelas_id, mata_pelajaran_id)',
          )
          .eq('tanggal', dateStr);

      // Group jurnal by Guru, Kelas, Mapel
      Map<String, String> groupedJurnalStatus = {};
      for (var j in resJurnal) {
        final jMap = j as Map<String, dynamic>;
        final jadwal = jMap['jadwal'] as Map<String, dynamic>;
        String key =
            "${jadwal['guru_id']}_${jadwal['kelas_id']}_${jadwal['mata_pelajaran_id']}";
        // Map key to status.
        groupedJurnalStatus[key] = jMap['status']?.toString() ?? 'pending';
      }

      totalJurnal.value = groupedJurnalStatus.length;

      // 3. Approval count based on grouped sessions
      // We count sessions that are 'pending' or 'menunggu'
      int pendingCount = groupedJurnalStatus.values
          .where((status) =>
              status.toLowerCase() == 'pending' ||
              status.toLowerCase() == 'menunggu')
          .length;
      totalApproved.value = pendingCount;

      // 4. Belum Input
      int belumInputCount = totalJadwal.value - totalJurnal.value;
      totalBelumInput.value = belumInputCount < 0 ? 0 : belumInputCount;
    } catch (e) {
      print('Failed to fetch dashboard stats: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class DashboardAdmin extends StatelessWidget {
  const DashboardAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardAdminController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Obx(() => Text(
                    controller.userName.value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )),
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              final String name = controller.userName.value;
              final String? photoUrl = controller.userProfileUrl.value.isNotEmpty ? controller.userProfileUrl.value : null;
              final String fallbackUrl = "https://ui-avatars.com/api/?name=${Uri.encodeComponent(name)}&background=4A8BCE&color=fff";
              
              return CircleAvatar(
                backgroundColor: MainColor.primaryBackground,
                backgroundImage: NetworkImage(photoUrl ?? fallbackUrl),
              );
            })
          ],
        ),
      ),
      drawer: const DrawerAdmin(),
      body: RefreshIndicator(
        onRefresh: () async {
          await controller.fetchStats(controller.selectedDate.value);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildCalendarHeader(controller),
              Obx(() {
                if (controller.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildStatCard(
                        controller.totalJadwal.value.toString(), 
                        'Jadwal',
                        onTap: () {
                          Get.delete<JadwalMengajarAdminController>();
                          Get.to(() => JadwalMengajarAdminPage(initialDate: controller.selectedDate.value));
                        },
                      ),
                      _buildStatCard(
                        controller.totalJurnal.value.toString(), 
                        'Jurnal',
                        onTap: () {
                          Get.delete<JurnalMengajarAdminController>();
                          Get.to(() => JurnalMengajarAdminPage(initialDate: controller.selectedDate.value));
                        },
                      ),
                      _buildStatCard(
                        controller.totalApproved.value.toString(), 
                        'Approval',
                        onTap: () {
                          Get.delete<JurnalMengajarAdminController>();
                          Get.to(() => JurnalMengajarAdminPage(initialDate: controller.selectedDate.value, showPendingOnly: true));
                        },
                      ),
                      _buildStatCard(
                        controller.totalBelumInput.value.toString(), 
                        'Belum Input',
                        onTap: () {
                          Get.delete<JadwalMengajarAdminController>();
                          Get.to(() => JadwalMengajarAdminPage(initialDate: controller.selectedDate.value, showBelumInputOnly: true));
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(DashboardAdminController controller) {
    return Obx(() {
      DateTime now = controller.selectedDate.value;
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday % 7));
      
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 18, color: MainColor.primaryColor),
                  onPressed: () => controller.changeDate(controller.selectedDate.value.subtract(const Duration(days: 1))),
                ),
                Text(
                  DateFormat('MMMM yyyy', 'id_ID').format(controller.selectedDate.value),
                  style: TextStyle(
                    fontSize: 20,
                    color: MainColor.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 18, color: MainColor.primaryColor),
                  onPressed: () => controller.changeDate(controller.selectedDate.value.add(const Duration(days: 1))),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 0.0),
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
                                fontWeight: FontWeight.w600,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              day.day.toString(),
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.grey[700],
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
        ),
      );
    });
  }

  Widget _buildStatCard(String number, String title, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF4A8BCE),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              number,
              style: TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.bold,
                fontFamily: GoogleFonts.poppins().fontFamily,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFFFDEBCA),
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

