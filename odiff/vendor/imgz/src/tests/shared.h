#ifndef SHARED_H
#define SHARED_H

#include <stddef.h>
#include <stdint.h>

typedef struct Slice {
  uint8_t *data;
  size_t len;
} Slice;

Slice generate_gradient_pixels(size_t width, size_t height, bool rgba);
Slice read_file(const char *path);

#endif
