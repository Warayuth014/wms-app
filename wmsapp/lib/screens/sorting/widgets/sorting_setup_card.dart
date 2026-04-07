import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../models/wms_models.dart';
import '../../../theme/theme.dart';
import '../../../widgets/common_widgets.dart';

class SortingSetupCard extends StatelessWidget {
  final List<SortStation> stations;
  final String? selectedStationId;
  final ValueChanged<String?> onStationChanged;
  final TextEditingController palletController;
  final FocusNode palletFocus;
  final VoidCallback onOpen;

  const SortingSetupCard({
    super.key,
    required this.stations,
    required this.selectedStationId,
    required this.onStationChanged,
    required this.palletController,
    required this.palletFocus,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                MdiIcons.sortVariant,
                color: AppTheme.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'เริ่ม Sorting Session',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'เลือก Sorting Station',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: selectedStationId,
            isExpanded: true,
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            items: stations
                .map(
                  (s) => DropdownMenuItem(
                    value: s.stationId,
                    enabled: s.status == 'AVAILABLE',
                    child: Row(
                      children: [
                        Icon(
                          s.status == 'AVAILABLE'
                              ? Icons.circle
                              : Icons.cancel,
                          size: 10,
                          color: s.status == 'AVAILABLE'
                              ? AppTheme.success
                              : AppTheme.danger,
                        ),
                        const SizedBox(width: 8),
                        Text('${s.stationId} • ${s.name}'),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: onStationChanged,
          ),
          const SizedBox(height: 16),
          const Text(
            'สแกน Pallet สำหรับ Sort',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          ScanTextField(
            label: 'Pallet ID',
            hint: 'Scan Pallet ID',
            controller: palletController,
            focusNode: palletFocus,
            onSubmit: onOpen,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'เริ่ม Session',
            icon: Icons.play_arrow,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}
