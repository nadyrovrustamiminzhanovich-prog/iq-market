import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TaxiRouteInputWidget extends StatelessWidget {
  final Widget routeFrom;
  final Widget routeTo;
  final VoidCallback onSwapTap;

  const TaxiRouteInputWidget({
    super.key,
    required this.routeFrom,
    required this.routeTo,
    required this.onSwapTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 21,
            top: 30,
            bottom: 30,
            child: Container(
              width: 1.5,
              decoration: BoxDecoration(
                color: const Color(0xFF4A80F0).withValues(alpha: 0.3),
              ),
            ),
          ),
          Column(children: [
            routeFrom,
            const Padding(
              padding: EdgeInsets.only(left: 50, right: 10),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            routeTo,
          ]),
          Positioned(
            right: 15,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onSwapTap();
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFF1F5F9)),
                  ),
                  child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF4A80F0), size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
