import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Voltagent-styled Value Proposition Card for authentication screens
class AuthHeroCard extends StatelessWidget {
  const AuthHeroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.voltagentHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.psychology_outlined,
                color: AppColors.voltagentPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '“Intelligent schedule coordination aligned with your cognitive rhythm.”',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.voltagentHairline, height: 1),
          const SizedBox(height: 16),
          _buildBullet(
            icon: Icons.auto_awesome,
            richText: TextSpan(
              style: const TextStyle(
                color: AppColors.voltagentBody,
                fontSize: 12.5,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Mitigate '),
                TextSpan(
                  text: 'Planning Fallacy',
                  style: const TextStyle(
                    color: AppColors.voltagentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const TextSpan(text: ' with dynamic K_bias calibration buffer'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildBullet(
            icon: Icons.timer_outlined,
            richText: TextSpan(
              style: const TextStyle(
                color: AppColors.voltagentBody,
                fontSize: 12.5,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'Protect critical '),
                const TextSpan(
                  text: 'Deep Work',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: ' blocks & cognitive recharge periods'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildBullet(
            icon: Icons.shield_outlined,
            richText: const TextSpan(
              text: 'End-to-end encrypted cognitive pattern analytics',
              style: TextStyle(
                color: AppColors.voltagentBody,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBullet({required IconData icon, required InlineSpan richText}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.voltagentPrimary, size: 16),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(text: richText),
        ),
      ],
    );
  }
}
