import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class MasterJamController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;
  var jamList = [].obs;
  var searchList = [].obs;
  var searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      final response = await supabase
          .from('master_jam')
          .select()
          .order('jam_ke', ascending: true);
      jamList.value = response;
      search(searchQuery.value);
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void search(String query) {
    searchQuery.value = query;
    if (query.isEmpty) {
      searchList.value = jamList;
    } else {
      searchList.value = jamList
          .where((j) => 
            j['jam_ke'].toString().contains(query) ||
            j['waktu_reguler'].toString().contains(query) ||
            j['waktu_puasa'].toString().contains(query)
          )
          .toList();
    }
  }

  Future<void> saveJam(String jamKe, String reguler, String puasa, {int? id}) async {
    if (jamKe.isEmpty || reguler.isEmpty || puasa.isEmpty) {
      Get.snackbar('Peringatan', 'Semua field harus diisi');
      return;
    }
    
    isLoading.value = true;
    try {
      final data = {
        'jam_ke': int.tryParse(jamKe) ?? 0,
        'waktu_reguler': reguler,
        'waktu_puasa': puasa,
      };

      if (id == null) {
        await supabase.from('master_jam').insert(data);
      } else {
        await supabase.from('master_jam').update(data).eq('id', id);
      }
      await fetchData();
      Get.back();
      Get.snackbar('Sukses', id != null ? 'Data berhasil diperbarui' : 'Data berhasil ditambahkan');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteJam(int id) async {
    isLoading.value = true;
    try {
      await supabase.from('master_jam').delete().eq('id', id);
      await fetchData();
      Get.back();
      Get.snackbar('Sukses', 'Data berhasil dihapus');
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }
}

class MasterJamPage extends StatelessWidget {
  const MasterJamPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MasterJamController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Master Jam',
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
            onPressed: () => _openForm(context, controller),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: controller.search,
              decoration: InputDecoration(
                hintText: 'Pencarian',
                hintStyle: TextStyle(
                  color: MainColor.validateColor,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
                suffixIcon: Icon(Icons.search, color: MainColor.secondaryText),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: MainColor.validateColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: MainColor.validateColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: MainColor.primaryColor),
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value && controller.jamList.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (controller.searchList.isEmpty) {
                return const Center(child: Text('Data tidak ditemukan'));
              }

              return ListView.builder(
                itemCount: controller.searchList.length,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemBuilder: (context, index) {
                  final data = controller.searchList[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: MainColor.primaryBackground,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openForm(context, controller, data: data),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: MainColor.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    data['jam_ke'].toString(),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Reguler: ${data['waktu_reguler']}',
                                      style: TextStyle(
                                        color: MainColor.primaryText,
                                        fontWeight: FontWeight.bold,
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                    Text(
                                      'Puasa: ${data['waktu_puasa']}',
                                      style: TextStyle(
                                        color: MainColor.secondaryText,
                                        fontSize: 14,
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: MainColor.primaryColor,
                                size: 16,
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          )
        ],
      ),
    );
  }

  void _openForm(BuildContext context, MasterJamController controller, {Map<String, dynamic>? data}) {
    final isEdit = data != null;
    final id = isEdit ? data['id'] : null;
    
    final jamKeController = TextEditingController(text: isEdit ? data['jam_ke'].toString() : '');
    final regulerController = TextEditingController(text: isEdit ? data['waktu_reguler'] : '');
    final puasaController = TextEditingController(text: isEdit ? data['waktu_puasa'] : '');

    Get.to(() => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              isEdit ? 'Edit Jam' : 'Tambah Jam',
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
                      middleText: 'Apakah Anda yakin ingin menghapus data ini?',
                      textConfirm: 'Ya',
                      textCancel: 'Tidak',
                      confirmTextColor: Colors.white,
                      onConfirm: () {
                        Get.back();
                        controller.deleteJam(id);
                      },
                    );
                  },
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Jam Ke (Angka)'),
                _buildTextField(jamKeController, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildLabel('Waktu Reguler (Contoh: 07:00 - 07:45)'),
                _buildTextField(regulerController),
                const SizedBox(height: 16),
                _buildLabel('Waktu Puasa (Contoh: 07:30 - 08:10)'),
                _buildTextField(puasaController),
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
                    onPressed: () {
                      controller.saveJam(
                        jamKeController.text,
                        regulerController.text,
                        puasaController.text,
                        id: id,
                      );
                    },
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
          ),
        ));
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

  Widget _buildTextField(TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        fillColor: MainColor.primaryBackground,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
