import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MapPickerScreen extends StatelessWidget {
  final dynamic initialLocation;
  const MapPickerScreen({super.key, this.initialLocation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор на карте')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Карта временно недоступна.\nПожалуйста, выберите город из списка.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Назад к списку'),
            )
          ],
        ),
      ),
    );
  }
}
