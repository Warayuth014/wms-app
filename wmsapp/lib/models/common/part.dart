class Part {
  final String partId;
  final String owner;
  final String brand;
  final String itemDesc;
  final String? imageUrl;

  Part({
    required this.partId,
    required this.owner,
    required this.brand,
    required this.itemDesc,
    this.imageUrl,
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
    partId: json['partId'],
    owner: json['owner'],
    brand: json['brand'],
    itemDesc: json['itemDesc'],
    imageUrl: json['imageUrl'],
  );
}
