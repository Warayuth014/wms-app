import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PalletScanSection extends StatelessWidget {
  final ReceiptLineResponse pendingLine;
  final TextEditingController palletController;
  final FocusNode palletFocus;
  final VoidCallback onScanPallet;
  final String title;
  final String fieldLabel;
  final String fieldHint;
  final String buttonLabel;
  final String conditionMessage;
  final String quantitySuffix;

  const PalletScanSection({
    super.key,
    required this.pendingLine,
    required this.palletController,
    required this.palletFocus,
    required this.onScanPallet,
    required this.title,
    required this.fieldLabel,
    required this.fieldHint,
    required this.buttonLabel,
    required this.conditionMessage,
    required this.quantitySuffix,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(MdiIcons.packageVariantClosed, color: AppTheme.secondary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.pending, color: AppTheme.warning, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pendingLine.partId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '${pendingLine.qtyReceived} $quantitySuffix',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                ),
                StatusBadge(pendingLine.condition),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            conditionMessage,
            style: TextStyle(fontSize: 13, color: AppTheme.textGrey(context)),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: fieldLabel,
            hint: fieldHint,
            controller: palletController,
            focusNode: palletFocus,
            onSubmit: onScanPallet,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: buttonLabel,
            icon: MdiIcons.linkVariant,
            onPressed: onScanPallet,
          ),
        ],
      ),
    );
  }
}
