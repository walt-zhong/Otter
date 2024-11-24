package com.dynamic.otter.data

object OTHelper {
    private const val HTTP_PREFIX = "http:"
    private const val HTTPS_PREFIX = "https:"
    private const val RES_PREFIX = "res:"
    private const val ASSET_PREFIX = "assets:"

    fun isNetSrc(url: String) =
        (url.startsWith(HTTP_PREFIX) || url.startsWith(HTTPS_PREFIX))

    fun isResSrc(url: String) = url.startsWith(RES_PREFIX)

    fun isAssetsSrc(url:String) = url.startsWith(ASSET_PREFIX)

    fun getResSrc(uri: String) = uri.replace(RES_PREFIX, "")

    fun getAssetsSrc(url: String) = url.replace(ASSET_PREFIX,"")

    fun isNumeric(str: String): Boolean {
        return str.matches(Regex("-?\\d+(\\.\\d+)?"))
    }
}