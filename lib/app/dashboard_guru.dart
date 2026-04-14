import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/drawer_guru.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/dashboard_guru_controller.dart';
import 'package:jurnal_mengajar/app/profil_guru_page.dart';
import 'package:jurnal_mengajar/app/jadwal_mengajar_guru_page.dart';
import 'package:jurnal_mengajar/app/jurnal_mengajar_guru_page.dart';
import 'package:jurnal_mengajar/app/form_jurnal_mengajar_guru_page.dart';
import 'package:jurnal_mengajar/app/detail_jurnal_mengajar_guru_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardGuru extends StatelessWidget {
  const DashboardGuru({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardGuruController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Obx(() {
          final profile = controller.userProfile.value;
          String nama = profile['nama_lengkap'] ?? 'Nama Guru';
          String jabatan = 'Guru';
          String? fotoUrl = profile['foto_url'];

          return Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                    Text(
                      jabatan,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Get.to(() => const ProfilGuruPage());
                },
                child: CircleAvatar(
                  backgroundColor: MainColor.primaryBackground,
                  backgroundImage: fotoUrl != null
                      ? NetworkImage(fotoUrl)
                      : null,
                  child: fotoUrl == null
                      ? Icon(Icons.person, color: MainColor.primaryColor)
                      : null,
                ),
              ),
            ],
          );
        }),
      ),
      drawer: const DrawerGuru(),
      body: Column(
        children: [
          Obx(() => _buildCalendarHeader(controller)),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return RefreshIndicator(
                onRefresh: () =>
                    controller.fetchDataByDate(controller.selectedDate.value),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                          vertical: 10.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionHeader(
                              'Jadwal Mengajar',
                              onTap: () {
                                Get.to(() => const JadwalMengajarGuruPage());
                              },
                            ),
                            const SizedBox(height: 12),
                            if (controller.groupedSchedules.isEmpty)
                              Text(
                                'Tidak ada jadwal untuk tanggal ini.',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                  color: Colors.grey,
                                ),
                              )
                            else
                              ...controller.groupedSchedules.map((group) {
                                final firstSchedule = group.first;
                                bool sudahDiisi = group.every(
                                  (s) =>
                                      (s['jurnal_harian'] as List).isNotEmpty,
                                );

                                String startTime =
                                    group.first['master_jam']['waktu_reguler']
                                        ?.split('-')[0]
                                        .trim() ??
                                    '';
                                String endTime =
                                    group.last['master_jam']['waktu_reguler']
                                        ?.split('-')[1]
                                        .trim() ??
                                    '';
                                String time = '$startTime - $endTime';
                                String jamKeList = group
                                    .map(
                                      (s) =>
                                          s['master_jam']['jam_ke'].toString(),
                                    )
                                    .join(', ');

                                return _buildJadwalCard(
                                  time,
                                  '${firstSchedule['master_kelas']['nama_kelas'] ?? ''} (Jam $jamKeList)',
                                  firstSchedule['master_mata_pelajaran']['nama_mata_pelajaran'] ??
                                      '',
                                  sudahDiisi: sudahDiisi,
                                  onTap: () {
                                    _showDetailJadwal(
                                      context,
                                      firstSchedule,
                                      sudahDiisi,
                                      controller,
                                      groupedSchedules: group,
                                    );
                                  },
                                );
                              }),

                            const SizedBox(height: 24),
                            _buildSectionHeader(
                              'Jurnal Mengajar',
                              onTap: () {
                                Get.to(() => const JurnalMengajarGuruPage());
                              },
                            ),
                            const SizedBox(height: 12),
                            if (controller.journals.isEmpty)
                              Text(
                                'Belum ada jurnal untuk tanggal ini.',
                                style: TextStyle(
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                  color: Colors.grey,
                                ),
                              )
                            else
                              ...controller.journals.map((jurnal) {
                                final jadwal = jurnal['jadwal_mengajar'];
                                String className =
                                    jadwal['master_kelas']['nama_kelas'] ?? '-';
                                String subject =
                                    jadwal['master_mata_pelajaran']['nama_mata_pelajaran'] ??
                                    '-';
                                String status = jurnal['status'] ?? 'pending';

                                // Perbaikan Presensi Riil
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
                                    if (status == 'validated' ||
                                        status == 'approved' ||
                                        status == 'disetujui') {
                                      Get.to(
                                        () => DetailJurnalMengajarGuruPage(
                                          jurnalId: jurnal['id'],
                                        ),
                                      );
                                    } else {
                                      Get.to(
                                        () => FormJurnalMengajarGuruPage(
                                          schedule: jurnal['jadwal_mengajar'],
                                          isEdit: true,
                                          jurnalId: jurnal['id'],
                                        ),
                                      );
                                    }
                                  },
                                );
                              }),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            color: MainColor.primaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            'Semua',
            style: TextStyle(
              color: MainColor.primaryColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildJadwalCard(
    String time,
    String className,
    String subject, {
    required bool sudahDiisi,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: sudahDiisi ? const Color(0xFFCDD8F0) : const Color(0xFF4A8BCE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          color: sudahDiisi
                              ? MainColor.primaryColor
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          className,
                          style: TextStyle(
                            color: sudahDiisi
                                ? MainColor.primaryColor
                                : const Color(0xFFFDEBCA),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subject,
                    style: TextStyle(
                      color: sudahDiisi
                          ? MainColor.primaryColor.withOpacity(0.8)
                          : Colors.white70,
                      fontSize: 14,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: sudahDiisi ? MainColor.primaryColor : Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJurnalCard(
    String className,
    String subject,
    String attendance, {
    required String status,
    VoidCallback? onTap,
  }) {
    Color bgColor;
    Color textColor;
    IconData iconData;
    Color iconBgColor;

    // Status can be: 'pending' (biru), 'validated' / 'approved' (abu-abu), 'rejected' (orange)
    if (status == 'validated' ||
        status == 'approved' ||
        status == 'disetujui') {
      bgColor = const Color(0xFFCDD8F0); // abu
      textColor = MainColor.primaryColor;
      iconBgColor = MainColor.sudahValidasiCheckColor;
      iconData = Icons.check;
    } else if (status == 'rejected' || status == 'ditolak') {
      bgColor = Colors.orange.shade100; // orange bg
      textColor = Colors.orange.shade900;
      iconBgColor = Colors.orange;
      iconData = Icons.close;
    } else {
      // pending
      bgColor = const Color(0xFF4A8BCE); // biru
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
                      color: status == 'pending' || status == 'proses'
                          ? const Color(0xFFFDEBCA)
                          : textColor,
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
                            color: status == 'pending' || status == 'proses'
                                ? Colors.white70
                                : textColor.withOpacity(0.8),
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
                          color: status == 'pending' || status == 'proses'
                              ? Colors.white70
                              : textColor.withOpacity(0.8),
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
              child: Icon(iconData, color: Colors.white, size: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetailJadwal(
    BuildContext context,
    Map schedule,
    bool sudahDiisi,
    DashboardGuruController controller, {
    List<Map<String, dynamic>> groupedSchedules = const [],
  }) {
    // Build combined time from group
    String time;
    String jamKeLabel;
    if (groupedSchedules.length > 1) {
      String firstTime =
          groupedSchedules.first['master_jam']['waktu_reguler']
              ?.split('-')[0]
              .trim() ??
          '';
      String lastTime =
          groupedSchedules.last['master_jam']['waktu_reguler']
              ?.split('-')[1]
              .trim() ??
          '';
      time = '$firstTime - $lastTime';
      jamKeLabel =
          'Jam ke ${groupedSchedules.map((s) => s['master_jam']['jam_ke'].toString()).join(', ')}';
    } else {
      time = schedule['master_jam']['waktu_reguler'] ?? '';
      jamKeLabel = 'Jam ke ${schedule['master_jam']['jam_ke']}';
    }
    String dateStr = schedule['tanggal'];
    DateTime scheduleDate = DateTime.parse(dateStr);
    String formattedDate = DateFormat('dd MMMM yyyy').format(scheduleDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: sudahDiisi
                    ? const Color(0xFFEBE0C8)
                    : const Color(0xFFCDD8F0),
                child: Center(
                  child: Text(
                    sudahDiisi
                        ? 'Jurnal dari jadwal ini sudah diisi'
                        : 'Jurnal dari jadwal ini belum diisi',
                    style: TextStyle(
                      color: sudahDiisi
                          ? Colors.green.shade800
                          : MainColor.primaryColor,
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
                schedule['master_kelas']['nama_kelas'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  color: MainColor.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                schedule['master_mata_pelajaran']['nama_mata_pelajaran'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.indigo,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    formattedDate,
                    style: TextStyle(
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                  const SizedBox(width: 24),
                  const Icon(Icons.access_time, size: 16, color: Colors.indigo),
                  const SizedBox(width: 8),
                  Text(
                    '$time ($jamKeLabel)',
                    style: TextStyle(
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
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
                    DateTime now = DateTime.now();
                    DateTime pureDate = DateTime(
                      scheduleDate.year,
                      scheduleDate.month,
                      scheduleDate.day,
                    );
                    DateTime pureNow = DateTime(now.year, now.month, now.day);

                    bool canFill = true;
                    if (pureDate.isAfter(pureNow)) {
                      canFill = false;
                    } else if (pureDate.isAtSameMomentAs(pureNow)) {
                      String startTimeStr = time.split('-')[0].trim();
                      try {
                        List<String> parts = startTimeStr.split('.');
                        int startHour = int.parse(parts[0]);
                        int startMin = int.parse(parts[1]);
                        DateTime startTime = DateTime(
                          now.year,
                          now.month,
                          now.day,
                          startHour,
                          startMin,
                        );
                        if (now.isBefore(startTime)) {
                          canFill = false;
                        }
                      } catch (e) {
                        // ignore parse error, format might differ
                      }
                    }

                    if (!canFill) {
                      Get.back(); // close modal
                      Get.snackbar(
                        'Peringatan',
                        'Anda belum bisa mengisi jurnal. Waktu pelaksanaan jadwal kelas belum tiba.',
                        backgroundColor: Colors.orange,
                        colorText: Colors.white,
                        snackPosition: SnackPosition.BOTTOM,
                        margin: const EdgeInsets.all(20),
                      );
                      return;
                    }

                    Get.back(); // Close modal
                    Get.to(
                      () => FormJurnalMengajarGuruPage(
                        schedule: schedule as Map<String, dynamic>,
                        groupedSchedules: groupedSchedules.isNotEmpty
                            ? groupedSchedules
                            : [schedule],
                        isEdit: sudahDiisi,
                        jurnalId: sudahDiisi
                            ? schedule['jurnal_harian'][0]['id']
                            : null,
                      ),
                    )?.then((value) {
                      if (value == true) {
                        controller.fetchDataByDate(
                          controller.selectedDate.value,
                        );
                      }
                    });
                  },
                  child: Text(
                    sudahDiisi ? 'Edit Jurnal' : 'Isi Jurnal',
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
      },
    );
  }

  Widget _buildCalendarHeader(DashboardGuruController controller) {
    DateTime currentSelected = controller.selectedDate.value;
    String monthYear = DateFormat('MMMM yyyy').format(currentSelected);

    // Generate dates for current week or arbitrary range (let's do +- 3 days from selected)
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
                  controller.changeDate(
                    currentSelected.subtract(const Duration(days: 7)),
                  );
                },
                child: Icon(
                  Icons.arrow_back_ios,
                  size: 18,
                  color: MainColor.primaryColor,
                ),
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
                  controller.changeDate(
                    currentSelected.add(const Duration(days: 7)),
                  );
                },
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: MainColor.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dates.map((d) {
              bool isSelected =
                  d.year == currentSelected.year &&
                  d.month == currentSelected.month &&
                  d.day == currentSelected.day;
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
