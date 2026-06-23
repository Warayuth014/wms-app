import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../services/api_service.dart';
import '../../../../../theme/theme.dart';
import '../../../../../widgets/common_widgets.dart';

class PickingDestScanCard extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onConfirm;
  final String? pickOrderId;

  const PickingDestScanCard({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onConfirm,
    this.pickOrderId,
  });

  @override
  State<PickingDestScanCard> createState() => _PickingDestScanCardState();
}

class _PickingDestScanCardState extends State<PickingDestScanCard> {
  final _api = ApiService();
  String? _suggestedPalletId;
  bool _continued = false; // true = ใช้ pallet เดิมของ order
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSuggested();
  }

  Future<void> _loadSuggested() async {
    setState(() => _loading = true);
    final res = await _api.getSuggestedDestPallet(
      pickOrderId: widget.pickOrderId,
    );
    if (!mounted) return;
    setState(() {
      _suggestedPalletId = res.success ? res.data?.palletId : null;
      _continued = res.success && (res.data?.continued ?? false);
      _loading = false;
    });
  }

  void _useSuggestion() {
    if (_suggestedPalletId == null) return;
    widget.controller.text = _suggestedPalletId!;
    widget.focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.qr_code_scanner, color: AppTheme.secondary),
              SizedBox(width: 8),
              Text(
                'Scan Pallet ปลายทาง',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'สแกน Pallet ปลายทางที่จะใส่สินค้าที่หยิบมา',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGrey(context),
            ),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'Dest Pallet ID',
            hint: 'Scan Pallet ปลายทาง',
            controller: widget.controller,
            focusNode: widget.focusNode,
            onSubmit: widget.onConfirm,
          ),

          // ── Suggested pallet ──
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_suggestedPalletId != null) ...[
            const SizedBox(height: 10),
            _buildSuggestionLabel(),
            const SizedBox(height: 6),
            _buildSuggestionChip(_suggestedPalletId!),
          ],

          const SizedBox(height: 12),
          PrimaryButton(
            label: 'ยืนยัน',
            icon: Icons.check,
            onPressed: widget.onConfirm,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionLabel() {
    final icon = _continued
        ? MdiIcons.replay
        : MdiIcons.gestureTapButton;
    final text = _continued
        ? 'ใช้ Pallet เดิมของ order นี้ต่อ — แตะเพื่อใช้'
        : 'Pallet ว่างถัดไป — แตะเพื่อเลือก';
    final color = _continued
        ? AppTheme.warning
        : AppTheme.textGrey(context);

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
        InkWell(
          onTap: _loadSuggested,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(Icons.refresh,
                size: 14, color: AppTheme.textGrey(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionChip(String palletId) {
    final accent = _continued ? AppTheme.warning : AppTheme.primary;
    return InkWell(
      onTap: _useSuggestion,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _continued ? MdiIcons.replay : Icons.pallet,
              size: 14,
              color: accent,
            ),
            const SizedBox(width: 5),
            Text(
              palletId,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: accent,
                letterSpacing: 0.2,
              ),
            ),
            if (_continued) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'ต่อจากเดิม',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: accent,
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
