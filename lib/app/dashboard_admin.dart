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

  @override
  void onInit() {
    super.onInit();
    fetchStats(selectedDate.value);
  }

  void changeDate(DateTime date) {
    selectedDate.value = date;
    fetchStats(date);
  }

  Future<void> fetchStats(DateTime date) async {
    isLoading.value = true;
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      // Get all jadwal for the date
      final resJadwal = await supabase
          .from('jadwal_mengajar')
          .select('id')
          .eq('tanggal', dateStr)
          .eq('is_active', true);
      
      totalJadwal.value = resJadwal.length;

      // Get all jurnal entries for these jadwal
      final resJurnal = await supabase
          .from('jurnal_harian')
          .select()
          .eq('tanggal', dateStr);
          
      totalJurnal.value = resJurnal.length;
      
      totalApproved.value = resJurnal.where((j) => j['status'] == 'approved' || j['is_verified'] == true).length;
      
      totalBelumInput.value = totalJadwal.value - totalJurnal.value;
      if (totalBelumInput.value < 0) totalBelumInput.value = 0;

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
                  Text(
                    'Administrator',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
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
            CircleAvatar(
              backgroundColor: MainColor.primaryBackground,
              child: Icon(Icons.person, color: MainColor.primaryColor),
            )
          ],
        ),
      ),
      drawer: const DrawerAdmin(),
      body: SingleChildScrollView(
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
            ),
          ],
        ),
      ),
    );
  }
}

