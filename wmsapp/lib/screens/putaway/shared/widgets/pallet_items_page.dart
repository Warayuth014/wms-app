import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../models/wms_models.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/part_thumbnail.dart';

class PalletItemsPage extends StatelessWidget {
  final String palletId;
  final String type;
  final List<UnloadItem> items;

  const PalletItemsPage({
    super.key,
    required this.palletId,
    required this.type,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isFG = type == 'FG';
    final typeColor = isFG ? AppTheme.success : AppTheme.warning;

    return Scaffold(
      appBar: WmsAppBar(title: '$palletId โ€” เธชเธดเธเธเนเธฒ'),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Summary header
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(MdiIcons.packageVariantClosed, color: typeColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          palletId,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary(context),
                          ),
                        ),
                        Text(
                          'เธเธฃเธฐเน€เธ เธ— $type ยท ${items.length} เธฃเธฒเธขเธเธฒเธฃ ยท เธฃเธงเธก ${items.fold<int>(0, (sum, i) => sum + i.qty)} เธเธดเนเธ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppTheme.textGrey(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: typeColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: typeColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Items list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        PartThumbnail(imageUrl: item.imageUrl, size: 56),
                        const SizedBox(width: 12),
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
                              const SizedBox(height: 2),
                              Text(
                                item.itemDesc,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textGrey(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    '${item.owner} / ${item.brand}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.textGrey(context),
                                    ),
                                  ),
                                  if (item.lotNumber != null &&
                                      item.lotNumber!.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      MdiIcons.tagOutline,
                                      size: 12,
                                      color: AppTheme.textGrey(context),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      item.lotNumber!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.textGrey(context),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          children: [
                            Text(
                              '${item.qty}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                            Text(
                              'เธเธดเนเธ',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textGrey(context),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
