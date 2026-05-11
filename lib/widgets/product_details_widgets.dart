import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:iqmarket/models/ad_model.dart';

class ProductDetailsHeader extends StatelessWidget {
  final Map<String, dynamic> ad;
  final String Function(String) translate;
  
  const ProductDetailsHeader({super.key, required this.ad, required this.translate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final price = ad['price'].toString().contains('₸') ? ad['price'].toString() : '${NumberFormat.decimalPattern('ru').format(ad['price'])} ₸';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, letterSpacing: -1.5),
              ),
              _buildConditionBadge(ad['condition'] ?? 'Б/У', theme),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            ad['title'],
            style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface, height: 1.2, letterSpacing: -0.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.location_on_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(ad['location'], style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 16),
              Icon(Icons.access_time_filled_rounded, size: 16, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 4),
              Text(translate('time_ago'), style: GoogleFonts.inter(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 24),
          _buildDivider(theme),
          const SizedBox(height: 24),
          Text(
            translate('description'),
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 12),
          Text(
            ad['description'],
            style: GoogleFonts.inter(fontSize: 15, color: theme.colorScheme.onSurface.withValues(alpha: 0.8), height: 1.6, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionBadge(String condition, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: condition == 'Новый' ? const Color(0xFF22C55E).withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        condition.toUpperCase(),
        style: GoogleFonts.inter(
          color: condition == 'Новый' ? const Color(0xFF16A34A) : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Container(height: 1, width: double.infinity, color: theme.colorScheme.onSurface.withValues(alpha: 0.05));
  }
}

class ProductSellerCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final String lang;
  final String Function(String) translate;
  final VoidCallback onTap;

  const ProductSellerCard({
    super.key, 
    required this.ad, 
    required this.lang, 
    required this.translate, 
    required this.onTap
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.1), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(radius: 30, backgroundImage: NetworkImage(ad['userImage'] ?? 'https://i.pravatar.cc/150?u=seller')),
                  if (ad['isVerified'] ?? false)
                    Positioned(bottom: 0, right: 0, child: Container(padding: const EdgeInsets.all(2), decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: const Icon(Icons.verified, color: Color(0xFF4A80F0), size: 18))),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ad['userName'], style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                    Text(ad['accType'] == 'Бизнес' ? 'Бизнес-аккаунт' : 'Частное лицо', style: GoogleFonts.inter(fontSize: 13, color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              _buildRating(theme),
            ],
          ),
          const SizedBox(height: 20),
          Container(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _sellerStat(theme, '12', translate('ads_stat')),
              _sellerStat(theme, '2 года', translate('on_market')),
              _sellerStat(theme, '50+', lang == 'Русский' ? 'Продаж' : (lang == 'Қазақша' ? 'Сатылым' : 'Сетиш')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRating(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: const Color(0xFFF59E0B).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
          const SizedBox(width: 4),
          Text('4.9', style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFFD97706))),
        ],
      ),
    );
  }

  Widget _sellerStat(ThemeData theme, String val, String label) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class ProductLocationSection extends StatelessWidget {
  final AdModel ad;
  final String Function(String) translate;

  const ProductLocationSection({super.key, required this.ad, required this.translate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final city = ad.location.isEmpty ? 'Чунджа' : ad.location;

    
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF4A80F0).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.location_on_rounded, color: Color(0xFF4A80F0), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(translate('location_title'), style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text(city, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
