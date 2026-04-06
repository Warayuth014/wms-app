import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../services/api_service.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../../../widgets/part_thumbnail.dart';
import '../../shared/putaway_shared_widgets.dart';

class PreworkReceiveSheet extends StatefulWidget {
  final StationInfo station;
  final String userId;
  final String? palletId;
  final String? palletStatus;
  final List<Map<String, dynamic>> cutItems;
  final VoidCallback onCompleted;

  const PreworkReceiveSheet({
    super.key,
    required this.station,
    required this.userId,
    this.palletId,
    this.palletStatus,
    required this.cutItems,
    required this.onCompleted,
  });

  @override
  State<PreworkReceiveSheet> createState() => _PreworkReceiveSheetState();
}

class _PreworkReceiveSheetState extends State<PreworkReceiveSheet> {
  final _api = ApiService();
  bool _loading = false;

  Future<void> _returnPallet() async {
    if (widget.palletId == null) return;

    final confirm = await showConfirmDialog(
      context,
      title: 'คืน Pallet เปล่า',
      message:
          'คืน ${widget.palletId}\n'
          'Pallet จะถูกเปลี่ยนเป็นสถานะ AVAILABLE\n\n'
          'ยืนยันคืน Pallet?',
      confirmLabel: 'คืน Pallet',
    );
    if (!confirm || !mounted) return;

    setState(() => _loading = true);

    final result = await _api.preworkReturnPallet(
      palletId: widget.palletId!,
      stationId: widget.station.id,
      operatorId: widget.userId,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'เกิดข้อผิดพลาด');
      return;
    }

    Navigator.pop(context);
    showSuccessSnackbar(context, '${widget.palletId} คืนแล้ว (AVAILABLE)');
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final bottomPad = mq.viewInsets.bottom + mq.viewPadding.bottom;
    final hasPallet = widget.palletId != null;
    final isInTransit = widget.palletStatus == 'IN_TRANSIT';

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: LoadingOverlay(
        loading: _loading,
        message: 'กำลังคืน Pallet...',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.station.color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(widget.station.icon, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.station.id,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          hasPallet ? widget.palletId! : 'ว่าง - รอ Pallet',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (hasPallet)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.palletStatus ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!hasPallet) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPad + 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        MdiIcons.packageVariant,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'ไม่มี Pallet ที่จุดนี้',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ส่ง Pallet PW มาจาก Putaway ก่อน',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isInTransit) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 24),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        MdiIcons.truckDeliveryOutline,
                        color: AppTheme.warning,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.palletId!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AMR กำลังนำ Pallet มาส่ง...',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'รอยิง API simulate/asrs/receive-pallet\nเพื่อจำลอง Pallet ถึงจุด Prework',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.success, size: 28),
                      SizedBox(width: 12),
                      Text(
                        'ตัดยอดแล้ว - Pallet เปล่า',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (widget.cutItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    itemCount: widget.cutItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = widget.cutItems[index];
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
                            PartThumbnail(
                              imageUrl: item['imageUrl'] as String?,
                              size: 52,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${item['partId'] ?? '-'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${item['itemDesc'] ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textGrey(context),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                Text(
                                  '${item['qty'] ?? 0}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.primary,
                                  ),
                                ),
                                Text(
                                  'ชิ้น',
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
              ] else
                const Spacer(),
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _returnPallet,
                    icon: Icon(MdiIcons.undoVariant, color: Colors.white),
                    label: const Text(
                      'คืน Pallet เปล่า',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
