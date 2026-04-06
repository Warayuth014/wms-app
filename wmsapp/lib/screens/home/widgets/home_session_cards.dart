import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class HomeLoginPromptCard extends StatelessWidget {
  final String message;
  final String buttonLabel;
  final VoidCallback onLoginTap;

  const HomeLoginPromptCard({
    super.key,
    required this.message,
    required this.buttonLabel,
    required this.onLoginTap,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: AppTheme.textGrey(context), fontSize: 14),
            ),
          ),
          TextButton(
            onPressed: onLoginTap,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class HomeUserCard extends StatelessWidget {
  final String fullName;
  final String userId;
  final String role;

  const HomeUserCard({
    super.key,
    required this.fullName,
    required this.userId,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Center(
              child: Text(
                fullName.isEmpty ? '?' : fullName[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppTheme.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  userId,
                  style: TextStyle(
                    color: AppTheme.textGrey(context),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(role),
        ],
      ),
    );
  }
}
