import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/part_thumbnail.dart';

class PendingPalletPoGroup extends StatelessWidget {
  final String poId;
  final List<PendingPalletLine> items;
  final void Function(PendingPalletLine line) onSelectLine;

  const PendingPalletPoGroup({
    super.key,
    required this.poId,
    required this.items,
    required this.onSelectLine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 4),
          child: Row(
            children: [
              Icon(
                MdiIcons.fileDocumentOutline,
                size: 16,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                'PO: $poId',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.12),
                  border: Border.all(color: AppTheme.warning),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length} รายการ',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        ...items.map((line) => _PendingPalletLineCard(line: line, onTap: () => onSelectLine(line))),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _PendingPalletLineCard extends StatelessWidget {
  final PendingPalletLine line;
  final VoidCallback onTap;

  const _PendingPalletLineCard({
    required this.line,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PartThumbnail(imageUrl: line.imageUrl, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.partId,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      line.itemDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (line.lotNumber != null) ...[
                          Icon(
                            MdiIcons.tagOutline,
                            size: 12,
                            color: AppTheme.textGrey(context),
                          ),
                          const SizedBox(width: 2),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textGrey(context),
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Batch No.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: ' : ${line.lotNumber}'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        StatusBadge(line.condition),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${line.owner} / ${line.brand}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Qty: ${line.qtyReceived}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Icon(MdiIcons.linkVariant, color: AppTheme.primary, size: 22),
                  const SizedBox(height: 2),
                  const Text(
                    'ผูก',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
