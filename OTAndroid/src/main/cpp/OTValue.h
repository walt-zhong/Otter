#ifndef GXANALYZEANDROID_GXVALUE_H
#define GXANALYZEANDROID_GXVALUE_H

#include <stdio.h>
#include <stdint.h>
#include <string>

enum {
    OT_TAG_FLOAT = 0,
    OT_TAG_BOOL = 1,
    OT_TAG_NULL = 2,
    OT_TAG_VALUE = 3,
    OT_TAG_STRING = 4,
    OT_TAG_OBJECT = 5,
    OT_TAG_ARRAY = 6,
    OT_TAG_MAP = 7,
    OT_TAG_LONG = 8,
};

class OTValue {
public:
    int64_t tag;
    int32_t int32;  //Bool 1，0
    float float64;  //Float
    int64_t intNum;    //long
    void *ptr;      //Array,Map
    char *str;      //String
    OTValue() {}

    OTValue(int tag, float f) {
        this->tag = tag;
        this->float64 = f;
    }

    OTValue(int tag, int32_t i) {
        this->tag = tag;
        this->int32 = i;
    }

    OTValue(int tag, int64_t i) {
        this->tag = tag;
        this->intNum = i;
    }

    OTValue(int tag, void *p) {
        this->tag = tag;
        this->ptr = p;
    }

    OTValue(int tag, std::string s) {
        this->tag = tag;
        int len = strlen(s.c_str());
        this->str = new char[len + 1];
        for (int i = 0; i < len; i++) {
            this->str[i] = s[i];
        }
        this->str[len] = '\0';
    }

    ~OTValue() {

    }

private:

};

static void releaseGXValue(long v) {
    OTValue *val = (OTValue *) v;
    delete val;
}

static int GX_VALUE_GET_TAG(OTValue v) {
    return v.tag;
}

static long GX_VALUE_GET_LONG(OTValue v) {
    return v.intNum;
}

static int32_t GX_VALUE_GET_BOOL(OTValue v) {
    return v.int32;
}

static float GX_VALUE_GET_FLOAT64(OTValue v) {
    return v.float64;
}

static void *GX_VALUE_GET_OBJECT(OTValue v) {
    return v.ptr;
}


/**
 * 通过该方法NewNull对象
 * @param val long值
 */
static OTValue *GX_NewNull(int val) {
    OTValue *v = new OTValue(OT_TAG_NULL, val);
    return v;
}

/**
 * 通过该方法NewInt对象
 * @param val long值
 */
static OTValue *GX_NewLong(int64_t val) {
    OTValue *v = new OTValue(OT_TAG_LONG, val);
    return v;
}

/**
 * 通过该方法NewArray对象
 * @param val long值
 */
static OTValue *GX_NewArray(void *val) {
    OTValue *v = new OTValue(OT_TAG_ARRAY, val);
    return v;
}

/**
 * 通过该方法NewMap对象
 * @param val long值
 */
static OTValue *GX_NewMap(void *val) {
    OTValue *v = new OTValue(OT_TAG_MAP, val);
    return v;
}

/**
 * 通过该方法NewBool对象
 * @param val bool对应的int值
 */
static OTValue *GX_NewBool(int val) {
    OTValue *v = new OTValue(OT_TAG_BOOL, val);
    return v;
}

/**
 * 通过该方法newFloat值
 * @param d Value值
 */
static OTValue *GX_NewFloat64(float d) {
    OTValue *v = new OTValue(OT_TAG_FLOAT, d);
    return v;
}

/**
 * 通过该方法NewString对象
 * @param str 字符串的值
 */
static OTValue *GX_NewGXString(const char *str) {
    OTValue *v = new OTValue(OT_TAG_STRING, str);
    return v;
}

#endif //GXANALYZEANDROID_GXVALUE_H
