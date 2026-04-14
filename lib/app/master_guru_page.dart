import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:jurnal_mengajar/app/color.dart';
import 'package:jurnal_mengajar/app/detail_guru_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:get/get.dart';

class MasterGuruController extends GetxController {
  final supabase = Supabase.instance.client;
  var isLoading = false.obs;
  var guruList = [].obs;
  var searchList = [].obs;

  @override
  void onInit() {
    super.onInit();
    fetchData();
  }

  Future<void> fetchData() async {
    isLoading.value = true;
    try {
      final response = await supabase
          .from('profiles')
          .select()
          .eq('role', 'guru')
          .order('nama_lengkap', ascending: true);
      guruList.value = response;
      searchList.value = response;
    } catch (e) {
      Get.snackbar('Error', e.toString());
    } finally {
      isLoading.value = false;
    }
  }

  void search(String query) {
    if (query.isEmpty) {
      searchList.value = guruList;
    } else {
      searchList.value = guruList
          .where((g) => g['nama_lengkap']
              .toString()
              .toLowerCase()
              .contains(query.toLowerCase()))
          .toList();
    }
  }
}

class MasterGuruPage extends StatelessWidget {
  const MasterGuruPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MasterGuruController());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Guru',
          style: TextStyle(
            color: Colors.white,
            fontFamily: GoogleFonts.poppins().fontFamily,
          ),
        ),
        backgroundColor: MainColor.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
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
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
              if (controller.isLoading.value) {
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
                      color: MainColor.secondaryColor,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => Get.to(() => DetailGuruPage(guruId: data['id'])),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 25,
                                backgroundImage: NetworkImage(
                                  data['foto_url'] != null && data['foto_url'].isNotEmpty
                                      ? data['foto_url']
                                      : 'https://ui-avatars.com/api/?name=${data['nama_lengkap']}&background=random',
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['nama_lengkap'] ?? '-',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                    Text(
                                      data['jabatan'] ?? '-',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white,
                                size: 18,
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
}
