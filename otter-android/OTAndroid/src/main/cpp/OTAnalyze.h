#ifndef _GXANALYZE_CORE_H_
#define _GXANALYZE_CORE_H_

#include <stdlib.h>
#include "OTATSNode.h"
#include "OTWordAnalyze.h"
#include <vector>
#include "OTValue.h"
#include <set>
#include <unordered_map>
#include <regex>


using namespace std;

class OTAnalyze {
public:

    OTAnalyze();

    ~OTAnalyze();

    long getValue(string expression, void *source);

    //获取数据 $
    virtual long getSourceValue(string valuePath, void *source) = 0;

    //获取方法 Function
    virtual long
    getFunctionValue(string funName, long *paramPointers, int paramsSize, string source) = 0;

    virtual void throwError(string message) = 0;

private:

    //获取两个数值计算的结果
    OTATSNode doubleCalculate(OTATSNode value1, OTATSNode value2, string op);

    //获取单个数值计算的结果
    OTATSNode singleCalculate(OTATSNode value1, string op);

    long check(string s, vector<OTATSNode> array, void *p_analyze, void* source, string expression);

    long calculateCache(string cache, vector<OTATSNode> array, void *p_analyze, void* source);
};

#endif /*include _GXAnalyze__H_*/
