import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool showGreetingCard = true;

  String name = "";
  String searchQuery = "";

  double lat = -6.34800000;
  double lng = 108.32400000;

  @override
  void initState() {
    super.initState();
    loadGreetingCardState();
    loadUser();
    loadLaundry();
  }

  Future<void> loadGreetingCardState() async {
    final prefs = await SharedPreferences.getInstance();
    final isHidden = prefs.getBool('hide_customer_greeting_card') ?? false;

    if (!mounted) return;

    setState(() {
      showGreetingCard = !isHidden;
    });
  }

  Future<void> hideGreetingCard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_customer_greeting_card', true);

    if (!mounted) return;

    setState(() {
      showGreetingCard = false;
    });
  }

  Future<void> loadUser() async {
    name = await auth.getName();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> loadLaundry() async {
    setState(() {
      loading = true;
    });

    try {
      laundries = await laundryService.getLaundries(lat, lng);
    } catch (e) {
      showMsg("Gagal mengambil laundry: $e");
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<LaundryModel> get filteredLaundries {
    if (searchQuery.trim().isEmpty) {
      return laundries;
    }

    return laundries.where((laundry) {
      final query = searchQuery.toLowerCase();

      return laundry.name.toLowerCase().contains(query) ||
          laundry.address.toLowerCase().contains(query);
    }).toList();
  }

  Widget _buildCustomerNavbar() {
    return Container(
      height: 195,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade600,
            Colors.blue.shade400,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -25,
            child: Container(
              width: 135,
              height: 135,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Positioned(
            right: 70,
            bottom: -45,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(22, 32, 22, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Halo, Pemesan",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.80),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            name.isEmpty ? "Selamat Datang" : name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),

                    _navIconButton(
                      icon: Icons.receipt_long_rounded,
                      onTap: () {
                        Navigator.pushNamed(context, "/order-status");
                      },
                    ),

                    const SizedBox(width: 8),

                    _navIconButton(icon: Icons.logout_rounded, onTap: logout),
                  ],
                ),

                const SizedBox(height: 34),

                Container(
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
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
                      hintStyle: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 13,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        color: Colors.blue.shade600,
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  searchQuery = "";
                                });
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _navIconButton({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildGreetingCard() {
    if (!showGreetingCard) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade600,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade100,
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.local_laundry_service_rounded,
            color: Colors.white,
            size: 32,
          ),

          const SizedBox(width: 14),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Butuh laundry hari ini?",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Cari laundry terdekat dan buat pesanan dengan mudah.",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: hideGreetingCard,
            icon: const Icon(
              Icons.close_rounded,
              color: Colors.white,
              size: 24,
            ),
            tooltip: "Tutup",
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    return Row(
      children: [
        Expanded(
          child: Text(
            "Laundry Terdekat (${filteredLaundries.length} laundry tersedia)",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget buildLaundryCard(LaundryModel laundry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
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
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            Navigator.pushNamed(
              context,
              "/laundry-detail",
              arguments: laundry.id,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.local_laundry_service_rounded,
                    color: Colors.blue.shade700,
                    size: 32,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        laundry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        children: [
                          _miniBadge(
                            icon: Icons.star_rounded,
                            text: laundry.rating.toStringAsFixed(1),
                            color: Colors.amber,
                          ),

                          const SizedBox(width: 8),

                          _miniBadge(
                            icon: Icons.location_on_rounded,
                            text: "${laundry.distance.toStringAsFixed(1)} km",
                            color: Colors.blue,
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Row(
                        children: [
                          Icon(
                            Icons.storefront_rounded,
                            size: 15,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              laundry.address,
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
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Colors.blue.shade700,
                    size: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniBadge({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLaundry() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Icon(
            Icons.store_mall_directory_outlined,
            size: 68,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 14),
          Text(
            searchQuery.isEmpty ? "Belum ada laundry" : "Tidak ditemukan",
            style: TextStyle(
              color: Colors.grey.shade700,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            searchQuery.isEmpty
                ? "Belum ada laundry terdaftar saat ini."
                : "Tidak ada laundry yang cocok dengan pencarian Anda.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          ),
          if (searchQuery.isNotEmpty) ...[
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  searchQuery = "";
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Reset Pencarian"),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLaundryList() {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (filteredLaundries.isEmpty) {
      return _buildEmptyLaundry();
    }

    return Column(
      children: filteredLaundries.map((laundry) {
        return buildLaundryCard(laundry);
      }).toList(),
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Pastikan alamat pickup ditulis lengkap agar kurir laundry mudah menemukan lokasi Anda.",
              style: TextStyle(
                fontSize: 12.5,
                color: Colors.orange.shade800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomerNavbar(),

            Expanded(
              child: RefreshIndicator(
                onRefresh: loadLaundry,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 15, 18, 24),
                  children: [
                    if (showGreetingCard) ...[
                      _buildGreetingCard(),
                      const SizedBox(height: 14),
                    ],

                    _buildSectionTitle(),

                    const SizedBox(height: 12),

                    _buildLaundryList(),

                    const SizedBox(height: 8),

                    _buildTipsCard(),
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
