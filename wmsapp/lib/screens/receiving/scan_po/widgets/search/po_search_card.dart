import 'package:flutter/material.dart';

import '../../../../../widgets/common_widgets.dart';

class PoSearchCard extends StatelessWidget {
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSearch;

  const PoSearchCard({
    super.key,
    required this.controller,
    required this.loading,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return WmsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สแกน PO Invoice',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          ScanTextField(
            label: 'PO ID',
            hint: 'เช่น PO-001',
            controller: controller,
            onSubmit: onSearch,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'ค้นหา PO',
            icon: Icons.search,
            loading: loading,
            onPressed: onSearch,
          ),
        ],
      ),
    );
  }
}
