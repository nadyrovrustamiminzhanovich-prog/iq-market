import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AdminTaxiScreen extends StatefulWidget {
  const AdminTaxiScreen({super.key});

  @override
  State<AdminTaxiScreen> createState() => _AdminTaxiScreenState();
}

class _AdminTaxiScreenState extends State<AdminTaxiScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text('ТАКСИ МОДЕРАЦИЯ', style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: const Color(0xFF0F172A), letterSpacing: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context)
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Поиск по именам или городам...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 18, color: Colors.grey[400]),
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: const Color(0xFF4A80F0),
                indicatorWeight: 3,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: Colors.grey[400],
                labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1),
                tabs: const [Tab(text: 'ЗАКАЗЫ (ПАССАЖИРЫ)'), Tab(text: 'ПОЕЗДКИ (ВОДИТЕЛИ)')],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrdersList(),
          _buildRidesList(),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('taxi_orders')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['passengerName'] ?? '').toString().toLowerCase();
          final from = (data['from'] ?? '').toString().toLowerCase();
          final to = (data['to'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || from.contains(q) || to.contains(q);
        }).toList();

        if (docs.isEmpty) return _buildEmptyState('Нет активных заказов пассажиров');

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return _buildTaxiCard(data, isOrder: true);
          },
        );
      },
    );
  }

  Widget _buildRidesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('taxi_rides')
          .orderBy('createdAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['driverName'] ?? '').toString().toLowerCase();
          final from = (data['from'] ?? '').toString().toLowerCase();
          final to = (data['to'] ?? '').toString().toLowerCase();
          final q = _searchQuery.toLowerCase();
          return name.contains(q) || from.contains(q) || to.contains(q);
        }).toList();

        if (docs.isEmpty) return _buildEmptyState('Нет активных поездок водителей');

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return _buildTaxiCard(data, isOrder: false);
          },
        );
      },
    );
  }

  Widget _buildTaxiCard(Map<String, dynamic> data, {required bool isOrder}) {
    final String id = data['id'] ?? '';
    final String name = isOrder ? (data['passengerName'] ?? 'Пассажир') : (data['driverName'] ?? 'Водитель');
    final String from = data['from'] ?? '';
    final String to = data['to'] ?? '';
    final int price = (data['price'] ?? 0) as int;
    // ignore: unused_local_variable
    final int seats = (data['seats'] ?? 1) as int;
    final String comment = data['comment'] ?? '';
    final String phone = isOrder ? (data['passengerPhone'] ?? '') : (data['driverPhone'] ?? '');
    final String status = data['status'] ?? 'active';

    Color statusColor = const Color(0xFF4A80F0);
    String statusText = 'Активен';
    if (status == 'accepted') {
      statusColor = const Color(0xFF10B981);
      statusText = 'Принят';
    } else if (status == 'completed') {
      statusColor = Colors.grey;
      statusText = 'Завершен';
    } else if (status == 'cancelled') {
      statusColor = Colors.redAccent;
      statusText = 'Отменен';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFF1F5F9),
                  backgroundImage: data['passengerImg'] != null && data['passengerImg'].toString().isNotEmpty
                      ? NetworkImage(data['passengerImg'])
                      : (data['driverImg'] != null && data['driverImg'].toString().isNotEmpty
                          ? NetworkImage(data['driverImg'])
                          : null),
                  child: (data['passengerImg'] == null || data['passengerImg'].toString().isEmpty) &&
                         (data['driverImg'] == null || data['driverImg'].toString().isEmpty)
                      ? Icon(isOrder ? Icons.person : Icons.directions_car, color: const Color(0xFF64748B))
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: const Color(0xFF0F172A), fontSize: 14)),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                            child: Text(statusText.toUpperCase(), style: GoogleFonts.inter(color: statusColor, fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
                          ),
                          const SizedBox(width: 8),
                          if (phone.isNotEmpty)
                            Text(phone, style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                Text('$price ₸', style: GoogleFonts.inter(fontWeight: FontWeight.w900, color: const Color(0xFF4A80F0), fontSize: 18)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
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
                      const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$from → $to',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF1E293B), fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        '"$comment"',
                        style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isOrder && data['driverCar'] != null && data['driverCar'].toString().isNotEmpty) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.car(), size: 14, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Авто: ${data['driverCar']} [${data['driverPlate'] ?? 'Б/Н'}]',
                      style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleDelete(id, isOrder, name),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('УДАЛИТЬ ЗАПИСЬ', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleDelete(String id, bool isOrder, String name) async {
    HapticFeedback.heavyImpact();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('УДАЛИТЬ ЗАПИСЬ?', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
        content: Text('Вы действительно хотите навсегда удалить эту поездку/заказ пользователя "$name" из системы?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ОТМЕНА')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('УДАЛИТЬ'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final collection = isOrder ? 'taxi_orders' : 'taxi_rides';
      await FirebaseFirestore.instance.collection(collection).doc(id).delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись успешно удалена из базы данных! 🗑️'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.taxi(), size: 60, color: Colors.grey[200]),
          const SizedBox(height: 16),
          Text(msg.toUpperCase(), style: GoogleFonts.outfit(color: Colors.grey[300], fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
        ],
      ),
    );
  }
}
