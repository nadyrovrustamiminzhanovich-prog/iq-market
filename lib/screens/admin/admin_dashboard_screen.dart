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
        centerTitle: true,
        title: Text('АНАЛИТИКА РЫНКА', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 0.5, fontSize: 16)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('ОБЗОР АКТИВНОСТИ И РЫНКА'),
            const SizedBox(height: 14),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ads').limit(200).snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                final totalAds = docs.length;
                final activeAds = docs.where((d) => (d.data() as Map)['active'] == true).length;
                final pendingAds = docs.where((d) => (d.data() as Map)['status'] == 'pending').length;
                final archivedAds = docs.where((d) => (d.data() as Map)['active'] != true).length;
                
                return Column(
                  children: [
                    Row(
                      children: [
                        _buildStatCard('ВСЕГО ТОВАРОВ', totalAds.toString(), PhosphorIcons.package(), const Color(0xFF4A80F0)),
                        const SizedBox(width: 12),
                        _buildStatCard('АКТИВНЫЕ', activeAds.toString(), PhosphorIcons.checkCircle(), const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStatCard('НА ПРОВЕРКЕ', pendingAds.toString(), PhosphorIcons.shieldCheck(), Colors.orange),
                        const SizedBox(width: 12),
                        _buildStatCard('В АРХИВЕ', archivedAds.toString(), PhosphorIcons.archive(), Colors.blueGrey),
                      ],
                    ),
                  ],
                );
              }
            ),
            
            const SizedBox(height: 32),
            _buildSectionTitle('РАСПРЕДЕЛЕНИЕ КАТЕГОРИЙ'),
            const SizedBox(height: 14),
            _buildCategoryChart(),
            
            const SizedBox(height: 32),
            _buildSectionTitle('РЕЙТИНГ ГОРОДОВ И РЕГИОНОВ'),
            const SizedBox(height: 14),
            _buildCityLeaderboard(),

            const SizedBox(height: 32),
            _buildSectionTitle('ДИНАМИКА ПУЛЬСА ПЛАТФОРМЫ'),
            const SizedBox(height: 14),
            _buildGrowthChart(),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title, 
      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF94A3B8), letterSpacing: 1.2),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: Colors.grey.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
            const SizedBox(height: 14),
            Text(value, style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF0F172A))),
            const SizedBox(height: 2),
            Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.grey[400], letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ads').limit(200).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          Map<String, int> counts = {};
          int total = 0;
          for (var doc in snapshot.data!.docs) {
            String cat = (doc.data() as Map<String, dynamic>?)?['category'] ?? 'Другое';
            counts[cat] = (counts[cat] ?? 0) + 1;
            total++;
          }
          
          final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final top = sorted.take(5).toList();
          final colors = [const Color(0xFF6366F1), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFFEC4899), const Color(0xFF8B5CF6)];

          return Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 45,
                    sections: top.asMap().entries.map((e) {
                      return PieChartSectionData(
                        color: colors[e.key % colors.length],
                        value: e.value.value.toDouble(),
                        title: '${((e.value.value / (total == 0 ? 1 : total)) * 100).toInt()}%',
                        radius: 50,
                        titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Column(
                children: top.asMap().entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[e.key % colors.length], shape: BoxShape.circle)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(e.value.key, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B)))),
                        Text('${e.value.value} объявлений', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.grey[600])),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildCityLeaderboard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('ads').limit(200).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          Map<String, int> cities = {};
          for (var doc in snapshot.data!.docs) {
            String city = (doc.data() as Map<String, dynamic>?)?['location'] ?? 'Чунджа';
            cities[city] = (cities[city] ?? 0) + 1;
          }

          final sorted = cities.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
          final topCities = sorted.take(4).toList();

          return Column(
            children: topCities.asMap().entries.map((e) {
              final rank = e.key + 1;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: rank == 1 ? Colors.amber.withValues(alpha: 0.15) : const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('#$rank', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: rank == 1 ? Colors.amber[900] : Colors.grey[600]))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(e.value.key, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF4A80F0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('${e.value.value} тов.', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF4A80F0))),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildGrowthChart() {
    return Container(
      height: 220,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [const FlSpot(0, 3), const FlSpot(1, 1), const FlSpot(2, 4), const FlSpot(3, 2), const FlSpot(4, 5), const FlSpot(5, 3), const FlSpot(6, 6)],
              isCurved: true,
              color: const Color(0xFF6366F1),
              barWidth: 3.5,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [const Color(0xFF6366F1).withValues(alpha: 0.15), const Color(0xFF6366F1).withValues(alpha: 0)])),
            ),
          ],
        ),
      ),
    );
  }
}
