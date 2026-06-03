import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/api_config.dart';
import '../../services/auth_service.dart';
import '../../services/laundry_service.dart';
import '../../widgets/custom_button.dart';

class ManageLaundryScreen extends StatefulWidget {
  const ManageLaundryScreen({super.key});

  @override
  State<ManageLaundryScreen> createState() => _ManageLaundryScreenState();
}

class _ManageLaundryScreenState extends State<ManageLaundryScreen> {
  final laundryService = LaundryService();
  final auth = AuthService();
  final picker = ImagePicker();

  final nameC = TextEditingController();
  final descC = TextEditingController();
  final addressC = TextEditingController();
  final latC = TextEditingController(text: "-6.34800000");
  final lngC = TextEditingController(text: "108.32400000");

  bool loading = true;
  bool savingLaundry = false;

  File? selectedPhoto;
  String? currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    loadOwnerLaundry();
  }

  String getFullPhotoUrl(String path) {
    if (path.startsWith("http")) {
      return path;
    }

    final baseUrl = ApiConfig.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');

    return "$baseUrl/$cleanPath";
  }

  Future<void> loadOwnerLaundry() async {
    setState(() => loading = true);

    try {
      final ownerId = await auth.getUserId();
      final result = await laundryService.getOwnerLaundry(ownerId);

      if (!mounted) return;

      if (result["success"] == true) {
        final laundry = result["laundry"];

        if (laundry != null) {
          nameC.text = laundry["name"]?.toString() ?? "";
          descC.text = laundry["description"]?.toString() ?? "";
          addressC.text = laundry["address"]?.toString() ?? "";
          latC.text = laundry["latitude"]?.toString() ?? "-6.34800000";
          lngC.text = laundry["longitude"]?.toString() ?? "108.32400000";

          final photo = laundry["photo"]?.toString() ?? "";

          if (photo.trim().isNotEmpty) {
            currentPhotoUrl = getFullPhotoUrl(photo);
          } else {
            currentPhotoUrl = null;
          }
        } else {
          currentPhotoUrl = null;
        }
      } else {
        showMsg(result["message"] ?? "Gagal mengambil data", false);
      }
    } catch (e) {
      showMsg("Gagal koneksi ke server: $e", false);
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  Future<void> pickPhoto() async {
    try {
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
      );

      if (picked == null) return;

      setState(() {
        selectedPhoto = File(picked.path);
      });
    } catch (e) {
      showMsg("Gagal memilih foto: $e", false);
    }
  }

  Future<void> saveLaundry() async {
    if (nameC.text.trim().isEmpty ||
        addressC.text.trim().isEmpty ||
        latC.text.trim().isEmpty ||
        lngC.text.trim().isEmpty) {
      showMsg(
        "Nama laundry, alamat, latitude, dan longitude wajib diisi",
        false,
      );
      return;
    }

    setState(() => savingLaundry = true);

    try {
      final ownerId = await auth.getUserId();

      final result = await laundryService.addLaundry(
        ownerId: ownerId,
        name: nameC.text.trim(),
        description: descC.text.trim(),
        address: addressC.text.trim(),
        latitude: double.tryParse(latC.text.trim()) ?? 0,
        longitude: double.tryParse(lngC.text.trim()) ?? 0,
        photo: selectedPhoto,
      );

      if (!mounted) return;

      showMsg(result["message"] ?? "Proses selesai", result["success"] == true);

      if (result["success"] == true) {
        setState(() {
          selectedPhoto = null;
        });

        await loadOwnerLaundry();
      }
    } catch (e) {
      showMsg("Gagal menyimpan profil laundry: $e", false);
    }

    if (mounted) {
      setState(() => savingLaundry = false);
    }
  }

  void showMsg(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  InputDecoration deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(
        icon,
        color: Colors.blue.shade600,
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.blue.shade600,
          width: 2,
        ),
      ),
    );
  }

  Widget buildPhotoForm() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: pickPhoto,
            child: Container(
              width: 115,
              height: 115,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: selectedPhoto != null
                    ? Image.file(
                        selectedPhoto!,
                        fit: BoxFit.cover,
                      )
                    : currentPhotoUrl != null &&
                            currentPhotoUrl!.trim().isNotEmpty
                        ? Image.network(
                            currentPhotoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return emptyPhoto();
                            },
                          )
                        : emptyPhoto(),
              ),
            ),
          ),

          const SizedBox(height: 10),

          TextButton.icon(
            onPressed: pickPhoto,
            icon: Icon(
              Icons.add_a_photo,
              color: Colors.blue.shade700,
            ),
            label: Text(
              "Pilih Foto Laundry",
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget emptyPhoto() {
    return Icon(
      Icons.local_laundry_service_rounded,
      color: Colors.blue.shade600,
      size: 45,
    );
  }

  @override
  void dispose() {
    nameC.dispose();
    descC.dispose();
    addressC.dispose();
    latC.dispose();
    lngC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Kelola Profil Laundry",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
        actions: [
          IconButton(
            onPressed: loadOwnerLaundry,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: loadOwnerLaundry,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        buildPhotoForm(),

                        const SizedBox(height: 18),

                        const Text(
                          "Informasi Laundry",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 16),

                        TextField(
                          controller: nameC,
                          decoration: deco(
                            "Nama Laundry",
                            Icons.store,
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: descC,
                          maxLines: 2,
                          decoration: deco(
                            "Deskripsi",
                            Icons.description,
                          ),
                        ),

                        const SizedBox(height: 14),

                        TextField(
                          controller: addressC,
                          maxLines: 2,
                          decoration: deco(
                            "Alamat",
                            Icons.location_on,
                          ),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: latC,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                decoration: deco(
                                  "Latitude",
                                  Icons.map,
                                ),
                              ),
                            ),

                            const SizedBox(width: 12),

                            Expanded(
                              child: TextField(
                                controller: lngC,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                decoration: deco(
                                  "Longitude",
                                  Icons.map_outlined,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 22),

                        CustomButton(
                          text: "Simpan Perubahan",
                          loading: savingLaundry,
                          onPressed: saveLaundry,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.blue.shade700,
                        ),

                        const SizedBox(width: 8),

                        Expanded(
                          child: Text(
                            "Pastikan data laundry benar agar customer mudah menemukan lokasi Anda.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}