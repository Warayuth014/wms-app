import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class PreworkReceiveEmptyState extends StatelessWidget {
  final EdgeInsets padding;

  const PreworkReceiveEmptyState({
    super.key,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          children: [
            Icon(MdiIcons.packageVariant, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'No pallet at this station',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Send a PW pallet from Putaway first',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }
}
