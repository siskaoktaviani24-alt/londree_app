import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../widgets/custom_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameC = TextEditingController();
  final emailC = TextEditingController();
  final phoneC = TextEditingController();
  final passwordC = TextEditingController();
  final confirmPasswordC = TextEditingController();

  final auth = AuthService();

  String role = "customer";
  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  Future<void> register() async {
    if (nameC.text.trim().isEmpty ||
        emailC.text.trim().isEmpty ||
        phoneC.text.trim().isEmpty ||
        passwordC.text.trim().isEmpty ||
        confirmPasswordC.text.trim().isEmpty) {
      showMsg("Semua field harus diisi", isSuccess: false);
      return;
    }

    if (passwordC.text.trim() != confirmPasswordC.text.trim()) {
      showMsg("Password tidak sama", isSuccess: false);
      return;
    }

    if (passwordC.text.trim().length < 6) {
      showMsg("Password minimal 6 karakter", isSuccess: false);
      return;
    }

    setState(() => loading = true);

    try {
      final result = await auth.register(
        name: nameC.text.trim(),
        email: emailC.text.trim(),
        phone: phoneC.text.trim(),
        password: passwordC.text.trim(),
        role: role,
      );

      if (!mounted) return;

      final success = result["success"] == true;
      showMsg(result["message"] ?? "Registrasi gagal", isSuccess: success);

      if (success) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        showMsg("Gagal koneksi ke server: $e", isSuccess: false);
      }
    }

    if (mounted) {
      setState(() => loading = false);
    }
  }

  void showMsg(String msg, {required bool isSuccess}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess
            ? Colors.green.shade700
            : Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    nameC.dispose();
    emailC.dispose();
    phoneC.dispose();
    passwordC.dispose();
    confirmPasswordC.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.blue.shade600),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: "Masukkan $label",
        prefixIcon: Icon(Icons.lock_outline, color: Colors.blue.shade600),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.grey.shade500,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      value: role,
      decoration: InputDecoration(
        labelText: "Daftar Sebagai",
        prefixIcon: Icon(
          Icons.assignment_ind_outlined,
          color: Colors.blue.shade600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      items: const [
        DropdownMenuItem(value: "customer", child: Text("Pemesan Laundry")),
        DropdownMenuItem(value: "owner", child: Text("Pemilik Laundry")),
      ],
      onChanged: (value) {
        if (value != null) {
          setState(() => role = value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade600,
              Colors.blue.shade400,
              Colors.blue.shade50,
            ],
            stops: const [0.0, 0.3, 0.8],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 50),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.person_add_alt_1,
                      size: 60,
                      color: Colors.blue.shade600,
                    ),
                  ),

                  const SizedBox(height: 15),

                  const Text(
                    "Daftar Akun",
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    "Buat akun Londree baru",
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.white.withOpacity(0.95),
                    ),
                  ),

                  const SizedBox(height: 35),

                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 20,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildTextField(
                          controller: nameC,
                          label: "Nama Lengkap",
                          hint: "Masukkan nama lengkap",
                          icon: Icons.person_outline,
                        ),

                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: emailC,
                          label: "Email",
                          hint: "contoh@email.com",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),

                        const SizedBox(height: 16),

                        _buildTextField(
                          controller: phoneC,
                          label: "No HP",
                          hint: "Masukkan nomor HP",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                        ),

                        const SizedBox(height: 16),

                        _buildPasswordField(
                          controller: passwordC,
                          label: "Password",
                          obscure: obscurePassword,
                          onToggle: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        _buildPasswordField(
                          controller: confirmPasswordC,
                          label: "Konfirmasi Password",
                          obscure: obscureConfirmPassword,
                          onToggle: () {
                            setState(() {
                              obscureConfirmPassword = !obscureConfirmPassword;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        _buildRoleDropdown(),

                        const SizedBox(height: 28),

                        CustomButton(
                          text: "Daftar",
                          loading: loading,
                          onPressed: register,
                        ),

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Sudah punya akun? ",
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                "Login",
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
