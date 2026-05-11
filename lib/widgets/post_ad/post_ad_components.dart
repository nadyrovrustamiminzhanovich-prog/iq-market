import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';

class PostAdInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final int maxLines;
  final bool isRequired;
  final int? maxLength;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const PostAdInput({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.isRequired = false,
    this.maxLength,
    this.errorText,
    this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF1E293B))),
            if (isRequired)
              const Text(' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: TextCapitalization.sentences,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            errorStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
            hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            counterStyle: GoogleFonts.inter(fontSize: 10, color: Colors.grey[500]),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF4A80F0), width: 2)),
          ),
        ),
      ],
    );
  }
}

class PostAdChoiceChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const PostAdChoiceChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF4A80F0) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: GoogleFonts.inter(color: isSelected ? Colors.white : const Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }
}

class PostAdOptionSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const PostAdOptionSwitch({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
      activeThumbColor: const Color(0xFF4A80F0),
      activeTrackColor: const Color(0xFF4A80F0).withValues(alpha: 0.5),
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class PostAdMediaTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const PostAdMediaTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: (color ?? const Color(0xFFF8FAFC)).withValues(alpha: color != null ? 0.1 : 1.0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color ?? Colors.grey[200]!, width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color ?? const Color(0xFF64748B)),
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }
}

class PostAdPreviewItem extends StatelessWidget {
  final File? file;
  final bool isVideo;
  final VoidCallback onRemove;

  const PostAdPreviewItem({
    super.key,
    this.file,
    this.isVideo = false,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: isVideo 
              ? Container(color: Colors.black87, child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 40)))
              : Image.file(file!, fit: BoxFit.cover, width: 100, height: 100),
          ),
          Positioned(
            top: 4, right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.red,
                child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PostAdSpecsContainer extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const PostAdSpecsContainer({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 10),
              Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}
