import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;
  final bool isSecondary;
  final IconData? icon; // Tambahkan parameter icon

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.loading = false,
    this.isSecondary = false,
    this.icon, // Tambahkan icon parameter
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? Colors.white : Colors.blue.shade600,
          foregroundColor: isSecondary ? Colors.blue.shade600 : Colors.white,
          elevation: isSecondary ? 0 : 2,
          shadowColor: isSecondary ? Colors.transparent : Colors.blue.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: isSecondary ? BorderSide(color: Colors.blue.shade600) : BorderSide.none,
          ),
        ),
        child: loading
            ? SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: isSecondary ? Colors.blue.shade600 : Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}