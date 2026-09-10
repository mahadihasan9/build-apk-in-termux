#include <jni.h>
#include <string>

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_myfirstapp_MainActivity_getMessage(JNIEnv* env, jobject /* this */) {
    std::string message = "Hello Brother, Welcome ";
    return env->NewStringUTF(message.c_str());
}
