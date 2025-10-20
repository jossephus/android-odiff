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
    void *ignore_regions; // array of IgnoreRegion
} CDiffOptions;

typedef struct {
    int result_type; // 0 = layout, 1 = pixel
    unsigned int diff_count;
    double diff_percentage;
    size_t diff_line_count;
    unsigned int *diff_lines;
    const char *diff_output_path;
} CDiffResult;

typedef enum {
    SUCCESS = 0,
    IMAGE_NOT_LOADED = 1,
    UNSUPPORTED_FORMAT = 2,
    FAILED_TO_DIFF = 3,
    OUT_OF_MEMORY = 4,
    INVALID_HEX_COLOR = 5,
} COdiffError;
