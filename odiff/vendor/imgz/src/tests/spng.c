#include "shared.h"
#include <spng.h>

bool test_spng_encode() {
  auto ctx = spng_ctx_new(SPNG_CTX_ENCODER);
  if (!ctx)
    return false;

  auto ihdr = (struct spng_ihdr){
      .width = 16,
      .height = 16,
      .bit_depth = 8,
      .color_type = SPNG_COLOR_TYPE_TRUECOLOR_ALPHA,
      .compression_method = 0,
      .filter_method = 0,
      .interlace_method = 0,
  };
  if (spng_set_ihdr(ctx, &ihdr) != 0) {
    return false;
  }

  if (spng_set_option(ctx, SPNG_ENCODE_TO_BUFFER, 1) != 0) {
    return false;
  }

  auto pixels = generate_gradient_pixels(16, 16, true);

  if (spng_encode_image(ctx, pixels.data, pixels.len, SPNG_FMT_PNG,
                        SPNG_ENCODE_FINALIZE) != 0) {
    return false;
  }

  size_t out_len = 0;
  int error_code = 0;
  auto out_buffer = spng_get_png_buffer(ctx, &out_len, &error_code);
  if (out_buffer == NULL || error_code != 0) {
    return false;
  }

  bool result = out_len > 0;

  free(pixels.data);
  spng_ctx_free(ctx);

  return result;
}

bool test_spng_decode() {
  auto image_data = read_file("src/tests/test-images/orange.png");
  if (!image_data.data)
    return false;

  auto ctx = spng_ctx_new(0);
  if (!ctx) {
    free(image_data.data);
    return false;
  }

  if (spng_set_png_buffer(ctx, image_data.data, image_data.len) != 0) {
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  size_t size = 0;
  if (spng_decoded_image_size(ctx, SPNG_FMT_RGBA8, &size) != 0) {
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  uint8_t *pixels = malloc(size);
  if (!pixels) {
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  if (spng_decode_image(ctx, pixels, size, SPNG_FMT_RGBA8, SPNG_DECODE_TRNS) !=
      0) {
    free(pixels);
    free(image_data.data);
    spng_ctx_free(ctx);
    return false;
  }

  free(pixels);
  free(image_data.data);
  spng_ctx_free(ctx);
  return true;
}

int main() {
  if (!test_spng_encode()) {
    printf("spng_encode failed\n");
    return 1;
  }

  if (!test_spng_decode()) {
    printf("spng_decode failed\n");
    return 1;
  }

  return 0;
}
