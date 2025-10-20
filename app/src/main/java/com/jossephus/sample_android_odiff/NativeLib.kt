package com.jossephus.sample_android_odiff

data class CDiffOptions(
    var antialiasing: Int = 0,
    var outputDiffMask: Int = 0,
    var diffOverlayFactor: Float = 0f,
    var diffLines: Int = 0,
    var diffPixel: Int = 0,
    var threshold: Double = 0.1,
    var failOnLayoutChange: Int = 0,
    var enableAsm: Int = 0,
    var ignoreRegionCount: Long = 0,
    var ignoreRegions: Long = 0 // native pointer
)

data class CDiffResult(
    var resultType: Int = 0,
    var diffCount: Int = 0,
    var diffPercentage: Double = 0.0,
    var diffLineCount: Long = 0,
    var diffLines: Long = 0, // native pointer
    var diffOutputPath: String? = null
)


object ODiffLib {
    init {
        System.loadLibrary("odiff_lib")
    }

    external fun odiff_diff(
        baseImagePath: String,
        compImagePath: String,
        diffOutputPath: String,
        options: CDiffOptions
    ): Int // COdiffError

//    external fun add(a: Int, b: Int): Int
}
