import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:iqmarket/providers/app_config_provider.dart';
import 'package:iqmarket/screens/product_details_screen.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/screens/admin/admin_user_card_screen.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  bool _isProcessing = false;

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
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all_rounded, color: Color(0xFF10B981)),
            tooltip: 'Прочитать все',
            onPressed: () async {
              try {
                final snapshot = await FirebaseFirestore.instance.collection('reports').get();
                final batch = FirebaseFirestore.instance.batch();
                int unreadCount = 0;
                for (final doc in snapshot.docs) {
                  if (doc.data()['isRead'] != true) {
                    batch.update(doc.reference, {'isRead': true});
                    unreadCount++;
                  }
                }
                if (unreadCount > 0) {
                  await batch.commit();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Прочитано жалоб: $unreadCount')),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Все жалобы уже прочитаны')),
                    );
                  }
                }
              } catch (e) {
                debugPrint('Error marking all read: $e');
              }
            },
          ),
        ],
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
          // Сортировка по убыванию времени на клиенте
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = (aData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = (bData['timestamp'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              final comment = data['comment'] ?? '';
              final bool isUnread = data['isRead'] != true;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: isUnread 
                      ? const BorderSide(color: Color(0xFFEF4444), width: 1.5)
                      : BorderSide.none,
                ),
                elevation: 0,
                color: Colors.white,
                child: InkWell(
                  onTap: _isProcessing ? null : () => _showReportDetails(context, doc, data),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _typeBadge(data['type'] ?? 'other'),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'НОВОЕ',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            Text(DateFormat('dd.MM HH:mm').format(timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          data['adTitle'] ?? data['reportedUserName'] ?? 'Без названия / Профиль', 
                          style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF0F172A))
                        ),
                        const SizedBox(height: 8),
                        if (comment.toString().isNotEmpty) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              comment,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF475569), fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        Row(
                          children: [
                            const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                            const SizedBox(width: 4),
                            Expanded(
                              child: UserInfoTile(
                                userId: data['reporterUserId'] ?? '',
                                label: 'От:',
                                labelColor: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.red),
                            const SizedBox(width: 4),
                            Expanded(
                              child: UserInfoTile(
                                userId: data['reportedUserId'] ?? '',
                                label: 'На:',
                                labelColor: Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Text(
                              'Подробнее', 
                              style: GoogleFonts.inter(color: const Color(0xFF1A73E8), fontWeight: FontWeight.bold, fontSize: 13)
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_rounded, size: 16, color: Color(0xFF1A73E8)),
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

  void _showReportDetails(BuildContext context, QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    if (_isProcessing) return;

    if (data['isRead'] != true) {
      FirebaseFirestore.instance
          .collection('reports')
          .doc(doc.id)
          .update({'isRead': true})
          .catchError((e) => debugPrint('Error marking report read: $e'));
    }

    setState(() => _isProcessing = true);
    try {
      final timestamp = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
      final type = data['type'] ?? 'other';
      final adId = data['adId'];
      final adTitle = data['adTitle'];
      final reportedUserId = data['reportedUserId'];
      final reportedUserName = data['reportedUserName'];
      final reporterUserId = data['reporterUserId'];
      final comment = data['comment'] ?? '';

      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        'Детали жалобы',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 22, color: const Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      _typeBadge(type),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('dd MMMM yyyy, HH:mm').format(timestamp),
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const Divider(height: 32),

                  // Subject
                  Text(
                    'ПРЕДМЕТ ЖАЛОБЫ',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  if (adTitle != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shopping_bag_outlined, color: Color(0xFF1A73E8), size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Объявление',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            adTitle,
                            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16, color: const Color(0xFF0F172A)),
                          ),
                          if (adId != null) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final rootNav = Navigator.of(context);
                                  try {
                                    final ad = await AdService.getAdById(adId);
                                    rootNav.pop(); // close bottom sheet
                                    if (ad != null && rootNav.context.mounted) {
                                      final lang = Provider.of<AppConfigProvider>(rootNav.context, listen: false).language;
                                      Navigator.push(
                                        rootNav.context,
                                        MaterialPageRoute(builder: (c) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: lang, heroPrefix: 'rep_${ad.id}')),
                                      );
                                    } else if (rootNav.context.mounted) {
                                      ScaffoldMessenger.of(rootNav.context).showSnackBar(
                                        const SnackBar(content: Text('Объявление не найдено или уже удалено.')),
                                      );
                                    }
                                  } catch (e) {
                                    rootNav.pop();
                                    if (rootNav.context.mounted) {
                                      ScaffoldMessenger.of(rootNav.context).showSnackBar(
                                        SnackBar(content: Text('Ошибка открытия объявления: $e')),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.remove_red_eye_outlined, size: 16),
                                label: const Text('Смотреть объявление'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEBF3FF),
                                  foregroundColor: const Color(0xFF1A73E8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (reportedUserName != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, color: Color(0xFF1A73E8), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Пользователь (Профиль)',
                                  style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reportedUserName,
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Users involved
                  UserDetailCard(
                    userId: reporterUserId,
                    roleLabel: 'Отправитель (жалобщик)',
                    roleColor: const Color(0xFF4A80F0),
                    screenContext: context,
                  ),
                  const SizedBox(height: 8),
                  UserDetailCard(
                    userId: reportedUserId ?? 'anonymous',
                    roleLabel: 'Нарушитель',
                    roleColor: Colors.redAccent,
                    screenContext: context,
                  ),

                  const SizedBox(height: 24),

                  // Comment / Reason
                  Text(
                    'КОММЕНТАРИЙ ПОЛЬЗОВАТЕЛЯ',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 1),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFFFEDD5), width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.format_quote_rounded, color: Colors.orange, size: 24),
                        const SizedBox(height: 6),
                        Text(
                          comment.isNotEmpty ? comment : 'Без дополнительных пояснений.',
                          style: GoogleFonts.inter(
                            fontSize: 14, 
                            color: const Color(0xFF7C2D12), 
                            fontWeight: FontWeight.w500, 
                            height: 1.4,
                            fontStyle: comment.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Admin Actions
                  Text(
                    'ДЕЙСТВИЯ',
                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF64748B), letterSpacing: 1),
                  ),
                  const SizedBox(height: 12),

                  if (adId != null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _confirmDeleteAd(context, adId, doc.id),
                        icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                        label: const Text('Удалить объявление нарушителя'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteReport(doc.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Жалоба удалена из списка')),
                              );
                            },
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981)),
                            label: const Text('Отклонить жалобу'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF10B981),
                              side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 60,
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF64748B),
                            side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Icon(Icons.close_rounded),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _confirmDeleteAd(BuildContext context, String adId, String reportId) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Удалить объявление?'),
        content: const Text('Вы действительно хотите навсегда удалить это объявление и эту жалобу? Данное действие необратимо.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Отмена', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c); // pop dialog
              Navigator.pop(context); // pop bottom sheet
              
              // Show progress
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Удаление объявления...'), duration: Duration(seconds: 1)),
              );

              try {
                await AdService.deleteAd(adId);
                await FirebaseFirestore.instance.collection('reports').doc(reportId).delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Объявление и жалоба успешно удалены! 🗑️')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Ошибка удаления: $e')),
                  );
                }
              }
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReport(String id) async {
    await FirebaseFirestore.instance.collection('reports').doc(id).delete();
  }
}

// ============================================================================
// Premium Widgets & Dialogs for Admin reports details
// ============================================================================

class UserInfoTile extends StatelessWidget {
  final String userId;
  final String label;
  final Color labelColor;

  const UserInfoTile({
    super.key,
    required this.userId,
    required this.label,
    this.labelColor = Colors.grey,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == 'anonymous' || userId.isEmpty) {
      return Row(
        children: [
          Text('$label ', style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.bold)),
          const Text('Анонимно', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminUserCardScreen(uid: userId)),
        );
      },
      child: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(
              children: [
                Text('$label ', style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.bold)),
                const SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(strokeWidth: 1, color: Colors.grey),
                ),
              ],
            );
          }

          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return Row(
              children: [
                Text('$label ', style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.bold)),
                Expanded(
                  child: Text(
                    userId, 
                    style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.underline), 
                    maxLines: 1, 
                    overflow: TextOverflow.ellipsis
                  ),
                ),
              ],
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>?;
          final name = data?['name'] ?? 'Пользователь';
          final phone = data?['phone'] ?? '';
          final display = phone.isNotEmpty ? '$name ($phone)' : name;

          return Row(
            children: [
              Text('$label ', style: TextStyle(fontSize: 11, color: labelColor, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  display,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF1E293B), fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class UserDetailCard extends StatelessWidget {
  final String userId;
  final String roleLabel;
  final Color roleColor;
  final BuildContext screenContext;

  const UserDetailCard({
    super.key,
    required this.userId,
    required this.roleLabel,
    required this.roleColor,
    required this.screenContext,
  });

  @override
  Widget build(BuildContext context) {
    if (userId == 'anonymous' || userId.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.grey[200],
              child: const Icon(Icons.person, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 1)),
                const SizedBox(height: 2),
                const Text('Анонимный отправитель', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ],
            ),
          ],
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 90,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const CircularProgressIndicator(color: Color(0xFF4A80F0)),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(roleLabel.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 1)),
                const SizedBox(height: 4),
                SelectableText('ID: $userId\n(Пользователь не найден в БД)', style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final name = data['name'] ?? 'Пользователь';
        final phone = data['phone'] ?? 'Нет телефона';
        final email = data['email'] ?? 'Нет email';
        final photoUrl = data['photoUrl'] ?? '';
        final status = data['status'] ?? 'active';
        final isBanned = status == 'banned';

        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              screenContext,
              MaterialPageRoute(builder: (_) => AdminUserCardScreen(uid: userId)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isBanned ? const Color(0xFFFEF2F2) : const Color(0xFFF8FAFC),
              border: Border.all(color: isBanned ? Colors.red.withValues(alpha: 0.15) : const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      roleLabel.toUpperCase(),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: roleColor, letterSpacing: 1),
                    ),
                    if (isBanned)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ЗАБЛОКИРОВАН',
                          style: TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blue.shade50,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty ? const Icon(Icons.person, color: Color(0xFF4A80F0)) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: const Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          SelectableText(
                            phone,
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        email,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: const Color(0xFFE2E8F0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        _showUserManagementDialog(screenContext, userId, name, phone, email, isBanned);
                      },
                      icon: const Icon(Icons.manage_accounts_outlined, size: 14, color: Color(0xFF1E293B)),
                      label: Text(
                        'Управлять',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

void _showUserManagementDialog(
  BuildContext context,
  String userId,
  String name,
  String phone,
  String email,
  bool isBanned,
) {
  showDialog(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text('Управление пользователем', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          SelectableText('ID: $userId', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.phone_outlined, color: Colors.blue),
            title: Text(phone),
            onTap: () async {
              if (phone.isNotEmpty && phone != 'Нет телефона') {
                final url = Uri.parse('tel:$phone');
                try {
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Не удалось запустить приложение для звонков'), backgroundColor: Colors.redAccent),
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ошибка вызова: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                }
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy_rounded, color: Colors.grey),
            title: const Text('Скопировать ID'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: userId));
              Navigator.pop(dialogCtx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID скопирован!'), behavior: SnackBarBehavior.floating),
              );
            },
          ),
          ListTile(
            leading: Icon(
              isBanned ? Icons.check_circle_outline_rounded : Icons.block_flipped,
              color: isBanned ? Colors.green : Colors.red,
            ),
            title: Text(isBanned ? 'Разблокировать' : 'Заблокировать'),
            onTap: () async {
              Navigator.pop(dialogCtx);
              await UserService.toggleUserBan(userId, !isBanned);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isBanned 
                        ? 'Пользователь успешно разблокирован!' 
                        : 'Пользователь заблокирован!',
                    ),
                    backgroundColor: isBanned ? Colors.green : Colors.red,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogCtx),
          child: const Text('Закрыть'),
        ),
      ],
    ),
  );
}
