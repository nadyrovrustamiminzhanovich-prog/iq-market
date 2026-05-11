import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iqmarket/theme/taxi_theme.dart';

class TaxiPremiumIconBox extends StatelessWidget {
  final TaxiTheme t;
  final IconData icon;
  final double size;

  const TaxiPremiumIconBox({
    super.key,
    required this.t,
    required this.icon,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Center(child: Icon(icon, size: size, color: t.text)),
    );
  }
}

class TaxiRoleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final TaxiTheme t;
  final VoidCallback onTap;

  const TaxiRoleCard({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.t,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 48,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon, 
                color: isSelected ? Colors.white : const Color(0xFF64748B), 
                size: 18
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

