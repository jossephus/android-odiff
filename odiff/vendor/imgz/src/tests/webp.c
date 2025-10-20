#include <stdio.h>
#include <stdlib.h>

#include "shared.h"
#include <webp/decode.h>
#include <webp/encode.h>

bool test_webp_encode() {
  const int width = 16;
  const int height = 16;

  auto rgba_pixels = generate_gradient_pixels(width, height, true);

  uint8_t *webp_buffer = NULL;
  size_t webp_size = WebPEncodeRGBA(rgba_pixels.data, width, height, width * 4,
                                    90, &webp_buffer);

  free(rgba_pixels.data);
  WebPFree(webp_buffer);
  return webp_size > 0;
}

bool test_webp_decode() {
  auto rgba_pixels = read_file("src/tests/test-images/orange.webp");
  if (!rgba_pixels.data)
    return false;

  int decoded_width, decoded_height;
  uint8_t *decoded_pixels = WebPDecodeRGBA(rgba_pixels.data, rgba_pixels.len,
                                           &decoded_width, &decoded_height);

  free(rgba_pixels.data);
  if (!decoded_pixels)
    return false;
  WebPFree(decoded_pixels);
  return true;
}

int main() {
  if (!test_webp_encode()) {
    printf("webp_encode failed\n");
    return 1;
  }

  if (!test_webp_decode()) {
    printf("webp_decode failed\n");
    return 1;
  }

  return 0;
}
