#include "OTATSNode.h"

using namespace std;

OTATSNode::OTATSNode() {
}

OTATSNode::OTATSNode(string name, string detail, string token) {
    OTATSNode::name = name;   //字段
    OTATSNode::detail = detail;     //code
    OTATSNode::token = token; //类型
}

OTATSNode::~OTATSNode() {

}

OTATSNode &OTATSNode::operator=(const OTATSNode &node) {
    OTATSNode::name = node.name;
    OTATSNode::detail = node.detail;
    OTATSNode::token = node.token;
    OTATSNode::count = node.count;
    return *this;
}

OTATSNode::OTATSNode(string name, string detail, string token, int count) {
    OTATSNode::name = name;   //字段
    OTATSNode::detail = detail;     //code
    OTATSNode::token = token; //类型
    OTATSNode::count = count;
}
