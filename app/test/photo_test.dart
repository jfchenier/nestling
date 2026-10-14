import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nestling/widgets/photo.dart';

void main() {
  testWidgets("a memory's photo: a light copy for the app, a full-size one for printing", (tester) async {
    await tester.runAsync(() async {
      final camera = img.encodeJpg(img.Image(width: 4000, height: 3000));
      final picked = await memoryPhoto(camera);
      final photo = img.decodeJpg(picked.photo)!, print = img.decodeJpg(picked.print!)!;
      expect((photo.width, photo.height), (1600, 1200));
      expect((print.width, print.height), (3600, 2700));

      // A picture no larger than the light copy needs no other.
      final small = await memoryPhoto(img.encodeJpg(img.Image(width: 1200, height: 1600)));
      expect(img.decodeJpg(small.photo)!.height, 1600);
      expect(small.print, isNull);
    });
  });
}
