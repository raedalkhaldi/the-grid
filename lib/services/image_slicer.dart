import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

class ImageSlicer {
  /// Slices a square-cropped image into gridSize x gridSize tiles.
  /// Returns a list of tiles indexed 0 to (gridSize²-1), left-to-right top-to-bottom.
  static Future<List<ui.Image>> slice(ui.Image source, int gridSize) async {
    // Crop to square (center crop)
    final minDim =
        source.width < source.height ? source.width : source.height;
    final offsetX = (source.width - minDim) ~/ 2;
    final offsetY = (source.height - minDim) ~/ 2;
    final tileSize = minDim / gridSize;

    final tiles = <ui.Image>[];

    for (int row = 0; row < gridSize; row++) {
      for (int col = 0; col < gridSize; col++) {
        final srcRect = Rect.fromLTWH(
          offsetX + col * tileSize,
          offsetY + row * tileSize,
          tileSize,
          tileSize,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        final tileSizeInt = tileSize.ceil();

        canvas.drawImageRect(
          source,
          srcRect,
          Rect.fromLTWH(0, 0, tileSizeInt.toDouble(), tileSizeInt.toDouble()),
          Paint()..filterQuality = FilterQuality.medium,
        );

        final picture = recorder.endRecording();
        final tile = await picture.toImage(tileSizeInt, tileSizeInt);
        tiles.add(tile);
      }
    }

    return tiles;
  }

  /// Decodes image bytes to ui.Image
  static Future<ui.Image> decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
}
