import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:iqmarket/screens/admin/admin_ads_screen.dart';
import 'package:iqmarket/screens/admin/admin_users_screen.dart';
import 'package:iqmarket/screens/admin/admin_notifications_screen.dart';
import 'package:iqmarket/screens/admin/admin_reports_screen.dart';
import 'package:iqmarket/screens/admin/admin_dashboard_screen.dart';
import 'package:iqmarket/services/ad_service.dart';
import 'package:iqmarket/services/user_service.dart';



class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  @override
  void initState() {
    super.initState();
    // Глобальная чистка архива (раз в месяц), если зашел админ
    AdService.runGlobalCleanupIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Светлый фон (Slate 50)
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('IQ УПРАВЛЕНИЕ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
        centerTitle: true,
      leading: Navigator.canPop(context)
          ? IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
              onPressed: () => Navigator.pop(context),
            )
          : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 32),
            
            // Сетка статистики (Light Glass)
            Row(
              children: [
                _buildQuickStat('АКТИВНЫЕ', FirebaseFirestore.instance.collection('ads').where('active', isEqualTo: true).count().get(), PhosphorIcons.chartLineUp(), const Color(0xFF4A80F0)),
                const SizedBox(width: 16),
                _buildQuickStat('ПОЛЬЗОВАТЕЛИ', FirebaseFirestore.instance.collection('users').count().get(), PhosphorIcons.usersThree(), const Color(0xFF8B5CF6)),
              ],
            ),
            
            const SizedBox(height: 40),
            Text('ИНСТРУМЕНТЫ', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.5)),
            const SizedBox(height: 20),
            
            // Сетка инструментов
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.9,
              children: [
                _buildToolCard(context, 'Аналитика', 'Пульс рынка', PhosphorIcons.chartPieSlice(), Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminDashboardScreen()))),
                _buildToolCard(context, 'Модерация', 'Контроль контента', PhosphorIcons.shieldCheck(), Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAdsScreen()))),
                _buildToolCard(context, 'Юзеры', 'Сообщество', PhosphorIcons.userList(), Colors.indigo, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminUsersScreen()))),
                _buildToolCard(context, 'Рассылка', 'Push-уведомления', PhosphorIcons.paperPlaneTilt(), Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminNotificationsScreen()))),
                _buildToolCard(context, 'Жалобы', 'Конфликты', PhosphorIcons.warningCircle(), Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminReportsScreen()))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Добро пожаловать', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
        const SizedBox(height: 4),
        Row(
          children: [
            const CircleAvatar(radius: 4, backgroundColor: Color(0xFF10B981)),
            const SizedBox(width: 8),
            Text('СИСТЕМА ОНЛАЙН', style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF10B981))),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStat(String label, Future<AggregateQuerySnapshot> future, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: color.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))],
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 20),
            FutureBuilder<AggregateQuerySnapshot>(
              future: future,
              builder: (context, snapshot) {
                final val = snapshot.hasData ? snapshot.data!.count.toString() : '...';
                return Text(val, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A)));
              }
            ),
            Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildToolCard(BuildContext context, String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 16),
              Text(title, style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
              const SizedBox(height: 4),
              Text(subtitle, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }
}



