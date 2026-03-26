// lib/widgets/part_thumbnail.dart

import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// Thumbnail รูปสินค้า — ใช้ได้ทุกที่ที่โชว์รายการ Part
/// ถ้า imageUrl เป็น null จะโชว์ icon แทน
class PartThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;

  const PartThumbnail({
    super.key,
    this.imageUrl,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = imageUrl != null && imageUrl!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade100,
        child: hasImg
            ? FutureBuilder<String>(
                future: ApiService().getImageFullUrl(imageUrl!),
                builder: (_, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return Image.network(
                    snap.data!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey.shade400,
                      size: size * 0.5,
                    ),
                  );
                },
              )
            : Icon(
                Icons.inventory_2_outlined,
                color: Colors.grey.shade400,
                size: size * 0.5,
              ),
      ),
    );
  }
}
