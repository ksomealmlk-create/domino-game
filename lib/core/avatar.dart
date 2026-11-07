import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:image_picker/image_picker.dart';

/// يفتح استوديو الجوال ويرجّع صورة مربعة صغيرة (PNG) مناسبة للإرسال أونلاين.
Future<Uint8List?> pickAvatar() async {
  final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
  if (x == null) return null;
  return shrinkAvatar(await x.readAsBytes());
}

Future<Uint8List> shrinkAvatar(Uint8List bytes, {int size = 80}) async {
  final codec = await ui.instantiateImageCodec(bytes, targetWidth: size * 2);
  final img = (await codec.getNextFrame()).image;
  final side = math.min(img.width, img.height).toDouble();
  final src = ui.Rect.fromLTWH((img.width - side) / 2, (img.height - side) / 2, side, side);
  final dst = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());
  final rec = ui.PictureRecorder();
  ui.Canvas(rec, dst).drawImageRect(img, src, dst, ui.Paint()..filterQuality = ui.FilterQuality.medium);
  final out = await rec.endRecording().toImage(size, size);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
