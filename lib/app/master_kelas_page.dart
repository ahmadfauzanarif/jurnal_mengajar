import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class MasterKelasController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;
  var kelasList = [].obs;
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
          .from('master_kelas')
          .select()
          .order('id', ascending: false);
      kelasList.value = response;
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
      searchList.value = kelasList;
    } else {
      searchList.value = kelasList
          .where((k) => k['nama_kelas']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }
  }

  Future<void> saveKelas(String nama, {int? id}) async {
    if (nama.isEmpty) {
      Get.snackbar('Peringatan', 'Nama kelas tidak boleh kosong');
      return;
    }
    
    isLoading.value = true;
    try {
      if (id == null) {
        await supabase.from('master_kelas').insert({
          'nama_kelas': nama,
        });
      } else {
        await supabase.from('master_kelas').update({
          'nama_kelas': nama,
        }).eq('id', id);
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

  Future<void> deleteKelas(int id) async {
    isLoading.value = true;
    try {
      await supabase.from('master_kelas').delete().eq('id', id);
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

class MasterKelasPage extends StatelessWidget {
  const MasterKelasPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MasterKelasController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Master Kelas',
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
              if (controller.isLoading.value && controller.kelasList.isEmpty) {
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
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  data['nama_kelas'] ?? '-',
                                  style: TextStyle(
                                    color: MainColor.primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: GoogleFonts.poppins().fontFamily,
                                  ),
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

  void _openForm(BuildContext context, MasterKelasController controller, {Map<String, dynamic>? data}) {
    final isEdit = data != null;
    final id = isEdit ? data['id'] : null;
    final nameController = TextEditingController(text: isEdit ? data['nama_kelas'] : '');

    Get.to(() => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Master Kelas',
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
                        controller.deleteKelas(id);
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
                Text(
                  'Nama Kelas',
                  style: TextStyle(
                    color: MainColor.primaryText,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    fillColor: MainColor.primaryBackground,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                    onPressed: () {
                      controller.saveKelas(
                        nameController.text,
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
}
