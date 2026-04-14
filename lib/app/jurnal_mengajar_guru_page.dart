import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jurnal_mengajar/app/form_jurnal_mengajar_guru_page.dart';
import 'package:jurnal_mengajar/app/detail_jurnal_mengajar_guru_page.dart';

class JurnalMengajarGuruController extends GetxController {
  final supabase = Supabase.instance.client;

  var isLoading = true.obs;
  var selectedDate = DateTime.now().obs;
  var journals = [].obs;

  @override
  void onInit() {
    super.onInit();
    fetchDataByDate(selectedDate.value);
  }

  Future<void> fetchDataByDate(DateTime date) async {
    selectedDate.value = date;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    isLoading.value = true;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      final journalRes = await supabase
          .from('jurnal_harian')
          .select('*, presensi_siswa(*), jadwal_mengajar!inner(*, master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(*)), profiles:validated_by(nama_lengkap)')
          .eq('jadwal_mengajar.guru_id', user.id)
          .eq('tanggal', dateStr);

      journals.value = journalRes;
    } catch (e) {
      print('Fetch Error: $e');
    } finally {
      isLoading.value = false;
    }
  }

  void changeDate(DateTime date) {
    fetchDataByDate(date);
  }
}

class JurnalMengajarGuruPage extends StatelessWidget {
  const JurnalMengajarGuruPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(JurnalMengajarGuruController());

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
      body: Obx(() {
        return Column(
          children: [
            _buildCalendarHeader(controller),
            Expanded(
              child: controller.isLoading.value 
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                  onRefresh: () => controller.fetchDataByDate(controller.selectedDate.value),
                  child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: controller.journals.length + (controller.journals.isEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (controller.journals.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 50.0),
                              child: Text(
                                'Tidak ada jurnal',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                            ),
                          );
                        }

                        final jurnal = controller.journals[index];
                        final jadwal = jurnal['jadwal_mengajar'];
                        String className = jadwal['master_kelas']['nama_kelas'] ?? '-';
                        String subject = jadwal['master_mata_pelajaran']['nama_mata_pelajaran'] ?? '-';
                        String status = jurnal['status'] ?? 'pending';
                        
                        // Parse attendance counts
                        final List presensi = jurnal['presensi_siswa'] as List? ?? [];
                        int sCount = presensi.where((p) => p['status'].toString().toUpperCase().startsWith('S')).length;
                        int iCount = presensi.where((p) => p['status'].toString().toUpperCase().startsWith('I')).length;
                        int aCount = presensi.where((p) => p['status'].toString().toUpperCase().startsWith('A')).length;
                        String attendance = 'S:$sCount I:$iCount A:$aCount'; 

                        return _buildJurnalCard(
                          className, 
                          subject, 
                          attendance, 
                          status: status,
                          onTap: () {
                            _handleCardTap(context, jurnal, status);
                          }
                        );
                      },
                    ),
                ),
            ),
          ],
        );
      }),
    );
  }

  void _handleCardTap(BuildContext context, Map jurnal, String status) {
    if (status == 'validated' || status == 'approved' || status == 'disetujui' ) {
      Get.to(() => DetailJurnalMengajarGuruPage(jurnalId: jurnal['id']));
    } else if (status == 'rejected' || status == 'ditolak') {
      // Show rejection reason first then allow edit
      Get.defaultDialog(
        title: 'Jurnal Ditolak',
        middleText: 'Catatan Admin: ${jurnal['catatan_admin'] ?? '-'}',
        textConfirm: 'Edit Jurnal',
        textCancel: 'Tutup',
        confirmTextColor: Colors.white,
        buttonColor: Colors.orange,
        onConfirm: () {
          Get.back();
          Get.to(() => FormJurnalMengajarGuruPage(
            schedule: jurnal['jadwal_mengajar'],
            isEdit: true,
            jurnalId: jurnal['id'],
          ))?.then((val) {
             if (val == true) {
               Get.find<JurnalMengajarGuruController>().fetchDataByDate(Get.find<JurnalMengajarGuruController>().selectedDate.value);
             }
          });
        }
      );
    } else {
      Get.to(() => FormJurnalMengajarGuruPage(
        schedule: jurnal['jadwal_mengajar'],
        isEdit: true,
        jurnalId: jurnal['id'],
      ))?.then((val) {
         if (val == true) {
           Get.find<JurnalMengajarGuruController>().fetchDataByDate(Get.find<JurnalMengajarGuruController>().selectedDate.value);
         }
      });
    }
  }

  Widget _buildJurnalCard(String className, String subject, String attendance, {required String status, VoidCallback? onTap}) {
    Color bgColor;
    Color textColor;
    IconData iconData;
    Color iconBgColor;
    
    if (status == 'validated' || status == 'approved' || status == 'disetujui') {
      bgColor = const Color(0xFFCDD8F0); 
      textColor = MainColor.primaryColor;
      iconBgColor = MainColor.sudahValidasiCheckColor;
      iconData = Icons.check;
    } else if (status == 'rejected' || status == 'ditolak') {
      bgColor = Colors.orange.shade100;
      textColor = Colors.orange.shade900;
      iconBgColor = Colors.orange;
      iconData = Icons.close;
    } else {
      bgColor = const Color(0xFF4A8BCE);
      textColor = Colors.white;
      iconBgColor = Colors.amber;
      iconData = Icons.hourglass_top;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    className,
                    style: TextStyle(
                      color: status == 'pending' || status == 'proses' ? const Color(0xFFFDEBCA) : textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          subject,
                          style: TextStyle(
                            color: status == 'pending' || status == 'proses' ? Colors.white70 : textColor.withOpacity(0.8),
                            fontSize: 14,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        attendance,
                        style: TextStyle(
                          color: status == 'pending' || status == 'proses' ? Colors.white70 : textColor.withOpacity(0.8),
                          fontSize: 14,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconBgColor,
              ),
              child: Icon(
                iconData,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader(JurnalMengajarGuruController controller) {
    DateTime currentSelected = controller.selectedDate.value;
    String monthYear = DateFormat('MMMM yyyy').format(currentSelected);
    
    List<DateTime> dates = [];
    for (int i = -3; i <= 3; i++) {
      dates.add(currentSelected.add(Duration(days: i)));
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                   controller.changeDate(currentSelected.subtract(const Duration(days: 7)));
                },
                child: Icon(Icons.arrow_back_ios, size: 18, color: MainColor.primaryColor),
              ),
              Text(
                monthYear,
                style: TextStyle(
                  fontSize: 20,
                  color: MainColor.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              GestureDetector(
                onTap: () {
                   controller.changeDate(currentSelected.add(const Duration(days: 7)));
                },
                child: Icon(Icons.arrow_forward_ios, size: 18, color: MainColor.primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dates.map((d) {
              bool isSelected = d.year == currentSelected.year && d.month == currentSelected.month && d.day == currentSelected.day;
              String dayName = DateFormat('E').format(d);
              String dayNum = DateFormat('d').format(d);
              
              return GestureDetector(
                onTap: () => controller.changeDate(d),
                child: _buildDayItem(dayName, dayNum, isSelected),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDayItem(String day, String date, bool isSelected) {
    return Column(
      children: [
        Text(
          day,
          style: TextStyle(
            color: isSelected ? MainColor.primaryColor : Colors.grey,
            fontWeight: FontWeight.w600,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? MainColor.primaryColor : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              date,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 16,
                fontFamily: GoogleFonts.poppins().fontFamily,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
