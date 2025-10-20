#include <jni.h>
#include <string>
#include "odiff_bindings.h" // header where CDiffOptions, CDiffResult, COdiffError, etc. are defined

extern "C" {
// Dummy implementations that do nothing or return safe defaults
int jsimd_can_ycc_rgb() { return 0; }  // SIMD not available
int jsimd_ycc_rgb_convert() { return 0; }
int jsimd_can_ycc_rgb565() { return 0; }
int jsimd_ycc_rgb565_convert() { return 0; }
int jsimd_can_idct_2x2() { return 0; }
int jsimd_idct_2x2() { return 0; }
int jsimd_can_idct_4x4() { return 0; }
int jsimd_idct_4x4() { return 0; }
int jsimd_can_encode_mcu_AC_refine_prepare() { return 0; }
int jsimd_encode_mcu_AC_refine_prepare() { return 0; }
int jsimd_can_encode_mcu_AC_first_prepare() { return 0; }
int jsimd_encode_mcu_AC_first_prepare() { return 0; }
int jpeg_nbits_table() { return 0; }
int jsimd_can_huff_encode_one_block() { return 0; }
int jsimd_can_fdct_islow() { return 0; }
int jsimd_fdct_islow() { return 0; }
int jsimd_can_fdct_ifast() { return 0; }
int jsimd_fdct_ifast() { return 0; }
int jsimd_can_fdct_float() { return 0; }
int jsimd_fdct_float() { return 0; }
int jsimd_can_convsamp() { return 0; }
int jsimd_convsamp() { return 0; }
int jsimd_can_convsamp_float() { return 0; }
int jsimd_huff_encode_one_block() { return 0; }
int jsimd_can_h2v1_downsample() { return 0; }
int jsimd_h2v1_downsample() { return 0; }
int jsimd_can_h2v2_downsample() { return 0; }
int jsimd_h2v2_downsample() { return 0; }
int jsimd_can_rgb_ycc() { return 0; }
int jsimd_rgb_ycc_convert() { return 0; }
int jsimd_can_rgb_gray() { return 0; }
int jsimd_rgb_gray_convert() { return 0; }
int jsimd_can_h2v1_fancy_upsample() { return 0; }
int jsimd_can_h2v1_upsample() { return 0; }
int jsimd_h2v1_upsample() { return 0; }
int jsimd_can_h2v2_fancy_upsample() { return 0; }
int jsimd_h2v2_fancy_upsample() { return 0; }
int jsimd_can_h2v2_merged_upsample() { return 0; }
int jsimd_h2v2_merged_upsample() { return 0; }
int jsimd_convsamp_float() { return 0; }
int jsimd_can_quantize() { return 0; }
int jsimd_h2v1_fancy_upsample() { return 0; }
int jsimd_can_h2v2_upsample() { return 0; }
int jsimd_h2v2_upsample() { return 0; }
int jsimd_quantize() { return 0; }
int jsimd_can_quantize_float() { return 0; }
int jsimd_quantize_float() { return 0; }
int jsimd_can_h2v1_merged_upsample() { return 0; }
int jsimd_h2v1_merged_upsample() { return 0; }
int jsimd_can_idct_islow() { return 0; }
int jsimd_idct_islow() { return 0; }
int jsimd_can_idct_ifast() { return 0; }
int jsimd_idct_ifast() { return 0; }
int jsimd_can_idct_float() { return 0; }
int jsimd_idct_float() { return 0; }
int jsimd_can_h1v2_fancy_upsample() { return 0; }
int jsimd_h1v2_fancy_upsample() { return 0; }
//int jsimd_can_quantize() { return 0; }

//int jsimd_can_h2v1_fancy_upsample() { return 0; }
//int jsimd_can_h2v1_fancy_upsample() { return 0; }
//int jsimd_can_h2v1_fancy_upsample() { return 0; }

}
//
//
extern "C" {
COdiffError
odiff_diff(const char *base_image_path, const char *comp_image_path, const char *diff_output_path,
           CDiffOptions options);

void odiff_free_diff_lines(unsigned int *diff_lines, size_t count);

//// Helper to convert jstring → std::string // chatgpt
static std::string jstringToString(JNIEnv *env, jstring jstr) {
    if (!jstr) return {};
    const char *chars = env->GetStringUTFChars(jstr, nullptr);
    std::string str(chars);
    env->ReleaseStringUTFChars(jstr, chars);
    return str;
}
//
//// JNI: odiff_diff(base, comp, diffOut, options)
JNIEXPORT jint JNICALL
Java_com_jossephus_sample_1android_1odiff_ODiffLib_odiff_1diff

        (JNIEnv *env, jobject /*thiz*/,
         jstring jbase, jstring jcomp, jstring jdiffOut,
         jobject joptions) {
    CDiffOptions options = {};

    // Extract fields from the Java options object
    jclass cls = env->GetObjectClass(joptions);
    options.antialiasing = env->GetIntField(joptions, env->GetFieldID(cls, "antialiasing", "I"));
    options.output_diff_mask = env->GetIntField(joptions,
                                                env->GetFieldID(cls, "outputDiffMask", "I"));
    options.diff_overlay_factor = env->GetFloatField(joptions,
                                                     env->GetFieldID(cls, "diffOverlayFactor",
                                                                     "F"));
    options.diff_lines = env->GetIntField(joptions, env->GetFieldID(cls, "diffLines", "I"));
    options.diff_pixel = env->GetIntField(joptions, env->GetFieldID(cls, "diffPixel", "I"));
    options.threshold = env->GetDoubleField(joptions, env->GetFieldID(cls, "threshold", "D"));
    options.fail_on_layout_change = env->GetIntField(joptions,
                                                     env->GetFieldID(cls, "failOnLayoutChange",
                                                                     "I"));
    options.enable_asm = env->GetIntField(joptions, env->GetFieldID(cls, "enableAsm", "I"));
    options.ignore_region_count = 0;
    options.ignore_regions = nullptr;

    std::string base = jstringToString(env, jbase);
    std::string comp = jstringToString(env, jcomp);
    std::string diffOut = jstringToString(env, jdiffOut);

    COdiffError err = odiff_diff(base.c_str(), comp.c_str(), diffOut.c_str(), options);
    return static_cast<jint>(err);
}

} // extern "C"
