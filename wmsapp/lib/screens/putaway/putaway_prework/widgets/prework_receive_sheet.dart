import 'package:flutter/material.dart';

import '../../../../services/api_service.dart';
import '../../../../theme/theme.dart';
import '../../../../widgets/common_widgets.dart';
import '../../shared/putaway_shared_widgets.dart';
import 'prework_cut_items_list.dart';
import 'prework_receive_empty_state.dart';
import 'prework_receive_in_transit_state.dart';
import 'prework_receive_sheet_header.dart';
import 'prework_return_pallet_button.dart';

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
      title: 'Return Empty Pallet',
      message:
          'Return ${widget.palletId}\n'
          'The pallet status will be changed to AVAILABLE\n\n'
          'Confirm pallet return?',
      confirmLabel: 'Return Pallet',
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
      showErrorDialog(
        context,
        message: result.error ?? 'An unexpected error occurred',
      );
      return;
    }

    Navigator.pop(context);
    showSuccessSnackbar(context, '${widget.palletId} returned (AVAILABLE)');
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
        message: 'Returning pallet...',
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
            PreworkReceiveSheetHeader(
              station: widget.station,
              palletId: widget.palletId,
              palletStatus: widget.palletStatus,
            ),
            const SizedBox(height: 16),
            if (!hasPallet) ...[
              PreworkReceiveEmptyState(
                padding: EdgeInsets.fromLTRB(16, 24, 16, bottomPad + 24),
              ),
            ] else if (isInTransit) ...[
              PreworkReceiveInTransitState(
                palletId: widget.palletId!,
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 24),
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
                        'Cut complete - empty pallet',
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
                PreworkCutItemsList(cutItems: widget.cutItems),
              ] else
                const Spacer(),
              PreworkReturnPalletButton(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPad + 16),
                onPressed: _returnPallet,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
