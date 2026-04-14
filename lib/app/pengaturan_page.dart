import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get/get.dart';

class PengaturanController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;
  
  var periodeList = [].obs;
  var selectedPeriodeId = Rxn<int>();
  
  var batasInputList = [1, 2, 3, 4, 5, 7, 14].obs; // Hari
  var selectedBatasInput = 3.obs; // Default 3 Hari

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      // Fetch master_periode
      final response = await supabase
          .from('master_periode')
          .select()
          .order('id', ascending: false);
      periodeList.value = response;

      // Load from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      
      final savedPeriode = prefs.getInt('active_periode_id');
      if (savedPeriode != null && response.any((p) => p['id'] == savedPeriode)) {
        selectedPeriodeId.value = savedPeriode;
      } else if (response.isNotEmpty) {
        selectedPeriodeId.value = response.first['id'];
      }

      final savedBatas = prefs.getInt('batas_input_jurnal');
      if (savedBatas != null) {
        selectedBatasInput.value = savedBatas;
      }
    } catch (e) {
      Get.snackbar('Error', 'Gagal memuat pengaturan: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> savePengaturan() async {
    if (selectedPeriodeId.value == null) {
      Get.snackbar('Peringatan', 'Pilih periode aktif terlebih dahulu');
      return;
    }

    isLoading.value = true;
    try {
      // 1. Update DB: Set all to false first
      await supabase
          .from('master_periode')
          .update({'is_active': false})
          .neq('id', 0); // neq dummy to target all if possible, or just update

      // 2. Set the selected one to true
      await supabase
          .from('master_periode')
          .update({'is_active': true})
          .eq('id', selectedPeriodeId.value!);

      // 3. Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_periode_id', selectedPeriodeId.value!);
      await prefs.setInt('batas_input_jurnal', selectedBatasInput.value);
      
      Get.snackbar('Sukses', 'Pengaturan berhasil disimpan');
    } catch (e) {
      Get.snackbar('Error', 'Gagal menyimpan pengaturan: $e');
    } finally {
      isLoading.value = false;
    }
  }
}

class PengaturanPage extends StatelessWidget {
  const PengaturanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PengaturanController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Pengaturan',
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

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Periode',
                style: TextStyle(
                  color: MainColor.primaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: MainColor.primaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: controller.selectedPeriodeId.value,
                    hint: const Text('Pilih Periode'),
                    onChanged: (val) {
                      controller.selectedPeriodeId.value = val;
                    },
                    items: controller.periodeList.map<DropdownMenuItem<int>>((p) {
                      return DropdownMenuItem<int>(
                        value: p['id'],
                        child: Text(p['nama_periode'].toString()),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Batas Input Jurnal',
                style: TextStyle(
                  color: MainColor.primaryText,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: MainColor.primaryBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: controller.selectedBatasInput.value,
                    onChanged: (val) {
                      if (val != null) controller.selectedBatasInput.value = val;
                    },
                    items: controller.batasInputList.map<DropdownMenuItem<int>>((b) {
                      return DropdownMenuItem<int>(
                        value: b,
                        child: Text('$b Hari'),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const Spacer(),
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
                  onPressed: controller.savePengaturan,
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
              )
            ],
          ),
        );
      }),
    );
  }
}
