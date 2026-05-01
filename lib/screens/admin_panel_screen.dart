import 'dart:io';
import 'package:flutter/material.dart';
import 'package:line_icons/line_icons.dart';

class AdminPanelScreen extends StatefulWidget {
  final List<Map<String, dynamic>> allAds;
  final Function(int) onDeleteAd;
  final Function(int) onApproveAd;

  const AdminPanelScreen({
    super.key, 
    required this.allAds, 
    required this.onDeleteAd,
    required this.onApproveAd,
  });

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1A1D1E), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Панель администратора',
          style: TextStyle(color: Color(0xFF1A1D1E), fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                'Всего: ${widget.allAds.length}',
                style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ),
          )
        ],
      ),
      body: widget.allAds.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.allAds.length,
              itemBuilder: (context, index) {
                final ad = widget.allAds[index];
                return _buildAdminAdCard(ad, index);
              },
            ),
    );
  }

  Widget _buildAdminAdCard(Map<String, dynamic> ad, int index) {
    final bool isPending = ad['status'] == 'pending';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20),
        ],
        border: Border.all(
          color: isPending ? Colors.orange.withValues(alpha: 0.3) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 60,
                height: 60,
                color: const Color(0xFFF8F9FB),
                child: (ad['image_file'] != null || ad['image'] != null)
                    ? (ad['image_file'] != null 
                        ? Image.file(ad['image_file'] is File ? ad['image_file'] as File : File(ad['image_file'].path), fit: BoxFit.cover)
                        : (ad['image'] is String 
                            ? Image.network(ad['image'] as String, fit: BoxFit.cover)
                            : Image(image: ad['image'] as ImageProvider, fit: BoxFit.cover)))
                    : const Icon(Icons.image_outlined, color: Colors.grey),
              ),
            ),
            title: Text(
              ad['title'] ?? 'Без названия',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${ad['price']} • ${ad['category']}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.orange.shade50 : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isPending ? 'НА ПРОВЕРКЕ' : 'АКТИВНО',
                        style: TextStyle(
                          color: isPending ? Colors.orange.shade700 : Colors.green.shade700,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F2F5)),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (isPending)
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => widget.onApproveAd(index),
                      icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      label: const Text('Одобрить', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w800)),
                    ),
                  ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => widget.onDeleteAd(index),
                    icon: const Icon(LineIcons.trash, color: Colors.red, size: 18),
                    label: const Text('Удалить', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: Icon(LineIcons.user, color: Colors.grey.shade600, size: 18),
                    label: Text('Автор', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LineIcons.landmark, size: 80, color: Colors.grey.shade300),
        const SizedBox(height: 20),
        const Text(
          'В системе нет объявлений',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1D1E)),
        ),
      ],
    ),
  );
}
