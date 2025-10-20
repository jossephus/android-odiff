#include <jni.h>
extern "C" {
int add(int a, int b);
}

extern "C"
JNIEXPORT jint JNICALL
Java_com_jossephus_testodiff_12_NativeLib_add(JNIEnv *env, jobject thiz, jint a, jint b) {
    return add(a, b);
}
