import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class MasterSiswaController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;
  var siswaList = [].obs;
  var searchList = [].obs;
  var searchQuery = ''.obs;
  
  // For Class Selection
  var kelasList = [].obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
    fetchKelas();
  }

  Future<void> fetchKelas() async {
    try {
      final response = await supabase.from('master_kelas').select().order('nama_kelas');
      kelasList.value = response;
    } catch (e) {
      print('Error fetching kelas: $e');
    }
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      // Use the new select query with relation as per Postman (2)
      final response = await supabase
          .from('master_siswa')
          .select('*, master_kelas(*)')
          .order('id', ascending: false);
      siswaList.value = response;
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
      searchList.value = siswaList;
    } else {
      searchList.value = siswaList
          .where((s) {
            final namaMatch = s['nama_siswa'].toString().toLowerCase().contains(query.toLowerCase());
            final nisnMatch = s['nisn'].toString().toLowerCase().contains(query.toLowerCase());
            final kelasMatch = s['master_kelas'] != null && 
                               s['master_kelas']['nama_kelas'].toString().toLowerCase().contains(query.toLowerCase());
            return namaMatch || nisnMatch || kelasMatch;
          })
          .toList();
    }
  }

  Future<void> saveSiswa(String nama, String nisn, int? kelasId, {int? id}) async {
    if (nama.isEmpty || nisn.isEmpty || kelasId == null) {
      Get.snackbar('Peringatan', 'Semua field harus diisi');
      return;
    }
    
    isLoading.value = true;
    try {
      final data = {
        'nama_siswa': nama,
        'nisn': nisn,
        'kelas_id': kelasId,
      };

      if (id == null) {
        await supabase.from('master_siswa').insert(data);
      } else {
        await supabase.from('master_siswa').update(data).eq('id', id);
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

  Future<void> deleteSiswa(int id) async {
    isLoading.value = true;
    try {
      await supabase.from('master_siswa').delete().eq('id', id);
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

class MasterSiswaPage extends StatelessWidget {
  const MasterSiswaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MasterSiswaController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Master Siswa',
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
                hintText: 'Pencarian (Nama, NISN, Kelas)',
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
              if (controller.isLoading.value && controller.siswaList.isEmpty) {
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
                  final kelas = data['master_kelas'] != null ? data['master_kelas']['nama_kelas'] : '-';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: MainColor.primaryBackground,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openForm(context, controller, data: data),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['nama_siswa'] ?? '-',
                                      style: TextStyle(
                                        color: MainColor.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'NISN: ${data['nisn'] ?? '-'}',
                                          style: TextStyle(
                                            color: MainColor.secondaryText,
                                            fontSize: 12,
                                            fontFamily: GoogleFonts.poppins().fontFamily,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: MainColor.secondaryColor.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Kelas: $kelas',
                                            style: TextStyle(
                                              color: MainColor.secondaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: GoogleFonts.poppins().fontFamily,
                                            ),
                                          ),
                                        ),
                                      ],
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

  void _openForm(BuildContext context, MasterSiswaController controller, {Map<String, dynamic>? data}) {
    final isEdit = data != null;
    final id = isEdit ? data['id'] : null;
    
    final namaController = TextEditingController(text: isEdit ? data['nama_siswa'] : '');
    final nisnController = TextEditingController(text: isEdit ? data['nisn'] : '');
    var selectedKelasId = isEdit ? data['kelas_id'] : null;

    if (selectedKelasId != null && !controller.kelasList.any((k) => k['id'] == selectedKelasId)) {
        selectedKelasId = null; 
    }

    Get.to(() => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              isEdit ? 'Edit Siswa' : 'Tambah Siswa',
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
                        controller.deleteSiswa(id);
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
                _buildLabel('Nama Siswa'),
                _buildTextField(namaController),
                const SizedBox(height: 16),
                _buildLabel('NISN'),
                _buildTextField(nisnController, keyboardType: TextInputType.number),
                const SizedBox(height: 16),
                _buildLabel('Kelas'),
                Obx(() => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: MainColor.primaryBackground,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: selectedKelasId,
                          hint: const Text('Pilih Kelas'),
                          onChanged: (val) {
                            selectedKelasId = val;
                            (context as Element).markNeedsBuild(); 
                          },
                          items: controller.kelasList.map<DropdownMenuItem<int>>((kelas) {
                            return DropdownMenuItem<int>(
                              value: kelas['id'],
                              child: Text(kelas['nama_kelas'].toString()),
                            );
                          }).toList(),
                        ),
                      ),
                    )),
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
                      controller.saveSiswa(
                        namaController.text,
                        nisnController.text,
                        selectedKelasId,
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
