import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

/// Let the user pick a picture and turn it into a centered square of at most [size] px (PNG),
/// small enough to upload and quick to show in the round avatars. Null if cancelled.
Future<Uint8List?> pickSquarePhoto({int size = 512}) async {
  final files = await FilePicker.pickFiles(type: FileType.image);
  if (files.isEmpty) return null;
  return squarePhoto(await files.first.xFile.readAsBytes(), size: size);
}

Future<Uint8List> squarePhoto(Uint8List bytes, {int size = 512}) async {
  // Plain decode (ImageDescriptor isn't available on the web); drawImageRect below does the
  // cropping and scaling.
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final side = math.min(image.width, image.height).toDouble();
  final out = math.min(size.toDouble(), side);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH((image.width - side) / 2, (image.height - side) / 2, side, side),
    ui.Rect.fromLTWH(0, 0, out, out),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final square = await recorder.endRecording().toImage(out.round(), out.round());
  final png = await square.toByteData(format: ui.ImageByteFormat.png);
  return png!.buffer.asUint8List();
}
