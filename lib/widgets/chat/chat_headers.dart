import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:iqmarket/models/ad_model.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:iqmarket/services/chat_service.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/screens/product_details_screen.dart';

class ChatGlassHeader extends StatelessWidget {
  final AdModel ad;
  final String? sellerAvatarUrl;
  final VoidCallback onBack;
  final VoidCallback onProfileTap;
  final VoidCallback onCall;

  const ChatGlassHeader({
    super.key,
    required this.ad,
    this.sellerAvatarUrl,
    required this.onBack,
    required this.onProfileTap,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF17212B).withValues(alpha: 0.8),
            border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
          ),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white), onPressed: onBack),
            GestureDetector(
              onTap: onProfileTap,
              child: Row(children: [
                CircleAvatar(
                  radius: 18, 
                  backgroundColor: Colors.white.withValues(alpha: 0.1), 
                  backgroundImage: sellerAvatarUrl != null ? CachedNetworkImageProvider(sellerAvatarUrl!) : null,
                  child: sellerAvatarUrl == null ? const Icon(Icons.person, size: 20, color: Colors.white70) : null,
                ),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(ad.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                  StreamBuilder<bool>(
                    stream: ChatService.getTypingStatusStream(ad.userId),
                    builder: (context, snapshot) {
                      if (snapshot.data == true) return const Text('печатает...', style: TextStyle(color: Color(0xFF4A80F0), fontSize: 11, fontWeight: FontWeight.bold));
                      return FutureBuilder<UserModel?>(
                        future: UserService.getUserById(ad.userId),
                        builder: (context, userSnap) {
                          if (userSnap.hasData && userSnap.data != null) {
                            final date = userSnap.data!.registrationDate;
                            final timeStr = DateFormat('d MMMM в HH:mm').format(date);
                            return Text('был(а) в сети $timeStr', style: const TextStyle(color: Colors.white38, fontSize: 11));
                          }
                          return const Text('в сети', style: TextStyle(color: Color(0xFF10B981), fontSize: 11, fontWeight: FontWeight.bold));
                        }
                      );
                    },
                  ),
                ]),
              ]),
            ),
            const Spacer(),
            IconButton(icon: const Icon(Icons.call_rounded, color: Colors.white70), onPressed: onCall),
            const SizedBox(width: 4),
          ]),
        ),
      ),
    );
  }
}

class ChatAdInfoBar extends StatelessWidget {
  final AdModel ad;

  const ChatAdInfoBar({super.key, required this.ad});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B).withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: ClipOval(
            child: Hero(
              tag: 'chat_ad-image-${ad.id}',
              child: ad.images.isNotEmpty 
                ? CachedNetworkImage(imageUrl: ad.images.isNotEmpty ? ad.images.first : '', fit: BoxFit.cover, errorWidget: (context, url, error) => const Icon(Icons.image, color: Colors.white24))
                : const Icon(Icons.shopping_bag_outlined, color: Colors.white54, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white)),
          Text('${ad.price.toInt()} ₸', style: const TextStyle(color: Color(0xFF4A80F0), fontWeight: FontWeight.w900, fontSize: 11)),
        ])),
        TextButton(
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(ad: ad, onReport: (_) {}, lang: 'Русский', heroPrefix: 'chat_')));
          },
          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
          child: const Text('Смотреть', style: TextStyle(fontSize: 12, color: Color(0xFF4A80F0))),
        ),
      ]),
    );
  }
}
