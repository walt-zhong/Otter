package com.dynamic.otter.demo

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.view.View
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.appcompat.widget.LinearLayoutCompat
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.nav.PageStack
import com.dynamic.otter.utils.AssetsUtils

class MarketActivity : AppCompatActivity() {
    private val session = MarketSession()
    private lateinit var tabLabels: List<TextView>
    private lateinit var tabMarks: List<View>
    private lateinit var containers: Map<String, View>
    private var selectedIndex = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_market)
        tabLabels = listOf(
            findViewById(R.id.tab_home_label),
            findViewById(R.id.tab_orders_label),
            findViewById(R.id.tab_mine_label)
        )
        tabMarks = listOf(
            findViewById(R.id.tab_home_mark),
            findViewById(R.id.tab_orders_mark),
            findViewById(R.id.tab_mine_mark)
        )
        val insetRoot = findViewById<View>(R.id.main)
        val home = findViewById<LinearLayoutCompat>(R.id.stack_home)
        val orders = findViewById<LinearLayoutCompat>(R.id.stack_orders)
        val mine = findViewById<LinearLayoutCompat>(R.id.stack_mine)
        containers = mapOf("home" to home, "orders" to orders, "mine" to mine)
        findViewById<View>(R.id.tab_home).setOnClickListener { showTab("home", 0) }
        findViewById<View>(R.id.tab_orders).setOnClickListener { showTab("orders", 1) }
        findViewById<View>(R.id.tab_mine).setOnClickListener { showTab("mine", 2) }
        selectTab(0)
        session.shops = readShops(this)
        session.openTab = { page ->
            val index = TAB_INDEX[page]
            if (index != null) {
                showTab(page, index)
            }
        }
        MarketSession.activate(session)
        val homeStack = PageStack.attach(
            this,
            insetRoot,
            home,
            "templates/market/routes.json",
            "demo",
            "market"
        )
        val ordersStack = PageStack.attach(
            this,
            insetRoot,
            orders,
            "templates/market/routes-orders.json",
            "demo",
            "market"
        )
        val mineStack = PageStack.attach(
            this,
            insetRoot,
            mine,
            "templates/market/routes-mine.json",
            "demo",
            "market"
        )
        session.stacks = listOf(homeStack, ordersStack, mineStack)
        session.stack = homeStack
        homeStack.activate()
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val current = session.stack
                if (current != null && current.depth > 1) {
                    isEnabled = false
                    onBackPressedDispatcher.onBackPressed()
                    if (!isFinishing) {
                        isEnabled = true
                    }
                    return
                }
                if (selectedIndex != 0) {
                    showTab("home", 0)
                    return
                }
                isEnabled = false
                onBackPressedDispatcher.onBackPressed()
            }
        })
    }

    override fun onDestroy() {
        session.release()
        super.onDestroy()
    }

    private fun showTab(page: String, index: Int) {
        val target = when (page) {
            "home" -> session.stacks.getOrNull(0)
            "orders" -> session.stacks.getOrNull(1)
            "mine" -> session.stacks.getOrNull(2)
            else -> null
        } ?: return
        session.stack = target
        target.activate()
        containers.forEach { (name, view) ->
            val show = name == page
            if (!show) {
                view.clearFocus()
            }
            view.visibility = if (show) View.VISIBLE else View.INVISIBLE
        }
        selectedIndex = index
        selectTab(index)
    }

    private fun selectTab(index: Int) {
        tabLabels.forEachIndexed { item, label ->
            val selected = item == index
            label.setTextColor(if (selected) ACCENT else MUTED)
            label.setTypeface(null, if (selected) Typeface.BOLD else Typeface.NORMAL)
            tabMarks[item].visibility = if (selected) View.VISIBLE else View.INVISIBLE
        }
    }

    companion object {
        private val ACCENT = Color.parseColor("#8B572A")
        private val MUTED = Color.parseColor("#8A8178")
        private val TAB_INDEX = mapOf("home" to 0, "orders" to 1, "mine" to 2)

        private fun readShops(context: Context): JSONArray {
            return try {
                val text = AssetsUtils.parseAssetsToString(
                    context,
                    "templates/market/mock-data/home.json"
                )
                val array = JSON.parseObject(text)?.getJSONArray("shops") ?: return JSONArray()
                JSON.parseArray(array.toJSONString()) ?: JSONArray()
            } catch (_: Exception) {
                JSONArray()
            }
        }
    }
}

private class MarketSession {
    var stack: PageStack? = null
    var stacks: List<PageStack> = emptyList()
    var shops: JSONArray = JSONArray()
    var openTab: ((String) -> Unit)? = null

    fun release() {
        if (current === this) {
            current = null
        }
        openTab = null
        stacks.forEach { it.release() }
        stacks = emptyList()
        stack = null
        shops = JSONArray()
    }

    fun pay(context: Context, params: JSONObject?) {
        val activity = context.findActivity() ?: return
        val paying = stack ?: return
        if (activity.isFinishing || activity.isDestroyed) {
            return
        }
        val amount = params.string("amount").orEmpty()
        AlertDialog.Builder(activity)
            .setTitle("确认支付")
            .setMessage(amount)
            .setPositiveButton("确认") { _, _ ->
                val payload = JSONObject()
                payload["orderNo"] = nextOrderNo()
                payload["amount"] = amount
                paying.replace("result", payload, null, null)
            }
            .setNegativeButton("取消", null)
            .show()
    }

    fun setQty(params: JSONObject?) {
        val currentStack = stack ?: return
        val lineId = params.string("lineId") ?: return
        val qty = parseQty(params.string("qty")) ?: return
        currentStack.editCurrentData { data ->
            val lines = data.getJSONArray("lines") ?: return@editCurrentData
            for (index in 0 until lines.size) {
                val line = lines.getJSONObject(index) ?: continue
                if (line.getString("lineId") == lineId) {
                    applyQty(line, qty)
                    break
                }
            }
            writeTotal(data, lines)
        }
        currentStack.rebindCurrent()
    }

    fun removeLine(params: JSONObject?) {
        val currentStack = stack ?: return
        val lineId = params.string("lineId") ?: return
        currentStack.editCurrentData { data ->
            val lines = data.getJSONArray("lines") ?: return@editCurrentData
            val kept = JSONArray()
            for (index in 0 until lines.size) {
                val line = lines.getJSONObject(index) ?: continue
                if (line.getString("lineId") != lineId) {
                    kept.add(line)
                }
            }
            data["lines"] = kept
            writeTotal(data, kept)
        }
        currentStack.rebindCurrent()
    }

    fun refreshStatus(context: Context) {
        val currentStack = stack ?: return
        currentStack.editCurrentData { data ->
            val orders = data.getJSONArray("orders") ?: return@editCurrentData
            if (orders.isEmpty()) {
                return@editCurrentData
            }
            val first = orders.getJSONObject(0) ?: return@editCurrentData
            if (first.getString("status") == "制作中") {
                first["status"] = "可取餐"
                first["statusNote"] = "可以到柜台取了，手冲还是热的。"
            }
        }
        currentStack.rebindCurrent()
        toast(context, "订单状态已更新")
    }

    fun callShop(context: Context, params: JSONObject?) {
        val phone = params.string("phone").orEmpty()
        toast(context, "正在联系店铺 $phone")
    }

    fun filter(params: JSONObject?) {
        val currentStack = stack ?: return
        val query = params.string("query").orEmpty().trim()
        val source = shops
        currentStack.editCurrentData { data ->
            val filtered = JSONArray()
            for (index in 0 until source.size) {
                val shop = source.getJSONObject(index) ?: continue
                val name = shop.getString("name").orEmpty()
                if (query.isEmpty() || name.contains(query)) {
                    filtered.add(JSON.parseObject(shop.toJSONString()))
                }
            }
            data["shops"] = filtered
            data["query"] = query
            data["noResult"] = query.isNotEmpty() && filtered.isEmpty()
        }
        currentStack.rebindCurrent()
    }

    companion object {
        private var current: MarketSession? = null

        fun activate(session: MarketSession) {
            current = session
            val center = ExpansionCenter.instance
            center.registerHostAction("pay") { context, params ->
                current?.pay(context, params)
            }
            center.registerHostAction("setQty") { _, params ->
                current?.setQty(params)
            }
            center.registerHostAction("removeLine") { _, params ->
                current?.removeLine(params)
            }
            center.registerHostAction("refreshStatus") { context, _ ->
                current?.refreshStatus(context)
            }
            center.registerHostAction("call") { context, params ->
                current?.callShop(context, params)
            }
            center.registerHostAction("filter") { _, params ->
                current?.filter(params)
            }
            center.registerHostAction("openTab") { _, params ->
                val page = params.string("page") ?: return@registerHostAction
                current?.openTab?.invoke(page)
            }
        }

        private fun applyQty(line: JSONObject, qty: Int) {
            val safe = if (qty < 1) 1 else qty
            val amount = line.getIntValue("price") * safe
            line["qty"] = safe
            line["qtyText"] = safe.toString()
            line["qtyMinus"] = (if (safe > 1) safe - 1 else 1).toString()
            line["qtyPlus"] = (safe + 1).toString()
            line["amount"] = amount.toString()
        }

        private fun writeTotal(data: JSONObject, lines: JSONArray) {
            var total = 0
            for (index in 0 until lines.size) {
                val line = lines.getJSONObject(index) ?: continue
                total += line.getIntValue("price") * line.getIntValue("qty")
            }
            data["total"] = total.toString()
            data["totalLabel"] = "$total 元"
            data["empty"] = lines.isEmpty()
        }

        private fun parseQty(raw: String?): Int? {
            val text = raw?.trim().orEmpty()
            if (text.isEmpty()) {
                return null
            }
            text.toIntOrNull()?.let { return it }
            return text.toDoubleOrNull()?.toInt()
        }

        private fun nextOrderNo(): String {
            val tail = (System.currentTimeMillis() % 1000000).toString().padStart(6, '0')
            return "NS$tail"
        }

        private fun toast(context: Context, message: String) {
            val activity = context.findActivity()
            if (activity != null && (activity.isFinishing || activity.isDestroyed)) {
                return
            }
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
        }

        private fun JSONObject?.string(key: String): String? {
            if (this == null || !containsKey(key)) {
                return null
            }
            val value = get(key) ?: return null
            return value.toString()
        }
    }
}

private fun Context.findActivity(): Activity? {
    var current: Context = this
    while (true) {
        if (current is Activity) {
            return current
        }
        if (current !is ContextWrapper) {
            return null
        }
        current = current.baseContext
    }
}
