#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  int antialiasing;
  int output_diff_mask;
  float diff_overlay_factor;
  int diff_lines;
  unsigned int diff_pixel;
  double threshold;
  int fail_on_layout_change;
  int enable_asm;
  size_t ignore_region_count;
  void* ignore_regions; // array of IgnoreRegion
} CDiffOptions;

typedef struct {
  int result_type; // 0 = layout, 1 = pixel
  unsigned int diff_count;
  double diff_percentage;
  size_t diff_line_count;
  unsigned int* diff_lines;
  const char* diff_output_path;
} CDiffResult;

typedef enum {
  SUCCESS = 0,
  IMAGE_NOT_LOADED = 1,
  UNSUPPORTED_FORMAT = 2,
  FAILED_TO_DIFF = 3,
  OUT_OF_MEMORY = 4,
  INVALID_HEX_COLOR = 5,
} COdiffError;

// Declare the exported functions
COdiffError odiff_diff(const char* base_image_path, const char* comp_image_path, const char* diff_output_path, CDiffOptions options);
COdiffError odiff_diff_with_results(const char* base_image_path, const char* comp_image_path, const char* diff_output_path, CDiffOptions options, CDiffResult* out_result);
void odiff_free_diff_lines(unsigned int* diff_lines, size_t count);
int parse_hex_color(const char* hex_str);

// No custom allocator needed

int main(int argc, char* argv[]) {
  if (argc < 3) {
    printf("Usage: %s <base_image> <comp_image> [diff_output]\n", argv[0]);
    return 1;
  }

  const char* base_path = argv[1];
  const char* comp_path = argv[2];
  const char* diff_output = (argc >= 4) ? argv[3] : NULL;

  int diff_pixel = parse_hex_color("");

  // Set up options
  CDiffOptions options = {
    .antialiasing = 0,
    .output_diff_mask = 0,
    .diff_overlay_factor = 0.0f,
    .diff_lines = 0,
    .diff_pixel = diff_pixel,
    .threshold = 0.1,
    .fail_on_layout_change = 0,
    .enable_asm = 0,
    .ignore_region_count = 0,
    .ignore_regions = NULL,
  };

  CDiffResult result;
  COdiffError err = odiff_diff(base_path, comp_path, diff_output, options);

  return 0;
}

