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
    this.onAcceptOffer,
    this.onDeclineOffer,
    this.onWriteOffer,
    this.onVoiceOffer,
    this.onCallOffer,
    this.lang = 'Русский',
  });

  final VoidCallback? onAcceptOffer;
  final VoidCallback? onDeclineOffer;
  final VoidCallback? onWriteOffer;
  final VoidCallback? onVoiceOffer;
  final VoidCallback? onCallOffer;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  bool _isOfferLoading = false;

  @override
  Widget build(BuildContext context) {
    final bool isMe = widget.msg.senderId == UserService.currentUid;
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
                    GestureDetector(
                      onTap: (widget.msg.mediaUrl != null && widget.msg.mediaUrl!.isNotEmpty)
                          ? () => widget.onImageTap(widget.msg.mediaUrl!)
                          : null,
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
                                child: (widget.msg.mediaUrl != null && widget.msg.mediaUrl!.startsWith('http'))
                                    ? CachedNetworkImage(
                                        imageUrl: widget.msg.mediaUrl!,
                                        fit: BoxFit.cover,
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
                              // 2. Show the Upload/Loading Overlay
                              if (widget.msg.mediaUrl == null || widget.msg.mediaUrl!.isEmpty)
                                Positioned.fill(
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    child: const Center(
                                      child: CircularProgressIndicator(
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
                    ),
                  if (widget.msg.type == 'audio') _AudioPlayerWidget(
                    msg: widget.msg, 
                    isMe: isMe, 
                    color: isMe ? Colors.white : const Color(0xFF3B82F6), 
                    onPlay: widget.onPlayVoice, 
                    isPlaying: widget.isPlaying,
                    currentPos: widget.currentPos,
                    currentDur: widget.currentDur,
                    lang: widget.lang,
                  ),
                  if (widget.msg.text.isNotEmpty && widget.msg.type == 'text')
                    Text(widget.msg.text, softWrap: true, style: TextStyle(color: isMe ? Colors.white : const Color(0xFF0F172A), fontSize: 15, fontWeight: FontWeight.w500)),
                  if (widget.msg.type == 'offer') _buildOfferCard(context, isMe),
                  const SizedBox(height: 4),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(DateFormat('HH:mm').format(widget.msg.timestamp), style: TextStyle(fontSize: 10, color: widget.msg.type == 'offer' ? const Color(0xFF94A3B8) : (isMe ? Colors.white70 : const Color(0xFF64748B)))),
                    if (isMe && widget.msg.type != 'offer') ...[const SizedBox(width: 4), Icon(widget.msg.isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: widget.msg.isRead ? const Color(0xFF00E5FF) : Colors.white38)],
                  ]),
                ]),
              ),
            ),
          ),
        ],
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
              final formattedPrice = priceVal > 0 
                  ? '${NumberFormat.decimalPattern('ru').format(priceVal.toInt())} ₸' 
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
                        setState(() => _isOfferLoading = true);
                        try {
                          await Future.microtask(() => widget.onDeclineOffer?.call());
                        } finally {
                          if (mounted) setState(() => _isOfferLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isOfferLoading 
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
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isOfferLoading ? null : () async {
                        setState(() => _isOfferLoading = true);
                        try {
                          await Future.microtask(() => widget.onAcceptOffer?.call());
                        } finally {
                          if (mounted) setState(() => _isOfferLoading = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: EdgeInsets.zero,
                      ),
                      child: _isOfferLoading 
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: widget.onCallOffer,
                icon: const Icon(Icons.phone_in_talk_rounded, size: 18, color: Colors.white),
                label: Text(
                  TranslationService.t('call_btn', widget.lang),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

  const _AudioPlayerWidget({
    required this.msg,
    required this.isMe,
    required this.color,
    required this.onPlay,
    required this.isPlaying,
    required this.currentPos,
    required this.currentDur,
    this.lang = 'Русский',
  });

  @override
  Widget build(BuildContext context) {
    final bool isUploading = msg.mediaUrl == null || msg.mediaUrl!.isEmpty;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: isUploading ? null : () => onPlay(msg.id, msg.mediaUrl!),
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
