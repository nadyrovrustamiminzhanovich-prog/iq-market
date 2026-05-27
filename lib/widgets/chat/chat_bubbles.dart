import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iqmarket/models/message_model.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class ChatBubble extends StatelessWidget {
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
    this.onAcceptOffer,
    this.onDeclineOffer,
    this.onWriteOffer,
    this.onVoiceOffer,
    this.onCallOffer,
  });

  final VoidCallback? onAcceptOffer;
  final VoidCallback? onDeclineOffer;
  final VoidCallback? onWriteOffer;
  final VoidCallback? onVoiceOffer;
  final VoidCallback? onCallOffer;

  @override
  Widget build(BuildContext context) {
    final bool isMe = msg.senderId == UserService.currentUid;
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
              backgroundImage: (sellerAvatarUrl != null && sellerAvatarUrl!.startsWith('http')) 
                  ? CachedNetworkImageProvider(sellerAvatarUrl!) 
                  : null,
              child: (sellerAvatarUrl == null || !sellerAvatarUrl!.startsWith('http')) 
                  ? const Icon(Icons.person, size: 14, color: Colors.white38) 
                  : null,
            ),

            const SizedBox(width: 8),
          ],
          GestureDetector(
            onLongPress: () => onLongPress(msg),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
                minWidth: msg.type == 'audio' ? 160 : 0,
              ),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isMe ? null : otherBubbleColor,
                gradient: isMe ? const LinearGradient(
                  colors: [Color(0xFF4A80F0), Color(0xFF3B6FE0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ) : null,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18), 
                  topRight: const Radius.circular(18), 
                  bottomLeft: Radius.circular(isMe ? 18 : 4), 
                  bottomRight: Radius.circular(isMe ? 4 : 18)
                ),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (msg.type == 'image' && msg.mediaUrl != null)
                  GestureDetector(
                    onTap: () => onImageTap(msg.mediaUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12), 
                      child: Hero(
                        tag: msg.mediaUrl!, 
                        child: (msg.mediaUrl != null && msg.mediaUrl!.startsWith('http'))
                          ? CachedNetworkImage(
                              imageUrl: msg.mediaUrl!,
                              errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white),
                            )
                          : const Icon(Icons.broken_image_rounded, color: Colors.white)
                      )

                    ),
                  ),
                if (msg.type == 'audio') _AudioPlayerWidget(
                  msg: msg, 
                  isMe: isMe, 
                  color: textColor, 
                  onPlay: onPlayVoice, 
                  isPlaying: isPlaying,
                  currentPos: currentPos,
                  currentDur: currentDur,
                ),
                if (msg.text.isNotEmpty && msg.type == 'text')
                  Text(msg.text, style: TextStyle(color: textColor, fontSize: 15, fontWeight: FontWeight.w500)),
                if (msg.type == 'offer') _buildOfferCard(context, isMe),
                const SizedBox(height: 4),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(DateFormat('HH:mm').format(msg.timestamp), style: TextStyle(fontSize: 10, color: subTextColor)),
                  if (isMe) ...[const SizedBox(width: 4), Icon(msg.isRead ? Icons.done_all_rounded : Icons.done_rounded, size: 14, color: msg.isRead ? const Color(0xFF00E5FF) : Colors.white38)],
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfferCard(BuildContext context, bool isMe) {
    final status = msg.offerStatus ?? 'pending';
    final isPending = status == 'pending';
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.handshake(PhosphorIconsStyle.fill), color: Colors.white70, size: 18),
              const SizedBox(width: 8),
              Text('ПРЕДЛОЖЕНИЕ ЦЕНЫ', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final double priceVal = double.tryParse(msg.offerPrice ?? '0') ?? 0.0;
              final formattedPrice = priceVal > 0 
                  ? '${NumberFormat.decimalPattern('ru').format(priceVal.toInt())} ₸' 
                  : '0 ₸';
              return Text(formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5));
            },
          ),
          const SizedBox(height: 14),
          if (!isMe && isPending) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF43F5E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onDeclineOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Отклонить', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: onAcceptOffer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Принять', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Divider(color: Colors.white24, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _quickActionButton(
                  icon: Icons.phone_in_talk_rounded,
                  label: 'Позвонить',
                  color: const Color(0xFF34D399),
                  onTap: onCallOffer,
                ),
                _quickActionButton(
                  icon: Icons.edit_note_rounded,
                  label: 'Написать',
                  color: const Color(0xFF60A5FA),
                  onTap: onWriteOffer,
                ),
                _quickActionButton(
                  icon: Icons.keyboard_voice_rounded,
                  label: 'Голосовое',
                  color: const Color(0xFFC084FC),
                  onTap: onVoiceOffer,
                ),
              ],
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _getStatusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _getStatusColor(status).withOpacity(0.25), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_getStatusIcon(status), color: _getStatusColor(status), size: 16),
                  const SizedBox(width: 6),
                  Text(_getStatusText(status), style: TextStyle(color: _getStatusColor(status), fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted': return const Color(0xFF10B981);
      case 'rejected': return Colors.redAccent;
      default: return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'accepted': return Icons.check_circle_rounded;
      case 'rejected': return Icons.cancel_rounded;
      default: return Icons.access_time_filled_rounded;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'accepted': return 'ПРИНЯТО';
      case 'rejected': return 'ОТКЛОНЕНО';
      default: return 'В ОЖИДАНИИ';
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

  const _AudioPlayerWidget({
    required this.msg,
    required this.isMe,
    required this.color,
    required this.onPlay,
    required this.isPlaying,
    required this.currentPos,
    required this.currentDur,
  });

  @override
  Widget build(BuildContext context) {
    final bool isUploading = msg.mediaUrl == null;
    
    return Row(mainAxisSize: MainAxisSize.min, children: [
      IconButton(
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
        icon: Icon(isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded, color: color, size: 32),
        onPressed: isUploading ? null : () => onPlay(msg.id, msg.mediaUrl!),
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
          Text(isPlaying ? _formatDuration(currentPos) : '${msg.duration ?? 0} сек', style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10)),
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
