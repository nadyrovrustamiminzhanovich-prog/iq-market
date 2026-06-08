import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/services/ad_service.dart';

class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text('Жалобы', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text('Ошибка загрузки жалоб: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red)),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.assignment_turned_in_rounded, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('Жалоб пока нет', style: GoogleFonts.inter(color: Colors.grey, fontSize: 16)),
              ],
            ));
          }

          final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
          // Сортировка на клиенте для абсолютной надежности и предотвращения ошибок отсутствия индекса Firestore
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime); // по убыванию (сначала новые)
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _typeBadge(data['type'] ?? 'other'),
                          const Spacer(),
                          Text(DateFormat('dd.MM HH:mm').format(timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(data['adTitle'] ?? 'Без названия', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(child: Text('От: ${data['reporterUserId']}', style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                          const SizedBox(width: 4),
                          Expanded(child: Text('На: ${data['reportedUserId']}', style: const TextStyle(fontSize: 11, color: Colors.red), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => _viewAd(context, data['adId']),
                            child: const Text('Смотреть объявление'),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                            onPressed: () => _deleteReport(doc.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _typeBadge(String type) {
    Color color = Colors.grey;
    String label = 'Другое';
    
    if (type == 'fraud') { color = Colors.red; label = 'Мошенничество'; }
    else if (type == 'wrong_price') { color = Colors.orange; label = 'Неверная цена'; }
    else if (type == 'sold') { color = Colors.blue; label = 'Продано'; }
    else if (type == 'prohibited') { color = Colors.red; label = 'Запрещено'; }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _viewAd(BuildContext context, String? adId) async {
    if (adId == null) return;
    try {
      final ad = await AdService.getAdById(adId);
      if (ad != null && context.mounted) {
        final lang = Provider.of<AppConfigProvider>(context, listen: false).language;
        Navigator.push(context, MaterialPageRoute(builder: (c) => ProductDetailsScreen(ad: ad, onReport: (_){}, lang: lang, heroPrefix: null)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Объявление не найдено или удалено: $e')));
      }
    }
  }

  Future<void> _deleteReport(String id) async {
    await FirebaseFirestore.instance.collection('reports').doc(id).delete();
  }
}
