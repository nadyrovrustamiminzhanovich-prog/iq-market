import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/services/translation_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ChatBubble extends StatefulWidget {
  final MessageModel msg;
  final String? sellerAvatarUrl;
  final Color myBubbleColor;
  final Color otherBubbleColor;
  final Color textColor;
  final Color subTextColor;
  final Function(String, String) onPlayVoice;
  final bool isPlaying;
  final Duration currentPos;
  final Duration currentDur;
  final Function(MessageModel) onLongPress;
  final Function(String) onImageTap;
  final String lang;
  final String? localImagePath;
  final void Function(MessageModel)? onRetryUpload;

  const ChatBubble({
    super.key,
    required this.msg,
    this.sellerAvatarUrl,
    required this.myBubbleColor,
    required this.otherBubbleColor,
    required this.textColor,
    required this.subTextColor,
    required this.onPlayVoice,
    required this.isPlaying,
    required this.currentPos,
    required this.currentDur,
    required this.onLongPress,
    required this.onImageTap,
    this.localImagePath,
    this.onRetryUpload,
    this.onAcceptOffer,
    this.onDeclineOffer,
    this.onVoiceOffer,
    this.onCallOffer,
    this.lang = 'Русский',
  });

  /// Оба ответа на оффер асинхронные: под ними серверный вызов
  /// respondToOffer, и кнопка обязана ждать его результата, иначе
  /// пользователь успевает нажать вторую.
  final Future<void> Function()? onAcceptOffer;
  final Future<void> Function()? onDeclineOffer;
  final VoidCallback? onVoiceOffer;
  final VoidCallback? onCallOffer;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isOfferLoading = false;
  // Какая именно кнопка сейчас крутится — раньше обе кнопки читали один и
  // тот же _isOfferLoading и для disabled, и для спиннера, поэтому нажатие
  // «Отклонить» показывало спиннер и на «Принять» тоже. Сама блокировка
  // ОБЕИХ кнопок на время запроса (см. _isOfferLoading ниже) остаётся —
  // это защита от двойного/конфликтующего запроса, а не баг.
  String? _loadingOfferAction; // 'accept' | 'decline' | null

  @override
  Widget build(BuildContext context) {
    final bool isMe = widget.msg.senderId == UserService.currentUid;

    // Системное сообщение об исходе оффера — не пузырь участника, а
    // центрированная плашка. Текст берём по systemKey, чтобы читающий видел
    // его на своём языке: поле text хранит русский фолбэк для пуша.
    if (widget.msg.type == 'system') {
      return _buildSystemMessage();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: const Color(0xFF17212D),
              backgroundImage: (widget.sellerAvatarUrl != null && widget.sellerAvatarUrl!.startsWith('http')) 
                  ? CachedNetworkImageProvider(widget.sellerAvatarUrl!) 
                  : null,
              child: (widget.sellerAvatarUrl == null || !widget.sellerAvatarUrl!.startsWith('http')) 
                  ? const Icon(Icons.person, size: 14, color: Colors.white38) 
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => widget.onLongPress(widget.msg),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.72,
                  minWidth: widget.msg.type == 'audio' ? 160 : 0,
                ),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.msg.type == 'offer' 
                      ? Colors.white 
                      : (isMe ? null : widget.otherBubbleColor),
                  gradient: (widget.msg.type != 'offer' && isMe) ? const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF2563EB)], // Beautiful blue gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ) : null,
                  boxShadow: widget.msg.type == 'offer' ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                  border: widget.msg.type == 'offer' ? Border.all(color: const Color(0xFFE2E8F0), width: 1.5) : null,
                  borderRadius: widget.msg.type == 'offer'
                      ? BorderRadius.circular(24)
                      : BorderRadius.only(
                          topLeft: const Radius.circular(18), 
                          topRight: const Radius.circular(18), 
                          bottomLeft: Radius.circular(isMe ? 18 : 4), 
                          bottomRight: Radius.circular(isMe ? 4 : 18)
                        ),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  if (widget.msg.type == 'image')
                    Builder(builder: (context) {
                      final bool hasUrl = widget.msg.mediaUrl != null && widget.msg.mediaUrl!.isNotEmpty;
                      final bool isFailed = !hasUrl && widget.msg.uploadFailed;
                      return GestureDetector(
                        onTap: hasUrl
                            ? () => widget.onImageTap(widget.msg.mediaUrl!)
                            : (isFailed ? () => widget.onRetryUpload?.call(widget.msg) : null),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 200,
                            height: 200,
                            color: isMe ? Colors.black26 : Colors.grey[200],
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // 1. Show the Image (Local or Network)
                                Positioned.fill(
                                  child: hasUrl && widget.msg.mediaUrl!.startsWith('http')
                                      ? CachedNetworkImage(
                                          imageUrl: widget.msg.mediaUrl!,
                                          fit: BoxFit.cover,
                                          memCacheWidth: 400,
                                          errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                        )
                                      : (widget.localImagePath != null && widget.localImagePath!.isNotEmpty)
                                          ? Image.file(
                                              File(widget.localImagePath!),
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                            )
                                          : const Center(child: Icon(Icons.image_rounded, color: Colors.grey, size: 40)),
                                ),
                                // 2. Show the Upload/Failed/Loading Overlay
                                if (!hasUrl)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withValues(alpha: isFailed ? 0.55 : 0.4),
                                      child: Center(
                                        child: isFailed
                                            ? Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: const [
                                                  Icon(Icons.refresh_rounded, color: Colors.white, size: 28),
                                                  SizedBox(height: 4),
                                                  Text('Повторить', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                                ],
                                              )
                                            : const CircularProgressIndicator(
                                                strokeWidth: 3,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  if (widget.msg.type == 'audio') _AudioPlayerWidget(
                    msg: widget.msg,
                    isMe: isMe,
                    color: isMe ? Colors.white : const Color(0xFF3B82F6),
                    onPlay: widget.onPlayVoice,
                    isPlaying: widget.isPlaying,
                    currentPos: widget.currentPos,
                    currentDur: widget.currentDur,
                    lang: widget.lang,
                    onRetryUpload: widget.onRetryUpload,
                  ),
                  if (widget.msg.text.isNotEmpty && widget.msg.type == 'text')
                    Text(widget.msg.text, softWrap: true, style: TextStyle(color: isMe ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w500)),
                  if (widget.msg.type == 'offer') _buildOfferCard(context, isMe),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      DateFormat('HH:mm').format(widget.msg.timestamp), 
                      style: TextStyle(
                        fontSize: 10, 
                        color: widget.msg.type == 'offer' ? const Color(0xFF94A3B8) : (isMe ? Colors.white70 : const Color(0xFF64748B)),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      // ✅ WhatsApp-style галочки:
                      // 1 серая  = отправлено (isDelivered: false, isRead: false)
                      // 2 серые  = доставлено (isDelivered: true,  isRead: false)
                      // 2 синие  = прочитано  (isRead: true)
                      _buildCheckmarks(widget.msg),
                    ],
                  ]),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    final key = widget.msg.systemKey;
    final bool accepted = key == 'offer_accepted';
    final Color color = accepted ? const Color(0xFF10B981) : const Color(0xFFEF4444);

    // Неизвестный ключ (сообщение от более новой версии сервера) — показываем
    // text как есть, а не сырой ключ, который вернул бы t() при промахе.
    String label = widget.msg.text;
    if (key != null && key.isNotEmpty) {
      final translated = TranslationService.t('${key}_msg', widget.lang);
      if (translated != '${key}_msg') label = translated;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                accepted ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, bool isMe) {
    final status = widget.msg.offerStatus ?? 'pending';
    final isPending = status == 'pending';
    
    return Container(
      width: double.infinity,
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.handshake(PhosphorIconsStyle.fill), color: const Color(0xFF3B82F6), size: 20),
              const SizedBox(width: 8),
              Text(
                TranslationService.t('offer_price_label', widget.lang).toUpperCase(), 
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.8)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final double priceVal = double.tryParse(widget.msg.offerPrice ?? '0') ?? 0.0;
              // 'kk' поддержан пакетом intl — используем честную локаль для
              // казахского. 'ug' не поддержан (NumberFormat бросил бы
              // ArgumentError на неизвестной локали) — для уйгурского и
              // русского безопасно остаёмся на 'ru' (формат разделителей тот
              // же, разницы для пользователя нет, а падения не будет).
              final numLocale = widget.lang == 'Қазақша' ? 'kk' : 'ru';
              final formattedPrice = priceVal > 0
                  ? '${NumberFormat.decimalPattern(numLocale).format(priceVal.toInt())} ₸'
                  : '0 ₸';
              return Text(formattedPrice, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -0.5));
            },
          ),
          const SizedBox(height: 16),
          if (!isMe && isPending) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isOfferLoading ? null : () async {
                        setState(() { _isOfferLoading = true; _loadingOfferAction = 'decline'; });
                        try {
                          await widget.onDeclineOffer?.call();
                        } finally {
                          if (mounted) setState(() { _isOfferLoading = false; _loadingOfferAction = null; });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _loadingOfferAction == 'decline'
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 12, color: Color(0xFFEF4444)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(TranslationService.t('decline_btn', widget.lang), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Accept вернулся через сервер: обработчик вызывает
                // respondToOffer, а не пишет статус сам. _isOfferLoading
                // блокирует ОБЕ кнопки сразу — иначе двойной тап или
                // «Отклонить» поверх «Принять» уходили бы двумя запросами.
                // Спиннер при этом показываем только на нажатой (_loadingOfferAction).
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isOfferLoading ? null : () async {
                        setState(() { _isOfferLoading = true; _loadingOfferAction = 'accept'; });
                        try {
                          await widget.onAcceptOffer?.call();
                        } finally {
                          if (mounted) setState(() { _isOfferLoading = false; _loadingOfferAction = null; });
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _loadingOfferAction == 'accept'
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                      child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFF10B981)),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(TranslationService.t('accept_btn', widget.lang), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Договориться напрямую — по-прежнему доступно рядом с формальным
            // ответом. "Написать" убран по просьбе: чат и так открыт, кнопка
            // дублировала то, что пользователь уже видит на экране.
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: widget.onCallOffer,
                icon: const Icon(Icons.phone_in_talk_rounded, size: 16, color: Color(0xFF10B981)),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    TranslationService.t('call_btn', widget.lang),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF10B981)),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF10B981), width: 1.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: EdgeInsets.zero,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _getStatusColor(status).withValues(alpha: 0.2), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(status).toUpperCase(), 
                    style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':  return const Color(0xFF10B981);
      case 'rejected':  return const Color(0xFFEF4444);
      case 'cancelled': return const Color(0xFF94A3B8); // grey — buyer cancelled/replaced
      default:          return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted':  return Icons.check_circle_rounded;
      case 'rejected':  return Icons.cancel_rounded;
      case 'cancelled': return Icons.remove_circle_outline_rounded;
      default:          return Icons.access_time_filled_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted':  return TranslationService.t('offer_accepted', widget.lang);
      case 'rejected':  return TranslationService.t('offer_rejected', widget.lang);
      case 'cancelled': return TranslationService.t('offer_cancelled', widget.lang);
      default:          return TranslationService.t('offer_pending', widget.lang);
    }
  }

  /// ✅ WhatsApp-style галочки:
  /// • 1 серая  = сообщение отправлено на сервер (isDelivered: false, isRead: false)
  /// • 2 серые  = доставлено получателю, но не прочитано (isDelivered: true, isRead: false)
  /// • 2 синие  = прочитано (isRead: true)
  Widget _buildCheckmarks(MessageModel msg) {
    final bool isOffer = msg.type == 'offer';

    // Цвет галочек
    final Color blueColor  = isOffer ? const Color(0xFF0284C7) : const Color(0xFF38BDF8);
    final Color greyColor  = isOffer ? const Color(0xFF94A3B8) : Colors.white60;

    if (msg.isRead) {
      // ══ 2 СИНИЕ галочки ════════════════════════════════
      return Icon(Icons.done_all_rounded, size: 15, color: blueColor);
    }

    if (msg.isDelivered) {
      // ══ 2 СЕРЫЕ галочки ════════════════════════════════
      return Icon(Icons.done_all_rounded, size: 15, color: greyColor);
    }

    // ══ 1 СЕРАЯ галочка ════════════════════════════════
    return Icon(Icons.done_rounded, size: 15, color: greyColor);
  }
}

class _AudioPlayerWidget extends StatelessWidget {

  final MessageModel msg;
  final bool isMe;
  final Color color;
  final Function(String, String) onPlay;
  final bool isPlaying;
  final Duration currentPos;
  final Duration currentDur;
  // P5 FIX: accept lang from parent instead of hardcoding 'Русский'
  final String lang;
  final void Function(MessageModel)? onRetryUpload;

  const _AudioPlayerWidget({
    required this.msg,
    required this.isMe,
    required this.color,
    required this.onPlay,
    required this.isPlaying,
    required this.currentPos,
    required this.currentDur,
    this.lang = 'Русский',
    this.onRetryUpload,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasUrl = msg.mediaUrl != null && msg.mediaUrl!.isNotEmpty;
    final bool isFailed = !hasUrl && msg.uploadFailed;
    final bool isUploading = !hasUrl && !isFailed;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: hasUrl
            ? () => onPlay(msg.id, msg.mediaUrl!)
            : (isFailed ? () => onRetryUpload?.call(msg) : null),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isUploading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                    ),
                  )
                : isFailed
                    ? const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 20)
                    : Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: const Color(0xFF3B82F6),
                        size: 22,
                      ),
          ),
        ),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 20,
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(15, (index) {
                final height = [10.0, 15.0, 8.0, 18.0, 12.0, 6.0, 14.0, 16.0, 10.0, 14.0, 8.0, 12.0, 18.0, 10.0, 6.0][index];
                return Container(
                  width: 3, height: height,
                  decoration: BoxDecoration(
                    color: isPlaying ? (currentPos.inMilliseconds / (currentDur.inMilliseconds + 1) > index / 15 ? color : color.withValues(alpha: 0.3)) : color.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 2),
          Text(isPlaying ? _formatDuration(currentPos) : '${msg.duration ?? 0} ${TranslationService.t('seconds_short', lang)}', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
        ]),
      ),
    ]);
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
