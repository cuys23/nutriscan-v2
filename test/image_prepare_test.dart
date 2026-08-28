import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutriscan/services/ai/image_prepare.dart';

/// Guards the two things the scan payload actually depends on: that a big
/// photo comes back small enough to send, and that the declared mime type
/// matches the bytes that were actually encoded.
void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('image_prepare'));
  tearDown(() => tmp.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${tmp.path}/$name')..writeAsBytesSync(bytes);

  /// Noise, not flat colour — a solid image compresses to almost nothing and
  /// would pass the size assertion no matter how broken the resize is.
  img.Image noisy(int width, int height) {
    final image = img.Image(width: width, height: height);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        image.setPixelRgb(x, y, (x * 7) % 256, (y * 13) % 256, (x * y) % 256);
      }
    }
    return image;
  }

  ({String mime, int bytes}) decodeDataUrl(String dataUrl) {
    final split = dataUrl.indexOf(';base64,');
    return (
      mime: dataUrl.substring('data:'.length, split),
      bytes: base64Decode(dataUrl.substring(split + ';base64,'.length)).length,
    );
  }

  test('resizes a large photo to well under the 1MB payload budget', () async {
    final file = write('big.jpg', img.encodeJpg(noisy(4000, 3000), quality: 100));
    expect(file.lengthSync(), greaterThan(2 * 1024 * 1024));

    final result = decodeDataUrl(
      await ImagePrepare.processAndEncodeImage(file),
    );

    expect(result.bytes, lessThan(1024 * 1024));
    expect(result.mime, 'image/jpeg');
  });

  test('re-encoded PNG is declared as jpeg, not by its extension', () async {
    final file = write('shot.png', img.encodePng(noisy(2000, 2000)));

    final result = decodeDataUrl(
      await ImagePrepare.processAndEncodeImage(file),
    );

    expect(result.mime, 'image/jpeg');
    final decoded = img.decodeJpg(
      base64Decode(
        (await ImagePrepare.processAndEncodeImage(file)).split(';base64,')[1],
      ),
    );
    expect(decoded, isNotNull);
    // Longest side clamped, aspect ratio kept.
    expect(decoded!.width, 1024);
    expect(decoded.height, 1024);
  });

  test('small image survives the round trip unresized', () async {
    final file = write('small.jpg', img.encodeJpg(noisy(320, 240)));

    final decoded = img.decodeJpg(
      base64Decode(
        (await ImagePrepare.processAndEncodeImage(file)).split(';base64,')[1],
      ),
    );

    expect(decoded, isNotNull);
    expect(decoded!.width, 320);
    expect(decoded.height, 240);
  });

  test('undecodable bytes fall back to the original payload', () async {
    final file = write('broken.png', List.filled(64, 0));

    final result = decodeDataUrl(
      await ImagePrepare.processAndEncodeImage(file),
    );

    expect(result.mime, 'image/png');
    expect(result.bytes, 64);
  });
}
