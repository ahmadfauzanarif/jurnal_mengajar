import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JadwalMengajarAdminController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;

  var selectedDate = DateTime.now().obs;
  var schedules = [].obs;
  var filteredSchedules = [].obs;
  var showBelumInputOnly = false.obs;
  var searchQuery = "".obs;

  JadwalMengajarAdminController({
    DateTime? initialDate,
    bool belumInputOnly = false,
  }) {
    if (initialDate != null) {
      selectedDate.value = initialDate;
    }
    showBelumInputOnly.value = belumInputOnly;

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
          .from('jadwal_mengajar')
          .select(
            '*, profiles:guru_id(id,nama_lengkap,foto_url), master_periode(nama_periode), master_kelas(nama_kelas), master_mata_pelajaran(nama_mata_pelajaran), master_jam(jam_ke,waktu_reguler,waktu_puasa)',
          )
          .eq('tanggal', dateStr)
          .order('jam_id', ascending: true);

      schedules.assignAll(response);

      if (showBelumInputOnly.value) {
        final resJurnal = await supabase
            .from('jurnal_harian')
            .select('jadwal_id')
            .eq('tanggal', dateStr);
        final filledJadwalIds = resJurnal.map((j) => j['jadwal_id']).toSet();

        schedules.value = schedules
            .where((s) => !filledJadwalIds.contains(s['id']))
            .toList();
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
      filteredSchedules.assignAll(schedules);
    } else {
      final query = searchQuery.value.toLowerCase();
      filteredSchedules.assignAll(
        schedules.where((s) {
          final guruName = (s['profiles']?['nama_lengkap'] ?? "")
              .toString()
              .toLowerCase();
          final mapel =
              (s['master_mata_pelajaran']?['nama_mata_pelajaran'] ?? "")
                  .toString()
                  .toLowerCase();
          final kelas = (s['master_kelas']?['nama_kelas'] ?? "")
              .toString()
              .toLowerCase();
          final jam = (s['master_jam']?['jam_ke'] ?? "")
              .toString()
              .toLowerCase();

          return guruName.contains(query) ||
              mapel.contains(query) ||
              kelas.contains(query) ||
              jam.contains(query);
        }).toList(),
      );
    }
  }

  Future<void> deleteJadwal(int id) async {
    isLoading.value = true;
    try {
      await supabase.from('jadwal_mengajar').delete().eq('id', id);
      await fetchDataByDate(selectedDate.value);
      Get.back(); // Close dialog or form
      Get.snackbar('Sukses', 'Jadwal berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menghapus jadwal: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class JadwalMengajarAdminPage extends StatelessWidget {
  final DateTime? initialDate;
  final bool showBelumInputOnly;

  const JadwalMengajarAdminPage({
    super.key,
    this.initialDate,
    this.showBelumInputOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      JadwalMengajarAdminController(
        initialDate: initialDate,
        belumInputOnly: showBelumInputOnly,
      ),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Jadwal Mengajar',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.white),
            onPressed: () {
              Get.to(
                () => FormJadwalPage(date: controller.selectedDate.value),
              )?.then((_) {
                controller.fetchDataByDate(controller.selectedDate.value);
              });
            },
          ),
        ],
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
                hintText: 'Cari Guru, Mapel, Kelas atau Jam...',
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

              if (controller.filteredSchedules.isEmpty) {
                return const Center(child: Text('Tidak ada jadwal ditemukan'));
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: controller.filteredSchedules.length,
                itemBuilder: (context, index) {
                  final schedule = controller.filteredSchedules[index];
                  return _buildScheduleCard(schedule, controller);
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalCalendar(JadwalMengajarAdminController controller) {
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
        ],
      );
    });
  }

  Widget _buildScheduleCard(
    Map<String, dynamic> s,
    JadwalMengajarAdminController controller,
  ) {
    final Map jam = s['master_jam'] ?? {};
    final String kelas = s['master_kelas'] != null
        ? s['master_kelas']['nama_kelas']
        : '-';
    final String mapel = s['master_mata_pelajaran'] != null
        ? s['master_mata_pelajaran']['nama_mata_pelajaran']
        : '-';
    final String timeRange = jam['waktu_reguler'] ?? '-';
    final Map guru = s['profiles'] ?? {};
    final String guruName = guru['nama_lengkap'] ?? '-';
    final bool isActive = s['is_active'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MainColor.accentColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Get.to(
              () => FormJadwalPage(
                date: DateTime.parse(s['tanggal']),
                existingData: s.cast<String, dynamic>(),
              ),
            )?.then((_) {
              controller.fetchDataByDate(controller.selectedDate.value);
            });
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
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            isActive ? Icons.check_circle : Icons.cancel,
                            color: isActive ? Colors.white : Colors.redAccent,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mapel,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            kelas,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                          Text(
                            timeRange,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
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
}

class FormJadwalController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;

  var periodeList = [].obs;
  var jamList = [].obs;
  var kelasList = [].obs;
  var mapelList = [].obs;
  var guruList = [].obs;

  var selectedPeriodeId = Rxn<int>();
  var selectedJamIds = <int>[].obs;
  var selectedKelasId = Rxn<int>();
  var selectedMapelId = Rxn<int>();
  var selectedGuruId = Rxn<String>();

  var selectedDate = DateTime.now().obs;
  var isActive = true.obs;
  var isRepeat = false.obs;
  var bookedJamIds = <int>[].obs;

  final Map<String, dynamic>? existingData;

  FormJadwalController({required DateTime initialDate, this.existingData}) {
    selectedDate.value = existingData != null
        ? DateTime.parse(existingData!['tanggal'])
        : initialDate;
  }

  @override
  void onInit() {
    super.onInit();
    fetchDropdownData().then((_) {
      if (selectedKelasId.value != null) {
        fetchBookedJams();
      }
    });

    // Listen to date or class changes to re-fetch bookings
    ever(selectedDate, (_) => fetchBookedJams());
    ever(selectedKelasId, (_) => fetchBookedJams());
  }

  Future<void> fetchBookedJams() async {
    if (selectedKelasId.value == null) {
      bookedJamIds.clear();
      return;
    }

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate.value);
      var query = supabase
          .from('jadwal_mengajar')
          .select('jam_id')
          .eq('tanggal', dateStr)
          .eq('kelas_id', selectedKelasId.value!);

      if (existingData != null) {
        query = query.neq('id', existingData!['id']);
      }

      final response = await query;
      bookedJamIds.assignAll(response.map((e) => e['jam_id'] as int).toList());
    } catch (e) {
      print("Error fetching booked jams: $e");
    }
  }

  Future<void> fetchDropdownData() async {
    isLoading.value = true;
    try {
      final resPeriode = await supabase
          .from('master_periode')
          .select()
          .eq('is_active', true);
      periodeList.value = resPeriode;

      final resJam = await supabase
          .from('master_jam')
          .select()
          .order('jam_ke', ascending: true);

      // Explicit sort in Dart to handle potential string types or DB inconsistencies
      resJam.sort(
        (a, b) => (int.tryParse(a['jam_ke'].toString()) ?? 0).compareTo(
          int.tryParse(b['jam_ke'].toString()) ?? 0,
        ),
      );

      jamList.value = resJam;

      final resKelas = await supabase
          .from('master_kelas')
          .select()
          .order('nama_kelas');
      kelasList.value = resKelas;

      final resMapel = await supabase
          .from('master_mata_pelajaran')
          .select()
          .order('nama_mata_pelajaran');
      mapelList.value = resMapel;

      final resGuru = await supabase
          .from('profiles')
          .select()
          .eq('role', 'guru')
          .order('nama_lengkap');
      guruList.value = resGuru;

      // Populate existing data if Editing
      if (existingData != null) {
        selectedPeriodeId.value = existingData!['periode_id'];
        selectedJamIds.assign(existingData!['jam_id']);
        selectedKelasId.value = existingData!['kelas_id'];
        selectedMapelId.value = existingData!['mata_pelajaran_id'];
        selectedGuruId.value = existingData!['guru_id'];
        isActive.value = existingData!['is_active'] ?? true;
      } else {
        // Just adding: load from settings
        final prefs = await SharedPreferences.getInstance();
        final savedPeriode = prefs.getInt('active_periode_id');
        if (savedPeriode != null &&
            resPeriode.any((p) => p['id'] == savedPeriode)) {
          selectedPeriodeId.value = savedPeriode;
        } else if (resPeriode.isNotEmpty) {
          selectedPeriodeId.value = resPeriode.first['id'];
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat data master: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveJadwal() async {
    if (selectedPeriodeId.value == null ||
        selectedJamIds.isEmpty ||
        selectedKelasId.value == null ||
        selectedMapelId.value == null ||
        selectedGuruId.value == null) {
      Get.snackbar(
        'Peringatan',
        'Semua field wajib diisi (Pilih minimal 1 jam)',
      );
      return;
    }

    isLoading.value = true;
    try {
      if (existingData == null) {
        List<Map<String, dynamic>> batchData = [];
        int totalWeeks = isRepeat.value ? 24 : 1;

        for (int w = 0; w < totalWeeks; w++) {
          DateTime currDate = selectedDate.value.add(Duration(days: w * 7));

          for (var jamId in selectedJamIds) {
            batchData.add({
              'guru_id': selectedGuruId.value,
              'periode_id': selectedPeriodeId.value,
              'kelas_id': selectedKelasId.value,
              'mata_pelajaran_id': selectedMapelId.value,
              'hari': currDate.weekday % 7,
              'tanggal': DateFormat('yyyy-MM-dd').format(currDate),
              'jam_id': jamId,
              'is_active': isActive.value,
            });
          }
        }
        await supabase.from('jadwal_mengajar').insert(batchData);
      } else {
        // Edit mode: only update this specific ID
        final data = {
          'guru_id': selectedGuruId.value,
          'periode_id': selectedPeriodeId.value,
          'kelas_id': selectedKelasId.value,
          'mata_pelajaran_id': selectedMapelId.value,
          'hari': selectedDate.value.weekday % 7,
          'tanggal': DateFormat('yyyy-MM-dd').format(selectedDate.value),
          'jam_id':
              selectedJamIds.first, // In edit mode we only allow 1 jam update
          'is_active': isActive.value,
        };
        await supabase
            .from('jadwal_mengajar')
            .update(data)
            .eq('id', existingData!['id']);
      }

      Get.back();
      Get.snackbar(
        'Sukses',
        existingData != null
            ? 'Jadwal berhasil diperbarui'
            : 'Jadwal berhasil ditambahkan',
      );
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

class FormJadwalPage extends StatelessWidget {
  final DateTime date;
  final Map<String, dynamic>? existingData;

  const FormJadwalPage({super.key, required this.date, this.existingData});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      FormJadwalController(initialDate: date, existingData: existingData),
    );
    final isEdit = existingData != null;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Edit Jadwal Mengajar' : 'Tambah Jadwal Mengajar',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () {
                Get.defaultDialog(
                  title: 'Konfirmasi',
                  middleText: 'Apakah Anda yakin ingin menghapus jadwal ini?',
                  textConfirm: 'Ya',
                  textCancel: 'Tidak',
                  confirmTextColor: Colors.white,
                  onConfirm: () {
                    final adminController =
                        Get.find<JadwalMengajarAdminController>();
                    adminController.deleteJadwal(existingData!['id']);
                  },
                );
              },
            ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Periode'),
              _buildDropdown(
                value: controller.selectedPeriodeId.value,
                hint: 'Pilih Periode',
                items: controller.periodeList,
                valueKey: 'id',
                displayKey: 'nama_periode',
                onChanged: (val) => controller.selectedPeriodeId.value = val,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Tanggal'),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: controller.selectedDate.value,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              controller.selectedDate.value = picked;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: MainColor.primaryBackground,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat(
                                    'dd MMMM yyyy',
                                    'id_ID',
                                  ).format(controller.selectedDate.value),
                                  style: TextStyle(
                                    fontFamily:
                                        GoogleFonts.poppins().fontFamily,
                                  ),
                                ),
                                const Icon(
                                  Icons.calendar_today,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Kelas'),
                        _buildDropdown(
                          value: controller.selectedKelasId.value,
                          hint: 'Pilih Kelas',
                          items: controller.kelasList,
                          valueKey: 'id',
                          displayKey: 'nama_kelas',
                          onChanged: (val) {
                            controller.selectedKelasId.value = val;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('Jam Ke'),
                  Obx(
                    () => Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.jamList.map((j) {
                        final id = j['id'] as int;
                        final isSelected = controller.selectedJamIds.contains(
                          id,
                        );
                        final isBooked = controller.bookedJamIds.contains(id);

                        return FilterChip(
                          label: Text(j['jam_ke'].toString()),
                          selected: isSelected,
                          onSelected: isBooked
                              ? null
                              : (val) {
                                  if (isEdit) {
                                    controller.selectedJamIds.assign(id);
                                  } else {
                                    if (val) {
                                      controller.selectedJamIds.add(id);
                                    } else {
                                      controller.selectedJamIds.remove(id);
                                    }
                                  }
                                },
                          disabledColor: Colors.grey.withOpacity(0.1),
                          selectedColor: MainColor.primaryColor.withOpacity(
                            0.2,
                          ),
                          checkmarkColor: MainColor.primaryColor,
                          labelStyle: TextStyle(
                            color: isBooked
                                ? Colors.grey
                                : (isSelected
                                      ? MainColor.primaryColor
                                      : Colors.black),
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            decoration: isBooked
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildLabel('Pelajaran'),
              _buildDropdown(
                value: controller.selectedMapelId.value,
                hint: 'Pilih Pelajaran',
                items: controller.mapelList,
                valueKey: 'id',
                displayKey: 'nama_mata_pelajaran',
                onChanged: (val) => controller.selectedMapelId.value = val,
              ),
              const SizedBox(height: 16),

              _buildLabel('Guru'),
              _buildDropdown(
                value: controller.selectedGuruId.value,
                hint: 'Pilih Guru',
                items: controller.guruList,
                valueKey: 'id',
                displayKey: 'nama_lengkap',
                onChanged: (val) => controller.selectedGuruId.value = val,
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 16),

              Row(
                children: [
                  Checkbox(
                    value: controller.isActive.value,
                    activeColor: MainColor.primaryColor,
                    onChanged: (val) => controller.isActive.value = val ?? true,
                  ),
                  Text(
                    'Aktif',
                    style: TextStyle(
                      fontFamily: GoogleFonts.poppins().fontFamily,
                      color: MainColor.primaryText,
                    ),
                  ),
                ],
              ),
              if (!isEdit) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: MainColor.secondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: MainColor.secondaryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: MainColor.secondaryColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.repeat,
                          color: MainColor.secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Buat Jadwal Rutin',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: MainColor.secondaryColor,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                            Text(
                              'Otomatis membuat jadwal mingguan untuk 6 bulan ke depan (1 Semester)',
                              style: TextStyle(
                                fontSize: 11,
                                color: MainColor.secondaryText,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: controller.isRepeat.value,
                        activeThumbColor: MainColor.secondaryColor,
                        onChanged: (val) => controller.isRepeat.value = val,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),
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
                  onPressed: controller.saveJadwal,
                  child: Text(
                    'Simpan',
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
      }),
    );
  }

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        label,
        style: TextStyle(
          color: MainColor.primaryText,
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List items,
    required String valueKey,
    required String displayKey,
    required Function(T?) onChanged,
  }) {
    // Make sure we handle mismatch where items might not contain the value due to dynamic lists or deletion
    bool valueExists = items.any((element) => element[valueKey] == value);
    T? finalValue = valueExists ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: MainColor.primaryBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: finalValue,
          hint: Text(hint),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<T>>((item) {
            return DropdownMenuItem<T>(
              value: item[valueKey] as T,
              child: Text(item[displayKey].toString()),
            );
          }).toList(),
        ),
      ),
    );
  }
}
