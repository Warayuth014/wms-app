part of '../api_service.dart';

extension UploadApi on ApiService {
  Future<ApiResult<List<Map<String, dynamic>>>> getAllParts() async {
    final response = await _get('/upload/parts');
    if (!response.success) return ApiResult.error(response.error);

    final items = response.data!['items'] as List;
    return ApiResult.success(items.cast<Map<String, dynamic>>());
  }

  Future<ApiResult<Map<String, dynamic>>> uploadPartImage({
    required String partId,
    required File imageFile,
  }) {
    return _uploadFile(
      '/upload/part-image',
      imageFile,
      fields: {'partId': partId},
    );
  }

  Future<String> getImageFullUrl(String relativePath) async {
    final base = await ApiService._resolveBase();
    final serverBase = base.replaceAll('/api', '');
    return '$serverBase$relativePath';
  }
}
