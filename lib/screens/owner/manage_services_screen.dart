import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/laundry_service.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen> {
  final laundryService = LaundryService();
  final auth = AuthService();

  final serviceNameC = TextEditingController();
  final priceC = TextEditingController();
  final estimatedC = TextEditingController();

  bool loading = true;
  bool savingService = false;
  bool isEditService = false;
  int? selectedServiceId;
  List<Map<String, dynamic>> services = [];

  @override
  void initState() {
    super.initState();
    loadServices();
  }

  Future<void> loadServices() async {
    setState(() => loading = true);

    try {
      final ownerId = await auth.getUserId();
      final result = await laundryService.getOwnerLaundry(ownerId);

      if (!mounted) return;

      if (result["success"] == true) {
        final List serviceData = result["services"] ?? [];
        services = serviceData
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
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

  Future<bool> saveService() async {
    if (serviceNameC.text.trim().isEmpty ||
        priceC.text.trim().isEmpty ||
        estimatedC.text.trim().isEmpty) {
      showMsg("Nama layanan, harga, dan estimasi wajib diisi", false);
      return false;
    }

    final price = double.tryParse(priceC.text.trim());

    if (price == null || price <= 0) {
      showMsg("Harga layanan harus lebih dari 0", false);
      return false;
    }

    setState(() => savingService = true);

    try {
      final ownerId = await auth.getUserId();
      Map<String, dynamic> result;

      if (isEditService && selectedServiceId != null) {
        result = await laundryService.updateService(
          ownerId: ownerId,
          serviceId: selectedServiceId!,
          serviceName: serviceNameC.text.trim(),
          pricePerKg: price,
          estimatedTime: estimatedC.text.trim(),
        );
      } else {
        result = await laundryService.addService(
          ownerId: ownerId,
          serviceName: serviceNameC.text.trim(),
          pricePerKg: price,
          estimatedTime: estimatedC.text.trim(),
        );
      }

      if (!mounted) return false;

      showMsg(result["message"] ?? "Proses selesai", result["success"] == true);

      if (result["success"] == true) {
        resetServiceForm();
        await loadServices();
        return true;
      }

      return false;
    } catch (e) {
      showMsg("Gagal menyimpan layanan: $e", false);
      return false;
    } finally {
      if (mounted) {
        setState(() => savingService = false);
      }
    }
  }

  void editService(Map<String, dynamic> service) {
    setState(() {
      isEditService = true;
      selectedServiceId = int.tryParse(service["id"].toString());

      serviceNameC.text = service["service_name"]?.toString() ?? "";
      priceC.text =
          double.tryParse(
            service["price_per_kg"].toString(),
          )?.toStringAsFixed(0) ??
          "0";
      estimatedC.text = service["estimated_time"]?.toString() ?? "";
    });

    showServiceFormDialog();
  }

  void resetServiceForm() {
    setState(() {
      isEditService = false;
      selectedServiceId = null;
      serviceNameC.clear();
      priceC.clear();
      estimatedC.clear();
    });
  }

  void openAddServiceForm() {
    resetServiceForm();
    showServiceFormDialog();
  }

  void showServiceFormDialog() {
    bool dialogSaving = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void closeDialog() {
              FocusManager.instance.primaryFocus?.unfocus();
              Navigator.pop(dialogContext);
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.78,
                ),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(
                            isEditService
                                ? Icons.edit_rounded
                                : Icons.add_rounded,
                            color: Colors.blue.shade700,
                            size: 25,
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEditService
                                    ? "Edit Layanan"
                                    : "Tambah Layanan",
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEditService
                                    ? "Perbarui informasi layanan laundry"
                                    : "Lengkapi data layanan baru",
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: dialogSaving ? null : closeDialog,
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.grey.shade700,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    Divider(color: Colors.grey.shade200, height: 1),

                    Flexible(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(top: 18, bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _serviceFieldLabel("Nama Layanan"),
                            const SizedBox(height: 7),
                            TextField(
                              controller: serviceNameC,
                              textInputAction: TextInputAction.next,
                              decoration: cleanServiceInput(
                                hint: "Contoh: Cuci Kering",
                                icon: Icons.local_laundry_service_rounded,
                              ),
                            ),

                            const SizedBox(height: 14),

                            _serviceFieldLabel("Harga per Kg"),
                            const SizedBox(height: 7),
                            TextField(
                              controller: priceC,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.next,
                              decoration: cleanServiceInput(
                                hint: "Contoh: 7000",
                                icon: Icons.payments_rounded,
                                prefixText: "Rp ",
                              ),
                            ),

                            const SizedBox(height: 14),

                            _serviceFieldLabel("Estimasi Waktu"),
                            const SizedBox(height: 7),
                            TextField(
                              controller: estimatedC,
                              textInputAction: TextInputAction.done,
                              decoration: cleanServiceInput(
                                hint: "Contoh: 2 hari",
                                icon: Icons.schedule_rounded,
                              ),
                            ),

                            const SizedBox(height: 16),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(13),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      "Layanan ini akan muncul di halaman customer saat membuat pesanan.",
                                      style: TextStyle(
                                        fontSize: 12.3,
                                        color: Colors.blue.shade800,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: dialogSaving
                            ? null
                            : () async {
                                FocusManager.instance.primaryFocus?.unfocus();

                                setDialogState(() {
                                  dialogSaving = true;
                                });

                                final success = await saveService();

                                if (!mounted) return;

                                if (success) {
                                  Navigator.pop(dialogContext);
                                } else {
                                  setDialogState(() {
                                    dialogSaving = false;
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: Colors.grey.shade300,
                          disabledForegroundColor: Colors.grey.shade600,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: dialogSaving
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditService
                                    ? "Simpan Perubahan"
                                    : "Tambah Layanan",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      if (mounted) {
        resetServiceForm();
      }
    });
  }

  Widget _serviceFieldLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  InputDecoration cleanServiceInput({
    required String hint,
    required IconData icon,
    String? prefixText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, color: Colors.blue.shade700, size: 21),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 1.5),
      ),
    );
  }

  Future<void> confirmDeleteService(Map<String, dynamic> service) async {
    final serviceName = service["service_name"]?.toString() ?? "layanan ini";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Hapus Layanan"),
          content: Text("Apakah kamu yakin ingin menghapus $serviceName?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text("Hapus"),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final serviceId = int.tryParse(service["id"].toString()) ?? 0;
      await deleteService(serviceId);
    }
  }

  Future<void> deleteService(int serviceId) async {
    if (serviceId <= 0) {
      showMsg("ID layanan tidak valid", false);
      return;
    }

    try {
      final ownerId = await auth.getUserId();

      final result = await laundryService.deleteService(
        ownerId: ownerId,
        serviceId: serviceId,
      );

      if (!mounted) return;

      showMsg(result["message"] ?? "Proses selesai", result["success"] == true);

      if (result["success"] == true) {
        await loadServices();
      }
    } catch (e) {
      showMsg("Gagal menghapus layanan: $e", false);
    }
  }

  void showMsg(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green.shade700 : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  InputDecoration deco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.blue.shade600),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  String formatRupiah(dynamic value) {
    final number = double.tryParse(value.toString()) ?? 0;
    final text = number.toStringAsFixed(0);

    final buffer = StringBuffer();
    int count = 0;

    for (int i = text.length - 1; i >= 0; i--) {
      buffer.write(text[i]);
      count++;

      if (count == 3 && i != 0) {
        buffer.write(".");
        count = 0;
      }
    }

    return "Rp ${buffer.toString().split('').reversed.join()}";
  }

  Widget serviceItem(Map<String, dynamic> service) {
    final serviceName = service["service_name"]?.toString() ?? "-";
    final price = service["price_per_kg"]?.toString() ?? "0";
    final estimated = service["estimated_time"]?.toString() ?? "-";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.local_laundry_service_rounded,
              color: Colors.blue.shade700,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Icon(
                      Icons.timer_outlined,
                      size: 15,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        estimated,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    "${formatRupiah(price)} / kg",
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey.shade700),
            onSelected: (value) {
              if (value == "edit") {
                editService(service);
              } else if (value == "delete") {
                confirmDeleteService(service);
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem(
                  value: "edit",
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text("Edit"),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: "delete",
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Hapus"),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    serviceNameC.dispose();
    priceC.dispose();
    estimatedC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Kelola Layanan",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: loading
          ? null
          : FloatingActionButton.extended(
              onPressed: openAddServiceForm,
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                "Tambah Layanan",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Memuat data layanan..."),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: loadServices,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.cleaning_services_rounded,
                                color: Colors.blue.shade700,
                              ),
                            ),

                            const SizedBox(width: 12),

                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Daftar Layanan Aktif",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    "Kelola layanan laundry yang tersedia",
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                "${services.length} Layanan",
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        if (services.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 34),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 54,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Belum ada layanan",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Tekan tombol Tambah Layanan untuk membuat layanan pertama.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(children: services.map(serviceItem).toList()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
