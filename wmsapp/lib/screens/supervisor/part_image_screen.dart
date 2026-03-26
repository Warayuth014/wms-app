// lib/screens/supervisor/part_image_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/api_service.dart';

class PartImageScreen extends StatefulWidget {
  final String userId;
  final String fullName;

  const PartImageScreen({
    super.key,
    required this.userId,
    required this.fullName,
  });

  @override
  State<PartImageScreen> createState() => _PartImageScreenState();
}

class _PartImageScreenState extends State<PartImageScreen> {
  final _api = ApiService();
  final _picker = ImagePicker();
  final _searchCtrl = TextEditingController();

  bool _loading = false;
  List<Map<String, dynamic>> _allParts = [];
  List<Map<String, dynamic>> _filteredParts = [];

  @override
  void initState() {
    super.initState();
    _loadParts();
    _searchCtrl.addListener(_filterParts);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadParts() async {
    setState(() => _loading = true);
    final result = await _api.getAllParts();
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'โหลดข้อมูลไม่ได้');
      return;
    }

    setState(() {
      _allParts = result.data!;
      _filterParts();
    });
  }

  void _filterParts() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredParts = _allParts;
      } else {
        _filteredParts = _allParts.where((p) {
          final partId = (p['partId'] as String).toLowerCase();
          final desc = (p['itemDesc'] as String).toLowerCase();
          final brand = (p['brand'] as String).toLowerCase();
          return partId.contains(q) || desc.contains(q) || brand.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _pickAndUpload(Map<String, dynamic> part) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('ถ่ายรูป'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _loading = true);
    final result = await _api.uploadPartImage(
      partId: part['partId'],
      imageFile: File(picked.path),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.success) {
      showErrorDialog(context, message: result.error ?? 'อัปโหลดไม่สำเร็จ');
      return;
    }

    showSuccessSnackbar(context, 'อัปโหลดรูป ${part['partId']} สำเร็จ');
    await _loadParts();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _filteredParts.where((p) => p['imageUrl'] != null).length;
    final total = _filteredParts.length;

    return Scaffold(
      appBar: WmsAppBar(title: 'จัดการรูปสินค้า', userName: widget.fullName),
      body: LoadingOverlay(
        loading: _loading,
        message: 'กำลังดำเนินการ...',
        child: Column(
          children: [
            // ── Search + Stats ──
            Container(
              padding: const EdgeInsets.all(16),
              color: AppTheme.primary.withValues(alpha: 0.05),
              child: Column(
                children: [
                  TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'ค้นหา Part ID, ชื่อสินค้า, แบรนด์...',
                      prefixIcon: const Icon(Icons.search),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 10,
                        horizontal: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      filled: true,
                      fillColor: AppTheme.surface(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'ทั้งหมด $total รายการ',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textGrey(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'มีรูป $hasImage',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'ยังไม่มี ${total - hasImage}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _loadParts,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── List ──
            Expanded(
              child: _filteredParts.isEmpty
                  ? Center(
                      child: Text(
                        'ไม่พบรายการ',
                        style: TextStyle(color: AppTheme.textGrey(context)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _filteredParts.length,
                      itemBuilder: (_, i) => _buildPartCard(_filteredParts[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartCard(Map<String, dynamic> part) {
    final partId = part['partId'] as String;
    final itemDesc = part['itemDesc'] as String;
    final owner = part['owner'] as String;
    final brand = part['brand'] as String;
    final imageUrl = part['imageUrl'] as String?;
    final hasImg = imageUrl != null && imageUrl.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: hasImg
              ? AppTheme.success.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _pickAndUpload(part),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // ── Thumbnail ──
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 56,
                  height: 56,
                  color: Colors.grey.shade100,
                  child: hasImg
                      ? FutureBuilder<String>(
                          future: _api.getImageFullUrl(imageUrl),
                          builder: (_, snap) {
                            if (!snap.hasData) {
                              return const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            }
                            return Image.network(
                              snap.data!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            );
                          },
                        )
                      : Icon(
                          Icons.add_a_photo,
                          color: AppTheme.textGrey(context),
                          size: 24,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Info ──
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          partId,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (hasImg)
                          const Icon(Icons.check_circle,
                              color: AppTheme.success, size: 16)
                        else
                          Icon(Icons.image_not_supported,
                              color: AppTheme.textGrey(context), size: 16),
                      ],
                    ),
                    Text(
                      itemDesc,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textGrey(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '$owner / $brand',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textGrey(context),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Upload button ──
              IconButton(
                icon: Icon(
                  hasImg ? Icons.edit : Icons.add_a_photo,
                  color: AppTheme.primary,
                ),
                onPressed: () => _pickAndUpload(part),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
