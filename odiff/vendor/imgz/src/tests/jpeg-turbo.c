#include "shared.h"
#include <stdio.h>
#include <stdlib.h>

#include <jpeglib.h>

bool test_jpeg_encode() {
  const size_t width = 16;
  const size_t height = 16;

  auto rgb_pixels = generate_gradient_pixels(width, height, false);

  unsigned char *jpeg_buffer = NULL;
  unsigned long jpeg_size = 0;
  struct jpeg_compress_struct cinfo;
  struct jpeg_error_mgr jerr;
  cinfo.err = jpeg_std_error(&jerr);
  jpeg_create_compress(&cinfo);
  jpeg_mem_dest(&cinfo, &jpeg_buffer, &jpeg_size);
  cinfo.image_width = width;
  cinfo.image_height = height;
  cinfo.input_components = 3;
  cinfo.in_color_space = JCS_RGB;
  jpeg_set_defaults(&cinfo);
  jpeg_set_quality(&cinfo, 90, TRUE);
  jpeg_start_compress(&cinfo, TRUE);

  const size_t row_stride = width * 3;
  unsigned char *row_ptr = rgb_pixels.data;
  while (cinfo.next_scanline < cinfo.image_height) {
    JSAMPROW row_pointers[1] = {row_ptr};
    jpeg_write_scanlines(&cinfo, row_pointers, 1);
    row_ptr += row_stride;
  }
  jpeg_finish_compress(&cinfo);
  jpeg_destroy_compress(&cinfo);

  free(rgb_pixels.data);
  free(jpeg_buffer);
  return jpeg_size > 0;
}

bool test_jpeg_decode() {
  auto jpeg_data = read_file("src/tests/test-images/orange.jpeg");
  if (!jpeg_data.data)
    return false;

  struct jpeg_decompress_struct dinfo;
  struct jpeg_error_mgr djerr;
  dinfo.err = jpeg_std_error(&djerr);
  jpeg_create_decompress(&dinfo);
  jpeg_mem_src(&dinfo, jpeg_data.data, jpeg_data.len);
  if (jpeg_read_header(&dinfo, TRUE) != JPEG_HEADER_OK) {
    free(jpeg_data.data);
    jpeg_destroy_decompress(&dinfo);
    return false;
  }
  jpeg_start_decompress(&dinfo);

  size_t decoded_size =
      dinfo.output_width * dinfo.output_height * dinfo.num_components;
  uint8_t *decoded_rgb = malloc(decoded_size);
  if (!decoded_rgb) {
    free(jpeg_data.data);
    jpeg_destroy_decompress(&dinfo);
    return false;
  }

  uint8_t *decoded_row_ptr = decoded_rgb;
  size_t decoded_row_stride = dinfo.output_width * dinfo.num_components;
  while (dinfo.output_scanline < dinfo.output_height) {
    JSAMPROW decoded_row_pointers[1] = {decoded_row_ptr};
    jpeg_read_scanlines(&dinfo, decoded_row_pointers, 1);
    decoded_row_ptr += decoded_row_stride;
  }
  jpeg_finish_decompress(&dinfo);
  jpeg_destroy_decompress(&dinfo);

  free(decoded_rgb);
  free(jpeg_data.data);
  return decoded_size > 0;
}

int main() {
  if (!test_jpeg_encode()) {
    printf("jpeg_encode failed\n");
    return 1;
  }

  if (!test_jpeg_decode()) {
    printf("jpeg_decode failed\n");
    return 1;
  }

  return 0;
}
