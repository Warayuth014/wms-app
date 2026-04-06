import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../theme/theme.dart';
import 'dest_button.dart';
import 'station_wrapping_toggle.dart';

class StationDestinationSelector extends StatelessWidget {
  final String palletType;
  final String selectedDestination;
  final bool wrappingRequired;
  final ValueChanged<String> onDestinationChanged;
  final ValueChanged<bool> onWrappingChanged;

  const StationDestinationSelector({
    super.key,
    required this.palletType,
    required this.selectedDestination,
    required this.wrappingRequired,
    required this.onDestinationChanged,
    required this.onWrappingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isPW = palletType == 'PW';
    final headerColor = isPW ? AppTheme.warning : AppTheme.primary;
    final headerIcon = isPW ? Icons.warning_amber : MdiIcons.packageVariantClosed;
    final headerText = isPW
        ? 'Pallet ประเภท PW - เลือกปลายทาง'
        : 'Pallet ประเภท FG - เลือกปลายทาง';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: headerColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: headerColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headerIcon, color: headerColor, size: 18),
              const SizedBox(width: 6),
              Text(
                headerText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: headerColor,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DestButton(
                  label: 'ASRS',
                  subtitle: 'เก็บเข้าคลังหลัก',
                  icon: MdiIcons.officeBuildingOutline,
                  selected: selectedDestination == 'ASRS',
                  onTap: () => onDestinationChanged('ASRS'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: isPW
                    ? DestButton(
                        label: 'Prework',
                        subtitle: 'ส่งจุด Prework',
                        icon: MdiIcons.cogOutline,
                        selected: selectedDestination == 'PREWORK',
                        onTap: () => onDestinationChanged('PREWORK'),
                      )
                    : DestButton(
                        label: 'Replenish',
                        subtitle: 'เติมสต็อก Rack',
                        icon: Icons.refresh,
                        selected: selectedDestination == 'REPLENISH',
                        onTap: () => onDestinationChanged('REPLENISH'),
                      ),
              ),
            ],
          ),
          if (selectedDestination == 'ASRS') ...[
            const SizedBox(height: 12),
            StationWrappingToggle(
              value: wrappingRequired,
              onChanged: onWrappingChanged,
            ),
          ],
        ],
      ),
    );
  }
}
