#include <stdio.h>
#include <stdlib.h>

#include "shared.h"

Slice generate_gradient_pixels(size_t width, size_t height, bool rgba) {
  uint32_t components = 3;
  if (rgba)
    components = 4;
  uint8_t *pixels = calloc(width * height * components, sizeof(uint8_t));
  Slice result = {pixels, width * height * components};
  for (size_t i = 0; i < width * height; i++) {
    uint8_t x = i % width;
    uint8_t y = i / width;
    uint8_t base = i * components;
    pixels[base + 0] = x * 255 / (width - 1);
    pixels[base + 1] = y * 255 / (height - 1);
    pixels[base + 2] = 0;
    if (rgba) {
      pixels[base + 3] = 255;
    }
  }
  return result;
}

Slice read_file(const char *path) {
  FILE *file = fopen(path, "rb");
  if (!file) {
    return (Slice){NULL, 0};
  }
  fseek(file, 0, SEEK_END);
  size_t len = ftell(file);
  fseek(file, 0, SEEK_SET);
  uint8_t *data = malloc(len);
  if (!data) {
    fclose(file);
    return (Slice){NULL, 0};
  }
  fread(data, 1, len, file);
  fclose(file);
  return (Slice){data, len};
}
