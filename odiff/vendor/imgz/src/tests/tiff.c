#include <stdlib.h>
#include <tiffio.h>

#include "shared.h"

bool test_tiff_encode() {
  const size_t width = 16;
  const size_t height = 16;

  auto pixels = generate_gradient_pixels(width, height, true);

  const char *output_path = "./zig-cache/test-outputs/tiff_encode.tiff";
  TIFF *tif = TIFFOpen(output_path, "w");
  if (!tif) {
    free(pixels.data);
    return false;
  }

  TIFFSetField(tif, TIFFTAG_IMAGEWIDTH, (uint32_t)width);
  TIFFSetField(tif, TIFFTAG_IMAGELENGTH, (uint32_t)height);
  TIFFSetField(tif, TIFFTAG_SAMPLESPERPIXEL, 4);
  TIFFSetField(tif, TIFFTAG_BITSPERSAMPLE, 8);
  TIFFSetField(tif, TIFFTAG_ORIENTATION, ORIENTATION_TOPLEFT);
  TIFFSetField(tif, TIFFTAG_PLANARCONFIG, PLANARCONFIG_CONTIG);
  TIFFSetField(tif, TIFFTAG_PHOTOMETRIC, PHOTOMETRIC_RGB);
  TIFFSetField(tif, TIFFTAG_COMPRESSION, COMPRESSION_NONE);
  TIFFSetField(tif, TIFFTAG_ROWSPERSTRIP, (uint32_t)height);

  if (TIFFWriteEncodedStrip(tif, 0, pixels.data, pixels.len) == -1) {
    free(pixels.data);
    TIFFClose(tif);
    return false;
  }

  free(pixels.data);
  TIFFClose(tif);

  // Check if file exists and has size > 0
  FILE *f = fopen(output_path, "rb");
  if (!f)
    return false;
  fseek(f, 0, SEEK_END);
  size_t size = ftell(f);
  fclose(f);
  remove(output_path);
  return size > 0;
}

bool test_tiff_decode() {
  const char *image_path = "src/tests/test-images/orange.tiff";
  TIFF *tif = TIFFOpen(image_path, "r");
  if (!tif)
    return false;

  uint32_t width, height;
  TIFFGetField(tif, TIFFTAG_IMAGEWIDTH, &width);
  TIFFGetField(tif, TIFFTAG_IMAGELENGTH, &height);

  uint32_t *pixels = malloc(width * height * sizeof(uint32_t));
  if (!pixels) {
    TIFFClose(tif);
    return false;
  }

  if (TIFFReadRGBAImage(tif, width, height, pixels, 0) == 0) {
    free(pixels);
    TIFFClose(tif);
    return false;
  }

  free(pixels);
  TIFFClose(tif);
  return true;
}

int main() {
  if (!test_tiff_encode()) {
    printf("tiff_encode failed\n");
    return 1;
  }

  if (!test_tiff_decode()) {
    printf("tiff_decode failed\n");
    return 1;
  }

  return 0;
}
