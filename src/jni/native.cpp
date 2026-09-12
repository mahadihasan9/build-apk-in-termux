#include <jni.h>
#include <string>
#include <ctime>

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_myfirstapp_MainActivity_getMessage(JNIEnv* env, jobject /* this */) {
    std::time_t result = std::time(nullptr);
    char *time = std::ctime(&result);
    std::string message = "Current time: " + std::string(time);
    return env->NewStringUTF(message.c_str());
}
