import 'package:flutter/material.dart';
import '../../models/laundry_model.dart';
import '../../services/auth_service.dart';
import '../../services/laundry_service.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final laundryService = LaundryService();
  final auth = AuthService();

  List<LaundryModel> laundries = [];
  bool loading = true;
  String name = "";
  String searchQuery = "";

  double lat = -6.34800000;
  double lng = 108.32400000;

  @override
  void initState() {
    super.initState();
    loadUser();
    loadLaundry();
  }

  Future<void> loadUser() async {
    name = await auth.getName();
    if (mounted) setState(() {});
  }

  Future<void> loadLaundry() async {
    setState(() => loading = true);
    try {
      laundries = await laundryService.getLaundries(lat, lng);
    } catch (e) {
      showMsg("Gagal mengambil laundry: $e");
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> logout() async {
    await auth.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/login");
  }

  void showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<LaundryModel> get filteredLaundries {
    if (searchQuery.isEmpty) return laundries;
    return laundries.where((laundry) =>
      laundry.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
      laundry.address.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();
  }

  Widget buildLaundryCard(LaundryModel laundry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 2,
        shadowColor: Colors.grey.shade200,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: () {
            Navigator.pushNamed(
              context,
              "/laundry-detail",
              arguments: laundry.id,
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade100, Colors.blue.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.local_laundry_service, 
                    color: Colors.blue.shade700, 
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        laundry.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, 
                                  size: 12, 
                                  color: Colors.amber.shade600,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  laundry.rating.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11, 
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade400,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on, 
                            size: 14, 
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            "${laundry.distance.toStringAsFixed(1)} km",
                            style: TextStyle(
                              fontSize: 12, 
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.storefront, 
                            size: 14, 
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              laundry.address,
                              style: TextStyle(
                                color: Colors.grey.shade600, 
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.chevron_right, 
                    size: 20, 
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade800],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_laundry_service, 
                color: Colors.white, 
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              "Londree",
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 22,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, "/order-status");
            },
            icon: const Icon(Icons.receipt_long),
            tooltip: "Status Pesanan",
          ),
          IconButton(
            onPressed: logout,
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Profile
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade500, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person, 
                    color: Colors.white, 
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Halo, ${name.isEmpty ? "Pemesan" : name}!",
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Temukan laundry terdekat",
                        style: TextStyle(
                          color: Colors.grey.shade600, 
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.my_location, 
                        size: 16, 
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Aktif",
                        style: TextStyle(
                          fontSize: 12, 
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    searchQuery = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: "Cari laundry atau alamat...",
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  prefixIcon: Icon(Icons.search, 
                    color: Colors.grey.shade500,
                    size: 22,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, 
                            color: Colors.grey.shade500,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              searchQuery = "";
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, 
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Title Section
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade700,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Laundry Terdekat",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (filteredLaundries.isNotEmpty)
                  TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue.shade600,
                    ),
                    child: const Text("Lihat Semua"),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // List
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadLaundry,
              color: Colors.blue,
              child: loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.blue),
                          SizedBox(height: 16),
                          Text("Memuat data laundry..."),
                        ],
                      ),
                    )
                  : filteredLaundries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.store_rounded, 
                                size: 80, 
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                searchQuery.isEmpty 
                                    ? "Belum ada laundry"
                                    : "Tidak ditemukan",
                                style: TextStyle(
                                  color: Colors.grey.shade600, 
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                searchQuery.isEmpty 
                                    ? "Belum ada laundry terdaftar"
                                    : "Tidak ada laundry yang cocok dengan \"$searchQuery\"",
                                style: TextStyle(
                                  color: Colors.grey.shade400, 
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              if (searchQuery.isNotEmpty)
                                const SizedBox(height: 16),
                              if (searchQuery.isNotEmpty)
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      searchQuery = "";
                                    });
                                  },
                                  icon: const Icon(Icons.refresh),
                                  label: const Text("Reset Pencarian"),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredLaundries.length,
                          itemBuilder: (context, index) => 
                              buildLaundryCard(filteredLaundries[index]),
                        ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          loadLaundry();
        },
        backgroundColor: Colors.blue.shade700,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}