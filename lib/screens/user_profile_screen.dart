import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Готовый чистый виджет экрана профиля пользователя (UserProfileScreen)
/// Поддерживает светлую тему (Light theme) и адаптивную верстку.
class UserProfileScreen extends StatefulWidget {
  final String userName;
  final String userId;
  final String? userPhotoUrl;
  final bool isVerified;
  final String verificationText;
  final String userStatus;
  final String statusSubtitle;
  final int reviewsCount;
  final String reviewsLabel;
  final String sectionTitle;
  final VoidCallback? onPersonalDataTap;
  final VoidCallback? onMyAdsTap;
  final VoidCallback? onMyMessagesTap;
  final VoidCallback? onReviewsTap;

  const UserProfileScreen({
    super.key,
    this.userName = 'Rufat Usenov',
    this.userId = 'sAezvK0z',
    this.userPhotoUrl,
    this.isVerified = true,
    this.verificationText = 'Текшүрүлгөн',
    this.userStatus = 'Йеңи әза',
    this.statusSubtitle = '5 балашлиқтин гейин шаклиниду',
    this.reviewsCount = 3,
    this.reviewsLabel = 'ПИКИРЛӘР',
    this.sectionTitle = 'ШӘХСИЙ МӘЛУМАТ',
    this.onPersonalDataTap,
    this.onMyAdsTap,
    this.onMyMessagesTap,
    this.onReviewsTap,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  void _copyUserIdToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.userId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('ID скопирован: ${widget.userId}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF2563EB);
    const Color backgroundColor = Color(0xFFF8FAFC);
    const Color cardColor = Colors.white;
    const Color titleColor = Color(0xFF0F172A);
    const Color subtitleColor = Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: titleColor, size: 20),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            // ==========================================
            // 1. ВЕРХНИЙ БЛОК ПОЛЬЗОВАТЕЛЯ (ПО ЦЕНТРУ)
            // ==========================================
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Аватар пользователя
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primaryColor.withValues(alpha: 0.15), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: (widget.userPhotoUrl != null && widget.userPhotoUrl!.isNotEmpty)
                          ? NetworkImage(widget.userPhotoUrl!)
                          : null,
                      child: (widget.userPhotoUrl == null || widget.userPhotoUrl!.isEmpty)
                          ? const Icon(
                              Icons.person_rounded,
                              size: 54,
                              color: primaryColor,
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Имя пользователя (Крупный жирный текст)
                  Text(
                    widget.userName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: titleColor,
                      letterSpacing: -0.4,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ID пользователя (Серый текст с иконкой копирования)
                  InkWell(
                    onTap: _copyUserIdToClipboard,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ID: ${widget.userId}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: subtitleColor,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 15,
                            color: subtitleColor,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Бейдж верификации (Статус)
                  if (widget.isVerified) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE), // Голубой фон
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: primaryColor, // Голубая галочка
                            size: 17,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            widget.verificationText,
                            style: GoogleFonts.inter(
                              color: primaryColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // 2. ПЛАШКА СТАТИСТИКИ / РЕЙТИНГА
            // ==========================================
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onReviewsTap,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      // Колонки слева: Статус + подпись
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.userStatus,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.statusSubtitle,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: subtitleColor,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Вертикальный разделитель
                      Container(
                        width: 1,
                        height: 44,
                        color: const Color(0xFFE2E8F0),
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                      ),

                      // Колонка справа: Отзывы + подпись
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${widget.reviewsCount}',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: titleColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.reviewsLabel,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: subtitleColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ==========================================
            // 3. СЕКЦИЯ МЕНЮ «ШӘХСИЙ МӘЛУМАТ»
            // ==========================================
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 10),
                child: Text(
                  widget.sectionTitle.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: subtitleColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

            // Карточка со списком пунктов меню
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Column(
                  children: [
                    // 1. Личные данные
                    _buildMenuItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Шахсий мәлумат',
                      onTap: widget.onPersonalDataTap,
                    ),

                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 60, endIndent: 16),

                    // 2. Мои объявления
                    _buildMenuItem(
                      icon: Icons.grid_view_rounded,
                      label: 'Мениң еланлирим',
                      onTap: widget.onMyAdsTap,
                    ),

                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 60, endIndent: 16),

                    // 3. Мои сообщения
                    _buildMenuItem(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Мениң үчүрлирим',
                      onTap: widget.onMyMessagesTap,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF94A3B8),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
