import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../models/wms_models.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/part_thumbnail.dart';

class UnloadItemsList extends StatelessWidget {
  final List<UnloadItem> items;
  final Map<String, String> partStatus;
  final Map<String, TextEditingController> qtyControllers;
  final String? scannedPartId;

  const UnloadItemsList({
    super.key,
    required this.items,
    required this.partStatus,
    required this.qtyControllers,
    required this.scannedPartId,
  });

  @override
  Widget build(BuildContext context) {
    final pending = items
        .where((item) => partStatus[item.partId] == 'PENDING')
        .toList();
    final confirmed = items
        .where((item) => partStatus[item.partId] == 'CONFIRMED')
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (pending.isNotEmpty) ...[
          Row(
            children: [
              Icon(
                MdiIcons.packageVariantClosed,
                color: AppTheme.textPrimary(context),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'รอ Unload (ระบุจำนวนที่จะหยิบออก)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pending.map(
            (item) => _UnloadItemCard(
              item: item,
              confirmed: false,
              isScanned: scannedPartId == item.partId,
              controller: qtyControllers[item.partId],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (confirmed.isNotEmpty) ...[
          const Text(
            'Confirmed',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.success,
            ),
          ),
          const SizedBox(height: 8),
          ...confirmed.map(
            (item) => _UnloadItemCard(
              item: item,
              confirmed: true,
              isScanned: false,
              controller: qtyControllers[item.partId],
            ),
          ),
        ],
      ],
    );
  }
}

class _UnloadItemCard extends StatelessWidget {
  final UnloadItem item;
  final bool confirmed;
  final bool isScanned;
  final TextEditingController? controller;

  const _UnloadItemCard({
    required this.item,
    required this.confirmed,
    required this.isScanned,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: confirmed
            ? AppTheme.success.withValues(alpha: 0.05)
            : isScanned
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: confirmed
              ? AppTheme.success.withValues(alpha: 0.3)
              : isScanned
                  ? AppTheme.primary
                  : AppTheme.border(context),
          width: isScanned ? 2 : 1,
        ),
        boxShadow: [
          if (!confirmed)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PartThumbnail(imageUrl: item.imageUrl, size: 36),
              const SizedBox(width: 10),
              Icon(
                confirmed ? Icons.check_circle : Icons.radio_button_unchecked,
                color: confirmed
                    ? AppTheme.success
                    : isScanned
                        ? AppTheme.primary
                        : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.partId,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      item.itemDesc,
                      style: TextStyle(
                        color: AppTheme.textGrey(context),
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        if (item.lotNumber != null &&
                            item.lotNumber!.isNotEmpty) ...[
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
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(text: ' : ${item.lotNumber}'),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          '${item.owner} / ${item.brand}',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (isScanned)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SCANNED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (!confirmed) ...[
            const Divider(height: 14),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'บน Pallet: ${item.qty} ชิ้น',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                    Text(
                      '${item.owner} / ${item.brand}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  'จำนวน Unload: ',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                SizedBox(
                  width: 72,
                  height: 38,
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    enabled: isScanned,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Divider(height: 14),
            Row(
              children: [
                Text(
                  '${item.owner} / ${item.brand}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textGrey(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${controller?.text ?? item.qty} ชิ้น',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
