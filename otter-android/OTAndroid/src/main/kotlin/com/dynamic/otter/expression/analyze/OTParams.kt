package com.dynamic.otter.expression.analyze

class OTParams {
    private val params: LongArray

    constructor(params: LongArray) {
        this.params = params
        //获取返回的参数列表结果
    }

    fun get(index: Int): OTValue? {
        return OTAnalyze.wrapAsSDValue(params[index])
    }

    fun getParamsLength(): Int {
        return params.count()
    }
}