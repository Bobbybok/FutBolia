import 'package:image_picker/image_picker.dart';

class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
}

Future<PickedImage?> pickCompressedImage({
  double maxWidth = 1400,
  int imageQuality = 78,
}) async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: maxWidth,
    imageQuality: imageQuality,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  final name = picked.name.toLowerCase();
  final mime = name.endsWith('.png')
      ? 'image/png'
      : name.endsWith('.webp')
          ? 'image/webp'
          : 'image/jpeg';
  return PickedImage(
    bytes: bytes,
    filename: picked.name.isEmpty ? 'photo.jpg' : picked.name,
    contentType: mime,
  );
}
