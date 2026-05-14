import 'package:flutter/material.dart';

class AuthField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final TextEditingController? controller;
  final bool isPassword;
  final bool showToggle;
  final bool isVisible;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;

  const AuthField({
    super.key,
    required this.hint,
    required this.icon,
    this.controller,
    this.isPassword = false,
    this.showToggle = false,
    this.isVisible = false,
    this.onToggle,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && !isVisible,
        keyboardType: keyboardType,
        style: const TextStyle(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontWeight: FontWeight.w500),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF4A80F0), size: 20),
            ),
          ),
          suffixIcon: showToggle
              ? IconButton(
                  icon: Icon(
                    isVisible ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: Colors.grey[400],
                    size: 22,
                  ),
                  onPressed: onToggle,
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

class AuthMainButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const AuthMainButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF3B6AD1)]),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
        ),
      ),
    );
  }
}

class AuthSocialButton extends StatelessWidget {
  final String url;
  final VoidCallback onTap;
  final bool isApple;

  const AuthSocialButton({
    super.key,
    required this.url,
    required this.onTap,
    this.isApple = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isApple ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isApple ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF4A80F0).withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ],
          border: isApple ? null : Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: isApple
            ? const Icon(Icons.apple, color: Colors.white, size: 32)
            : Image.network(url),
      ),
    );
  }
}
class AuthSocialLongButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;
  final Color? color;
  final Color? textColor;
  final bool isDark;

  const AuthSocialLongButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.textColor,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: color ?? (isDark ? Colors.black : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: isDark ? null : Border.all(color: Colors.grey.shade200, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              left: 20,
              child: icon,
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: textColor ?? (isDark ? Colors.white : Colors.black87),
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
