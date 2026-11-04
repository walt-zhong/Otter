#ifndef _ATSNODE__H_
#define _ATSNODE__H_

#include <string>
#include <iostream>

using namespace std;

class OTATSNode {
public:
    OTATSNode();                                   //无参构造函数
    OTATSNode(string name, string detail, string token); //有参构造函数
    OTATSNode(string name, string detail, string token, int count); //有参构造函数
    ~OTATSNode();                                  //析构函数
    OTATSNode &operator=(const OTATSNode &node);

    string name;  //字段
    string token; //类型
    string detail;
    int count;

private:
};

#endif /*include _ATSNODE__H_*/
