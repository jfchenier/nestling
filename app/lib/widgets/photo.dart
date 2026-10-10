import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

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

/// Let the user pick a picture for a memory: scaled down to at most [maxSide] px on its long
/// side and saved as a JPEG (a few hundred KB), so the baby book stays light to store and sync.
/// Null if cancelled.
Future<Uint8List?> pickMemoryPhoto({int maxSide = 1600}) async {
  final files = await FilePicker.pickFiles(type: FileType.image);
  if (files.isEmpty) return null;
  return memoryPhoto(await files.first.xFile.readAsBytes(), maxSide: maxSide);
}

Future<Uint8List> memoryPhoto(Uint8List bytes, {int maxSide = 1600}) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  final scale = math.min(1.0, maxSide / math.max(image.width, image.height));
  final w = math.max(1, (image.width * scale).round()), h = math.max(1, (image.height * scale).round());
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
    ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.high,
  );
  final scaled = await recorder.endRecording().toImage(w, h);
  final rgba = await scaled.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  // JPEG encoding is plain Dart: off the UI thread on phones (the web has no isolates).
  return compute(_jpeg, (rgba!.buffer.asUint8List(), w, h));
}

Uint8List _jpeg((Uint8List, int, int) raw) {
  final (rgba, w, h) = raw;
  final pic = img.Image.fromBytes(width: w, height: h, bytes: rgba.buffer, numChannels: 4);
  return img.encodeJpg(pic, quality: 82);
}
