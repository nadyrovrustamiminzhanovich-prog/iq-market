import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isSending = false;

  final List<String> _targets = ['Все пользователи', 'Только Бизнес', 'Только Личные', 'Водители Такси'];

  void _send() async {
    if (_titleController.text.isEmpty || _bodyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните заголовок и текст!'), backgroundColor: Colors.orange)
      );
      return;
    }
    
    setState(() => _isSending = true);

    try {
      final title = _titleController.text.trim();
      final body = _bodyController.text.trim();
      
      Query query = FirebaseFirestore.instance.collection('users');
      
      if (_selectedTarget == 'Только Бизнес') {
        query = query.where('accountType', isEqualTo: 'business');
      } else if (_selectedTarget == 'Только Личные') {
        query = query.where('accountType', isEqualTo: 'user');
      } else if (_selectedTarget == 'Водители Такси') {
        query = query.where('isVerified', isEqualTo: true);
      }
      
      final querySnapshot = await query.get();
      final usersDocs = querySnapshot.docs;
      
      if (usersDocs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Нет пользователей в выбранной аудитории!'), backgroundColor: Colors.orange)
          );
        }
        setState(() => _isSending = false);
        return;
      }
      
      final db = FirebaseFirestore.instance;
      int chunkCount = 0;
      WriteBatch batch = db.batch();
      
      for (var userDoc in usersDocs) {
        final userId = userDoc.id;
        final notifRef = db.collection('users').doc(userId).collection('notifications').doc();
        
        batch.set(notifRef, {
          'title': title,
          'body': body,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'system',
          'isRead': false,
          'data': {'sender': 'admin_broadcast'}
        });
        
        chunkCount++;
        if (chunkCount >= 500) {
          await batch.commit();
          batch = db.batch();
          chunkCount = 0;
        }
      }
      
      if (chunkCount > 0) {
        await batch.commit();
      }

      if (mounted) {
        setState(() => _isSending = false);
        _titleController.clear();
        _bodyController.clear();
        _showSuccessDialog();
      }
    } catch (e) {
      debugPrint('[AdminNotifications] Send failed: $e');
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при отправке: $e'), backgroundColor: Colors.red)
        );
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(PhosphorIcons.checkCircle(), color: Colors.green, size: 64),
            ),
            const SizedBox(height: 24),
            Text('Отправлено!', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Рассылка успешно доставлена целевой аудитории: $_selectedTarget', 
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.grey, fontSize: 14)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Отлично', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Рассылка', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('АУДИТОРИЯ'),
            const SizedBox(height: 12),
            _buildTargetSelector(colorScheme),
            const SizedBox(height: 32),
            _buildSectionTitle('СОДЕРЖАНИЕ'),
            const SizedBox(height: 12),
            _buildTextField('Заголовок рассылки', _titleController, PhosphorIcons.textT()),
            const SizedBox(height: 16),
            _buildTextField('Текст сообщения', _bodyController, PhosphorIcons.textAlignLeft(), maxLines: 4),
            const SizedBox(height: 32),
            _buildSectionTitle('ПРЕДПРОСМОТР'),
            const SizedBox(height: 12),
            _buildPreviewCard(colorScheme),
            const SizedBox(height: 40),
            _buildSendButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(
    title,
    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2),
  );

  Widget _buildTargetSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTarget,
          isExpanded: true,
          icon: Icon(PhosphorIcons.caretDown(), size: 18),
          onChanged: (v) => setState(() => _selectedTarget = v!),
          items: _targets.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontWeight: FontWeight.w600)))).toList(),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, PhosphorIconData icon, {int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: (v) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 20, color: Colors.blue)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1))),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF4A80F0), Color(0xFF3B6AD1)]),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('УВЕДОМЛЕНИЕ', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
              const Spacer(),
              Text('СЕЙЧАС', style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _titleController.text.isEmpty ? 'Заголовок появится здесь' : _titleController.text,
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          const SizedBox(height: 6),
          Text(
            _bodyController.text.isEmpty ? 'Текст вашего сообщения будет отображаться в этой области.' : _bodyController.text,
            style: GoogleFonts.inter(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isSending ? null : _send,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E293B),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        child: _isSending 
          ? const CircularProgressIndicator(color: Colors.white)
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(PhosphorIcons.paperPlaneTilt(), size: 24),
                const SizedBox(width: 12),
                Text('ОТПРАВИТЬ РАССЫЛКУ', style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              ],
            ),
      ),
    );
  }
}
