import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AdminNotificationsScreen extends StatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  State<AdminNotificationsScreen> createState() => _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState extends State<AdminNotificationsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  
  String _selectedTarget = 'Все пользователи';
  final List<String> _targets = [
    'Все пользователи',
    'Только Бизнес',
    'Только Личные',
    'Водители Такси'
  ];

  bool _isSending = false;
  bool _isLoadingCount = false;
  int _targetUserCount = 0;
  
  int _sentCount = 0;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAudienceCount();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Получение точного списка UID целевой аудитории
  Future<List<String>> _fetchTargetUserIds(String target) async {
    final db = FirebaseFirestore.instance;
    final Set<String> userIds = {};

    try {
      if (target == 'Все пользователи') {
        final snap = await db.collection('users').get();
        for (var doc in snap.docs) {
          userIds.add(doc.id);
        }
      } else if (target == 'Только Бизнес') {
        // Поддержка всех возможных написаний поля accountType в БД
        final snapBusinessEn = await db.collection('users').where('accountType', isEqualTo: 'business').get();
        final snapBusinessRu = await db.collection('users').where('accountType', isEqualTo: 'Бизнес').get();
        final snapBusinessFull = await db.collection('users').where('accountType', isEqualTo: 'Бизнес-аккаунт').get();

        for (var doc in snapBusinessEn.docs) {
          userIds.add(doc.id);
        }
        for (var doc in snapBusinessRu.docs) {
          userIds.add(doc.id);
        }
        for (var doc in snapBusinessFull.docs) {
          userIds.add(doc.id);
        }
      } else if (target == 'Только Личные') {
        // Поддержка англ/рус вариантов личного аккаунта
        final snapUserEn = await db.collection('users').where('accountType', isEqualTo: 'user').get();
        final snapUserRu = await db.collection('users').where('accountType', isEqualTo: 'Личный').get();

        for (var doc in snapUserEn.docs) {
          userIds.add(doc.id);
        }
        for (var doc in snapUserRu.docs) {
          userIds.add(doc.id);
        }

        // Если список мал, проверяем пользователей без прямо указанного accountType (по умолчанию Личный)
        if (userIds.isEmpty) {
          final snapAll = await db.collection('users').get();
          for (var doc in snapAll.docs) {
            final type = doc.data()['accountType'];
            if (type == null || (type != 'business' && type != 'Бизнес')) {
              userIds.add(doc.id);
            }
          }
        }
      } else if (target == 'Водители Такси') {
        // 1. Поиск в driver_verifications (подтвержденные авто)
        final snapVerifApproved = await db
            .collection('driver_verifications')
            .where('status', isEqualTo: 'approved')
            .get();
        final snapVerifAi = await db
            .collection('driver_verifications')
            .where('status', isEqualTo: 'approved_by_ai')
            .get();

        for (var doc in snapVerifApproved.docs) {
          final uid = doc.data()['userId'];
          if (uid != null && uid.toString().isNotEmpty) userIds.add(uid.toString());
        }
        for (var doc in snapVerifAi.docs) {
          final uid = doc.data()['userId'];
          if (uid != null && uid.toString().isNotEmpty) userIds.add(uid.toString());
        }

        // 2. Также проверяем флаг водителя в объекте пользователя
        final snapDriverFlag = await db.collection('users').where('isTaxiDriver', isEqualTo: true).get();
        for (var doc in snapDriverFlag.docs) {
          userIds.add(doc.id);
        }
      }
    } catch (e) {
      debugPrint('[AdminNotifications] Error fetching target user IDs: $e');
    }

    return userIds.toList();
  }

  /// Предварительный подсчет получателей при смене фильтра
  Future<void> _loadAudienceCount() async {
    if (!mounted) return;
    setState(() => _isLoadingCount = true);
    
    final ids = await _fetchTargetUserIds(_selectedTarget);
    
    if (mounted) {
      setState(() {
        _targetUserCount = ids.length;
        _isLoadingCount = false;
      });
    }
  }

  /// Запуск высокопроизводительной батчевой рассылки
  void _send() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполните заголовок и текст рассылки!'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
      _sentCount = 0;
      _totalCount = 0;
    });

    try {
      final userIds = await _fetchTargetUserIds(_selectedTarget);

      if (userIds.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Нет активных пользователей в выбранной целевой аудитории!'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          setState(() => _isSending = false);
        }
        return;
      }

      setState(() {
        _totalCount = userIds.length;
      });

      final db = FirebaseFirestore.instance;
      const chunkSize = 400; // Безопасный объем батча (< 500 Firestore limit)
      
      for (int i = 0; i < userIds.length; i += chunkSize) {
        final chunk = userIds.sublist(i, i + chunkSize > userIds.length ? userIds.length : i + chunkSize);
        WriteBatch batch = db.batch();

        for (final userId in chunk) {
          final notifRef = db.collection('users').doc(userId).collection('notifications').doc();

          batch.set(notifRef, {
            'title': title,
            'body': body,
            'timestamp': FieldValue.serverTimestamp(),
            'type': 'system',
            'isRead': false,
            'senderId': FirebaseAuth.instance.currentUser?.uid ?? 'admin',
            'data': {
              'sender': 'admin_broadcast',
              'targetAudience': _selectedTarget,
            }
          });
        }

        await batch.commit();

        if (mounted) {
          setState(() {
            _sentCount += chunk.length;
          });
        }

        // Небольшая задержка для сохранения плавности UI и избежания сетевых пиков
        await Future.delayed(const Duration(milliseconds: 50));
      }

      if (mounted) {
        setState(() => _isSending = false);
        _titleController.clear();
        _bodyController.clear();
        _showSuccessDialog(_totalCount);
        _loadAudienceCount();
      }
    } catch (e) {
      debugPrint('[AdminNotifications] Broadcast failed: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отправке рассылки: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccessDialog(int deliveredTotal) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.bold), color: Colors.green, size: 56),
            ),
            const SizedBox(height: 20),
            Text(
              'Рассылка доставлена! 🎉',
              style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildStatRow('Аудитория:', _selectedTarget),
                  const Divider(height: 12),
                  _buildStatRow('Получателей:', '$deliveredTotal пользователей'),
                  const Divider(height: 12),
                  _buildStatRow('Push-статус:', 'Отправлено в шторку 🚀'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text('Отлично', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final progress = _totalCount > 0 ? (_sentCount / _totalCount) : 0.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Рассылка сообщений', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('ЦЕЛЕВАЯ АУДИТОРИЯ'),
            const SizedBox(height: 12),
            _buildTargetSelector(colorScheme),
            const SizedBox(height: 28),
            _buildSectionTitle('СОДЕРЖАНИЕ СООБЩЕНИЯ'),
            const SizedBox(height: 12),
            _buildTextField('Заголовок рассылки', _titleController, PhosphorIcons.textT(), maxLength: 60),
            const SizedBox(height: 16),
            _buildTextField('Текст Push-уведомления', _bodyController, PhosphorIcons.textAlignLeft(), maxLines: 4, maxLength: 250),
            const SizedBox(height: 28),
            _buildSectionTitle('ИНТЕРАКТИВНЫЙ ПРЕДПРОСМОТР'),
            const SizedBox(height: 12),
            _buildPreviewCard(colorScheme),
            const SizedBox(height: 36),
            if (_isSending) _buildProgressIndicator(progress),
            if (!_isSending) _buildSendButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
        title,
        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey[600], letterSpacing: 1.2),
      );

  Widget _buildTargetSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTarget,
              isExpanded: true,
              icon: Icon(PhosphorIcons.caretDown(), size: 20),
              onChanged: _isSending
                  ? null
                  : (v) {
                      if (v != null) {
                        setState(() => _selectedTarget = v);
                        _loadAudienceCount();
                      }
                    },
              items: _targets
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
                      ))
                  .toList(),
            ),
          ),
          const Divider(height: 20),
          Row(
            children: [
              Icon(PhosphorIcons.users(), size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Text(
                'Найдено получателей:',
                style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              _isLoadingCount
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_targetUserCount чел.',
                        style: GoogleFonts.inter(color: Colors.blueAccent, fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    PhosphorIconData icon, {
    int maxLines = 1,
    int? maxLength,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        maxLength: maxLength,
        enabled: !_isSending,
        onChanged: (_) => setState(() {}),
        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: Colors.blueAccent)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.15))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ColorScheme colorScheme) {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.notifications_active, color: Colors.amberAccent, size: 16),
              ),
              const SizedBox(width: 10),
              Text(
                'IQ MARKET PUSH',
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.1),
              ),
              const Spacer(),
              Text('СЕЙЧАС', style: GoogleFonts.inter(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            title.isEmpty ? 'Заголовок уведомления' : title,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            body.isEmpty ? 'Текст вашего Push-сообщения появится на экранах пользователей в точности в таком виде.' : body,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(double progress) {
    final percentage = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Выполняется отправка...', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('$percentage%', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: Colors.blueAccent, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Отправлено: $_sentCount из $_totalCount сообщений',
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    final isReady = _titleController.text.trim().isNotEmpty && _bodyController.text.trim().isNotEmpty && !_isSending;

    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: isReady ? _send : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          disabledBackgroundColor: Colors.grey[300],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: isReady ? 4 : 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIcons.paperPlaneTilt(PhosphorIconsStyle.bold), size: 22),
            const SizedBox(width: 12),
            Text(
              _isLoadingCount 
                  ? 'РАССЫЛКА (загрузка...)' 
                  : 'ОТПРАВИТЬ РАССЫЛКУ (${_targetUserCount > 0 ? _targetUserCount : "все"})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 0.5, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

