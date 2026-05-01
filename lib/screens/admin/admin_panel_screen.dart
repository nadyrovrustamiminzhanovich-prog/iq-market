import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:iqmarket/screens/admin/admin_ads_screen.dart';
import 'package:iqmarket/screens/admin/admin_users_screen.dart';
import 'package:iqmarket/screens/admin/admin_notifications_screen.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Панель управления', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatCard(context, 'Активные объявления', '1,248', PhosphorIcons.newspaper(), Colors.blue),
            const SizedBox(height: 15),
            _buildStatCard(context, 'Новые пользователи', '+84 сегодня', PhosphorIcons.users(), Colors.green),
            const SizedBox(height: 30),
            Text('Инструменты', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 15),
            _buildAdminTile(
              context, 
              'Модерация объявлений', 
              'Проверка и удаление контента', 
              PhosphorIcons.shieldCheck(), 
              Colors.orange,
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen())),
            ),
            _buildAdminTile(
              context, 
              'Пользователи', 
              'Бан, верификация и статистика', 
              PhosphorIcons.userList(), 
              Colors.purple,
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen())),
            ),
            _buildAdminTile(
              context, 
              'Push-уведомления', 
              'Рассылка на все устройства', 
              PhosphorIcons.paperPlaneTilt(), 
              Colors.blue,
              () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminNotificationsScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, PhosphorIconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
              Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context, String title, String subtitle, PhosphorIconData icon, Color color, VoidCallback onTap) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      ),
    );
  }
}
