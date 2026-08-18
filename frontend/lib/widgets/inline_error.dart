import 'package:flutter/material.dart';

import '../theme/app_text_styles.dart';
import '../utils/app_colors.dart';

/// Message d'erreur au niveau du champ, affiché sous un `TextFormField`.
///
/// Rend un widget vide quand [message] est `null`, ce qui permet de lui passer
/// directement `_fieldErrors['email']` sans test préalable.
class InlineError extends StatelessWidget {
  final String? message;
  const InlineError({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final text = message;
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySm.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
