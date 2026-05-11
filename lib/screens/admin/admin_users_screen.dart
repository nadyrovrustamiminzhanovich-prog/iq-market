import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iqmarket/services/user_service.dart';
import 'package:iqmarket/models/user_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text('Пользователи', style: GoogleFonts.inter(fontWeight: FontWeight.w900)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Поиск по имени, email или ID...',
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(), size: 20),
                suffixIcon: _searchQuery.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                  : null,
                filled: true,
                fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<UserModel>>(
        stream: UserService.getAllUsersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          final users = snapshot.data ?? [];
          final filteredUsers = users.where((u) => 
            u.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            u.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            u.uid.toLowerCase().contains(_searchQuery.toLowerCase())
          ).toList();

          if (filteredUsers.isEmpty) return _buildEmptyState();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: filteredUsers.length,
            itemBuilder: (context, index) => _buildUserCard(filteredUsers[index], colorScheme),
          );
        },
      ),
    );
  }

  Widget _buildUserCard(UserModel user, ColorScheme colorScheme) {
    final isAdmin = user.accountType == 'admin';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: colorScheme.surfaceContainerHighest,
          backgroundImage: user.photoUrl.isNotEmpty ? CachedNetworkImageProvider(user.photoUrl) : null,
          child: user.photoUrl.isEmpty ? Icon(PhosphorIcons.user(), color: Colors.grey) : null,
        ),
        title: Row(
          children: [
            Expanded(child: Text(user.name, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16))),
            if (isAdmin) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: colorScheme.primary, borderRadius: BorderRadius.circular(6)),
              child: const Text('ADMIN', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(user.email, style: GoogleFonts.inter(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: user.uid));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID скопирован!'), duration: Duration(seconds: 1)));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('ID: ${user.uid.substring(0, 8)}...', style: GoogleFonts.firaCode(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Icon(PhosphorIcons.copy(), size: 14, color: colorScheme.primary),
                  ],
                ),
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          icon: Icon(PhosphorIcons.dotsThreeVertical(), color: Colors.grey),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          itemBuilder: (context) => [
            PopupMenuItem(
              onTap: () => UserService.toggleUserAdmin(user.uid, !isAdmin),
              child: Row(children: [
                Icon(isAdmin ? PhosphorIcons.userMinus() : PhosphorIcons.userPlus(), size: 20),
                const SizedBox(width: 12),
                Text(isAdmin ? 'Снять админа' : 'Сделать админом'),
              ]),
            ),
            PopupMenuItem(
              onTap: () => UserService.toggleUserVerification(user.uid, !user.isVerified),
              child: Row(children: [
                Icon(PhosphorIcons.sealCheck(), size: 20, color: Colors.blue),
                const SizedBox(width: 12),
                Text(user.isVerified ? 'Снять галочку' : 'Подтвердить'),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(PhosphorIcons.users(), size: 80, color: Colors.grey.withValues(alpha: 0.2)),
          const SizedBox(height: 24),
          Text('Пользователь не найден', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.grey)),
        ],
      ),
    );
  }
}
