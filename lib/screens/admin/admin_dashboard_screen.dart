import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:fl_chart/fl_chart.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('АНАЛИТИКА', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('ОБЗОР РЫНКА'),
            const SizedBox(height: 20),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ads').limit(100).snapshots(),
              builder: (context, snapshot) {
                final totalAds = snapshot.data?.docs.length ?? 0;
                final pendingAds = snapshot.data?.docs.where((d) => (d.data() as Map)['status'] == 'pending').length ?? 0;
                
                return Row(
                  children: [
                    _buildStatCard('ВСЕГО ТОВАРОВ', totalAds.toString(), PhosphorIcons.package(), const Color(0xFF4A80F0)),
                    const SizedBox(width: 12),
                    _buildStatCard('НА ПРОВЕРКЕ', pendingAds.toString(), PhosphorIcons.shieldCheck(), Colors.orange),
                  ],
                );
              }
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle('РАСПРЕДЕЛЕНИЕ КАТЕГОРИЙ'),
            const SizedBox(height: 20),
            _buildCategoryChart(),
            
            const SizedBox(height: 32),
            _buildSectionTitle('РОСТ ПОЛЬЗОВАТЕЛЕЙ'),
            const SizedBox(height: 20),
            _buildGrowthChart(),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 1.5));
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 16),
            Text(value, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            Text(label, style: GoogleFonts.outfit(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey[400], letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    return Container(
      height: 280,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.grey.withOpacity(0.05))),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ads').limit(100).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          Map<String, int> counts = {};
          for (var doc in snapshot.data!.docs) {
            String cat = doc['category'] ?? 'Другое';
            counts[cat] = (counts[cat] ?? 0) + 1;
          }
          
          final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final top = sorted.take(5).toList();

          return PieChart(
            PieChartData(
              sectionsSpace: 4,
              centerSpaceRadius: 50,
              sections: top.asMap().entries.map((e) {
                final colors = [const Color(0xFF6366F1), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFFEC4899), const Color(0xFF8B5CF6)];
                return PieChartSectionData(
                  color: colors[e.key % colors.length],
                  value: e.value.value.toDouble(),
                  title: '${e.value.key}\n${e.value.value}',
                  radius: 60,
                  titleStyle: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                );
              }).toList(),
            ),
          );
        }
      ),
    );
  }

  Widget _buildGrowthChart() {
    return Container(
      height: 240,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.grey.withOpacity(0.05))),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [const FlSpot(0, 3), const FlSpot(1, 1), const FlSpot(2, 4), const FlSpot(3, 2), const FlSpot(4, 5), const FlSpot(5, 3), const FlSpot(6, 4)],
              isCurved: true,
              color: const Color(0xFF6366F1),
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFF6366F1).withOpacity(0.1), const Color(0xFF6366F1).withOpacity(0)])),
            ),
          ],
        ),
      ),
    );
  }
}


