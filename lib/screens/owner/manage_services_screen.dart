import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/laundry_service.dart';
import '../../widgets/custom_button.dart';

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
        services = serviceData.map((e) => Map<String, dynamic>.from(e)).toList();
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

  Future<void> saveService() async {
    if (serviceNameC.text.trim().isEmpty ||
        priceC.text.trim().isEmpty ||
        estimatedC.text.trim().isEmpty) {
      showMsg("Nama layanan, harga, dan estimasi wajib diisi", false);
      return;
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
          pricePerKg: double.tryParse(priceC.text.trim()) ?? 0,
          estimatedTime: estimatedC.text.trim(),
        );
      } else {
        result = await laundryService.addService(
          ownerId: ownerId,
          serviceName: serviceNameC.text.trim(),
          pricePerKg: double.tryParse(priceC.text.trim()) ?? 0,
          estimatedTime: estimatedC.text.trim(),
        );
      }

      if (!mounted) return;

      showMsg(result["message"] ?? "Proses selesai", result["success"] == true);

      if (result["success"] == true) {
        resetServiceForm();
        await loadServices();
      }
    } catch (e) {
      showMsg("Gagal menyimpan layanan: $e", false);
    }

    if (mounted) {
      setState(() => savingService = false);
    }
  }

  void editService(Map<String, dynamic> service) {
    setState(() {
      isEditService = true;
      selectedServiceId = int.tryParse(service["id"].toString());

      serviceNameC.text = service["service_name"]?.toString() ?? "";
      priceC.text = double.tryParse(service["price_per_kg"].toString())
              ?.toStringAsFixed(0) ??
          "0";
      estimatedC.text = service["estimated_time"]?.toString() ?? "";
    });
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

  Future<void> confirmDeleteService(Map<String, dynamic> service) async {
    final serviceName = service["service_name"]?.toString() ?? "layanan ini";

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.green.shade50.withOpacity(0.3),
            ],
          ),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade400, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.local_laundry_service,
              color: Colors.white,
              size: 24,
            ),
          ),
          title: Text(
            serviceName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "${formatRupiah(price)} / kg",
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  "⏱️ $estimated",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          trailing: PopupMenuButton<String>(
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
        ),
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
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.green.shade700,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: loadServices,
            icon: const Icon(Icons.refresh),
            tooltip: "Refresh",
          ),
        ],
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
                padding: const EdgeInsets.all(16),
                children: [
                  // Section: Tambah/Edit Layanan
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.green.shade400, Colors.green.shade700],
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isEditService ? Icons.edit : Icons.add,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    isEditService ? "Edit Layanan" : "Tambah Layanan Baru",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              if (isEditService)
                                TextButton.icon(
                                  onPressed: resetServiceForm,
                                  icon: const Icon(Icons.close, size: 18),
                                  label: const Text("Batal"),
                                  style: TextButton.styleFrom(
                                    backgroundColor: Colors.grey.shade100,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextField(
                            controller: serviceNameC,
                            decoration: deco("Nama Layanan", Icons.cleaning_services),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: priceC,
                            keyboardType: TextInputType.number,
                            decoration: deco("Harga per Kg", Icons.payments),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: estimatedC,
                            decoration: deco("Estimasi Waktu", Icons.schedule),
                          ),
                          const SizedBox(height: 20),
                          CustomButton(
                            text: isEditService ? "Update Layanan" : "Tambah Layanan",
                            loading: savingService,
                            onPressed: saveService,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Section: Daftar Layanan
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.shade200,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange.shade400, Colors.orange.shade700],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.list_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Daftar Layanan Aktif",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                "${services.length} Layanan",
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (services.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(40),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.inbox_outlined,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    "Belum ada layanan",
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Tambah layanan pertama Anda",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Column(
                              children: services.map(serviceItem).toList(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}