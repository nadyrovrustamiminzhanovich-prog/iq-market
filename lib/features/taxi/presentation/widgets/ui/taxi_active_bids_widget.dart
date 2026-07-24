// ─────────────────────────────────────────────────────────────────────────────
// FILE: lib/features/taxi/presentation/widgets/ui/taxi_active_bids_widget.dart
// STEP: #22 | СЛОЙ: widgets/ui
// ОТВЕЧАЕТ ЗА: список активных ставок торгов (принять / отклонить / детали)
// ЗАВИСИМОСТИ: TaxiTheme, TaxiProvider (acceptBid/rejectBid), FirebaseAuth,
//              NotificationService, CachedNetworkImage
//              Колбек onBidTap — открытие деталей остаётся в родителе
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/theme/taxi_theme.dart';
import 'package:iqmarket/providers/taxi_provider.dart';
import 'package:iqmarket/services/notification_service.dart';

/// Карточка активных ставок торгов.
///
/// Показывается в пассажирском и водительском view когда есть активные биды.
/// Кнопки «Принять» / «Отклонить» вызывают методы provider напрямую.
/// Тап по строке делегируется через [onBidTap] — родитель открывает детали.
class TaxiActiveBidsWidget extends StatelessWidget {
  final TaxiProvider provider;
  final TaxiTheme t;

  /// Колбек: родитель показывает детальный bottom sheet по биду
  final void Function(Map<String, dynamic> bid) onBidTap;

  const TaxiActiveBidsWidget({
    super.key,
    required this.provider,
    required this.t,
    required this.onBidTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBids = provider.activeBids;
    final currentUser = FirebaseAuth.instance.currentUser;

    // Скрываем виджет если нет данных
    if (activeBids.isEmpty || currentUser == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4A80F0).withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(color: const Color(0xFF4A80F0).withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок ──────────────────────────────────────────────────
          Row(children: [
            const Icon(Icons.bolt_rounded, color: Color(0xFF4A80F0), size: 20),
            const SizedBox(width: 6),
            Text(
              'Активные предложения торгов (${activeBids.length})',
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 13, color: const Color(0xFF1E293B), letterSpacing: -0.2),
            ),
          ]),
          const SizedBox(height: 10),
          // ── Список ставок ──────────────────────────────────────────────
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeBids.length,
            separatorBuilder: (_, __) => const Divider(color: Color(0xFFF1F5F9), height: 12),
            itemBuilder: (ctx, index) => _BidRow(
              bid: activeBids[index],
              currentUid: currentUser.uid,
              t: t,
              provider: provider,
              onTap: () {
                HapticFeedback.selectionClick();
                onBidTap(activeBids[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Внутренняя строка ставки ──────────────────────────────────────────────────
class _BidRow extends StatefulWidget {
  final Map<String, dynamic> bid;
  final String currentUid;
  final TaxiTheme t;
  final TaxiProvider provider;
  final VoidCallback onTap;

  const _BidRow({
    required this.bid,
    required this.currentUid,
    required this.t,
    required this.provider,
    required this.onTap,
  });

  @override
  State<_BidRow> createState() => _BidRowState();
}

class _BidRowState extends State<_BidRow> {
  bool isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final bool isSender = widget.bid['senderId'] == widget.currentUid;
    final int price     = widget.bid['offeredPrice'] ?? 0;
    final String name   = widget.bid['senderName']   ?? 'Пользователь';
    final String bidId  = widget.bid['id']           ?? '';
    final String? img   = widget.bid['senderImg']?.toString().isNotEmpty == true ? widget.bid['senderImg'] : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: isProcessing ? null : widget.onTap,
      child: Row(children: [
        // Аватар
        CircleAvatar(
          radius: 20,
          backgroundColor: widget.t.bg,
          backgroundImage: img != null ? CachedNetworkImageProvider(img) : null,
          child: img == null ? Icon(Icons.person, color: widget.t.sub) : null,
        ),
        const SizedBox(width: 12),
        // Имя + статус
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isSender ? 'Ваше предложение' : name,
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, color: widget.t.text)),
          const SizedBox(height: 2),
          Text(isSender ? 'Ожидание решения • $price ₸' : 'Предлагает цену: $price ₸',
              style: GoogleFonts.inter(fontSize: 11, color: widget.t.sub)),
        ])),
        // Действия
        if (isSender)
          _badge('В обработке', Colors.amber[800]!, Colors.amber.withValues(alpha: 0.15))
        else if (isProcessing)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          Row(children: [
            _actionBtn(widget.provider.translate('accept_btn'), const Color(0xFF84CC16), Colors.white, () async {
              if (isProcessing) return;
              HapticFeedback.mediumImpact();
              setState(() => isProcessing = true);
              try {
                await widget.provider.acceptBid(bidId);
                if (mounted) {
                  NotificationService.notify(context, widget.provider.translate('acceptedTitle'), widget.provider.translate('agreedToPriceMsg').replaceAll('{price}', price.toString()), isSuccess: true);
                }
              } catch (e) {
                if (mounted) {
                  NotificationService.notify(context, widget.provider.translate('errorTitle'), widget.provider.translate('errAcceptOffer'), isSuccess: false);
                }
              } finally {
                if (mounted) {
                  setState(() => isProcessing = false);
                }
              }
            }),
            const SizedBox(width: 8),
            _actionBtn(widget.provider.translate('decline_btn'), Colors.red.withValues(alpha: 0.1), Colors.red, () async {
              if (isProcessing) return;
              HapticFeedback.lightImpact();
              setState(() => isProcessing = true);
              try {
                await widget.provider.rejectBid(bidId);
                if (mounted) {
                  NotificationService.notify(context, widget.provider.translate('declinedTitle'), widget.provider.translate('declinedOfferMsg'), isSuccess: false);
                }
              } catch (e) {
                if (mounted) {
                  NotificationService.notify(context, widget.provider.translate('errorTitle'), widget.provider.translate('errDeclineOffer'), isSuccess: false);
                }
              } finally {
                if (mounted) {
                  setState(() => isProcessing = false);
                }
              }
            }),
          ]),
      ]),
    );
  }

  Widget _badge(String label, Color textColor, Color bgColor) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
    child: Text(label, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 10)),
  );

  Widget _actionBtn(String label, Color bg, Color textColor, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
      ),
    ),
  );
}
