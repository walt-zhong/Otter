package com.dynamic.otter.nav

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.os.Bundle
import android.provider.Settings
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.Toast
import android.view.animation.DecelerateInterpolator
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.alibaba.fastjson.JSON
import com.alibaba.fastjson.JSONArray
import com.alibaba.fastjson.JSONObject
import com.dynamic.otter.OTEngine
import com.dynamic.otter.context.TemplateContext
import com.dynamic.otter.expression.ExpressionWrapper
import com.dynamic.otter.utils.AssetsUtils
import com.dynamic.otter.utils.toJson
import kotlin.math.max

class PageStack private constructor(
    private val activity: Activity,
    private val insetRoot: View,
    private val container: ViewGroup,
    private val routes: PageRouteTable,
    private val routePath: String,
    private val bizId: String,
    private val templateId: String
) {
    private val frames = PageFrames()
    private val stack = mutableListOf<Frame>()
    private val deferred = ArrayDeque<() -> Unit>()
    private val stage = FrameLayout(activity)
    private var insetsApplied = false
    private var ownsInsets = false
    private var scheduled = false
    private var startAttempted = false
    private var released = false
    private var laidOutWidth = 0
    private var laidOutHeight = 0
    private var generation = 0
    private var pendingDrop: Frame? = null
    private var dismissing: Frame? = null
    private var enteringView: View? = null
    private var leavingView: View? = null
    private var backCallback: OnBackPressedCallback? = null
    private var restored: List<SavedPage>? = null
    private val touchGuard = View(activity).apply {
        isClickable = true
        isFocusable = false
        importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    }

    val depth: Int
        get() = frames.depth

    private val layoutListener = View.OnLayoutChangeListener { _, left, top, right, bottom, _, _, _, _ ->
        if (right - left > 0 && bottom - top > 0) {
            render()
        }
    }

    fun open(
        page: String,
        rawParams: JSONObject?,
        itemData: JSONObject?,
        pageData: JSONObject?
    ) {
        if (released) {
            return
        }
        if (container.isInLayout) {
            defer { open(page, rawParams, itemData, pageData) }
            return
        }
        openNow(page, rawParams, itemData, pageData)
    }

    fun replace(
        page: String,
        rawParams: JSONObject?,
        itemData: JSONObject?,
        pageData: JSONObject?
    ) {
        if (released) {
            return
        }
        if (container.isInLayout) {
            defer { replace(page, rawParams, itemData, pageData) }
            return
        }
        replaceNow(page, rawParams, itemData, pageData)
    }

    fun pop(): Boolean = pop(null)

    fun popTo(page: String, rawParams: JSONObject?): Boolean {
        if (released) {
            return false
        }
        if (stack.indexOfLast { it.name == page } < 0) {
            return false
        }
        if (container.isInLayout) {
            defer { popTo(page, rawParams) }
            return true
        }
        return popToNow(page, rawParams)
    }

    fun editCurrentData(block: (JSONObject) -> Unit) {
        if (released) {
            return
        }
        val frame = stack.lastOrNull() ?: return
        if (frame.data == null) {
            val created = frame.templateContext?.data ?: JSONObject()
            frame.data = created
            val context = frame.templateContext
            if (context != null && context.data == null) {
                context.data = created
            }
        }
        PageForm.snapshot(frame.templateContext?.rootView, frame.data)
        block(frame.data!!)
    }

    fun rebindCurrent() {
        if (released) {
            return
        }
        if (container.isInLayout) {
            defer { rebindCurrent() }
            return
        }
        val context = stack.lastOrNull()?.templateContext ?: return
        if (context.rootView == null) {
            return
        }
        OTEngine.instance.rebind(context)
        PageForm.restore(context.rootView, stack.lastOrNull()?.data)
    }

    internal fun pop(rawParams: JSONObject?): Boolean {
        if (released || frames.depth <= 1) {
            return false
        }
        if (container.isInLayout) {
            defer { popNow(rawParams) }
            return true
        }
        return popNow(rawParams)
    }

    fun release() {
        if (released) {
            return
        }
        released = true
        endMotion()
        deferred.clear()
        stack.forEach { sever(it) }
        stack.clear()
        frames.clear()
        container.removeOnLayoutChangeListener(layoutListener)
        if (ownsInsets) {
            ViewCompat.setOnApplyWindowInsetsListener(insetRoot, null)
        }
        if (stage.parent === container) {
            container.removeView(stage)
        }
        backCallback?.remove()
        backCallback = null
        (activity as? ComponentActivity)?.savedStateRegistry?.unregisterSavedStateProvider(stateKey)
        val list = groups[activity]
        list?.remove(this)
        if (list.isNullOrEmpty()) {
            groups.remove(activity)
        }
        if (active[activity] === this) {
            active.remove(activity)
        }
    }

    fun activate() {
        if (released) {
            return
        }
        active[activity] = this
        groups[activity]?.forEach { it.syncBack() }
    }

    private fun install(manageInsets: Boolean) {
        ownsInsets = manageInsets
        stage.clipChildren = true
        container.addView(stage, matchParent())
        container.addOnLayoutChangeListener(layoutListener)
        registerHostCallbacks()
        if (manageInsets) {
            ViewCompat.setOnApplyWindowInsetsListener(insetRoot) { view, insets ->
                // enableEdgeToEdge 关掉了 adjustResize，键盘只通过 IME inset 报高度。
                val bars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
                val ime = insets.getInsets(WindowInsetsCompat.Type.ime())
                val bottom = max(bars.bottom, ime.bottom)
                if (view.paddingLeft != bars.left || view.paddingTop != bars.top ||
                    view.paddingRight != bars.right || view.paddingBottom != bottom
                ) {
                    view.setPadding(bars.left, bars.top, bars.right, bottom)
                    view.requestLayout()
                }
                groups[activity]?.forEach { stack ->
                    if (!stack.released) {
                        stack.insetsApplied = true
                        stack.render()
                    }
                }
                insets
            }
            ViewCompat.requestApplyInsets(insetRoot)
        } else if (groups[activity]?.any { it.insetsApplied } == true) {
            insetsApplied = true
            render()
        }
    }

    private val stateKey: String
        get() = "$STATE_KEY:$routePath"

    private fun registerHostCallbacks() {
        val host = activity as? ComponentActivity ?: return
        val callback = object : OnBackPressedCallback(false) {
            override fun handleOnBackPressed() {
                if (!pop()) {
                    isEnabled = false
                    host.onBackPressedDispatcher.onBackPressed()
                }
            }
        }
        backCallback = callback
        host.onBackPressedDispatcher.addCallback(host, callback)
        host.savedStateRegistry.registerSavedStateProvider(stateKey) {
            val bundle = Bundle()
            exportState()?.let { bundle.putString(STATE_JSON, it) }
            bundle
        }
        readRestored(host.savedStateRegistry.consumeRestoredStateForKey(stateKey))
    }

    private fun render() {
        if (released || !insetsApplied || container.width <= 0 || container.height <= 0) {
            return
        }
        // 布局过程中改尺寸会被丢掉，等这一轮结束再排。
        if (container.isInLayout) {
            defer { render() }
            return
        }
        if (stack.isNotEmpty()) {
            if (container.width == laidOutWidth && container.height == laidOutHeight) {
                return
            }
            laidOutWidth = container.width
            laidOutHeight = container.height
            relayout(stack.last())
            return
        }
        if (startAttempted) {
            return
        }
        startAttempted = true
        openStart()
    }

    private fun openStart() {
        val saved = restored
        restored = null
        if (saved.isNullOrEmpty()) {
            openNow(routes.start, null, null, null)
            return
        }
        for ((index, page) in saved.withIndex()) {
            val route = routes.pages[page.name]
            val data = try {
                if (page.data.isNullOrEmpty()) null else JSON.parseObject(page.data)
            } catch (_: Exception) {
                null
            }
            if (route == null || (page.data?.isNotEmpty() == true && data == null)) {
                abandonRestore()
                openNow(routes.start, null, null, null)
                return
            }
            val frame = Frame(page.name, route.template, data, null, page.slotKey, page.slotIndex)
            frame.scrolls.putAll(page.scrolls)
            stack.add(frame)
            frames.push(frame.name)
            if (index == saved.lastIndex && !materialize(frame, under = false)) {
                abandonRestore()
                openNow(routes.start, null, null, null)
                return
            }
        }
        syncBack()
        laidOutWidth = container.width
        laidOutHeight = container.height
    }

    private fun abandonRestore() {
        stack.forEach { sever(it) }
        stack.clear()
        frames.clear()
    }

    private fun openNow(
        page: String,
        rawParams: JSONObject?,
        itemData: JSONObject?,
        pageData: JSONObject?
    ) {
        Ime.dismiss(insetRoot)
        val entry = resolveEntry(page, rawParams, itemData, pageData, replace = false) ?: return
        val shown = createShown(page, entry, itemData) ?: return
        try {
            showFrame(shown.frame, shown.view)
        } catch (_: Exception) {
            shown.frame.templateContext?.release()
            toastCannotOpen()
        }
    }

    private fun replaceNow(
        page: String,
        rawParams: JSONObject?,
        itemData: JSONObject?,
        pageData: JSONObject?
    ) {
        Ime.dismiss(insetRoot)
        val entry = resolveEntry(page, rawParams, itemData, pageData, replace = true) ?: return
        val shown = createShown(page, entry, itemData) ?: return
        val removed = if (stack.isNotEmpty()) {
            frames.drop()
            stack.removeAt(stack.lastIndex)
        } else {
            null
        }
        if (removed != null && stack.isNotEmpty()) {
            showReplacement(shown.frame, shown.view, removed)
        } else if (removed != null) {
            swapFrame(shown.frame, shown.view, removed)
        } else {
            showFrame(shown.frame, shown.view)
        }
    }

    private fun resolveEntry(
        page: String,
        rawParams: JSONObject?,
        itemData: JSONObject?,
        pageData: JSONObject?,
        replace: Boolean
    ): Entry? {
        if (released) {
            return null
        }
        val route = routes.pages[page]
        if (route == null) {
            toastCannotOpen()
            return null
        }
        val current = stack.lastOrNull()
        // 滑入过程中新页面在屏幕外，点击会落到还没卸掉的上一页。那一页不能再打开。
        if (current != null && current.data !== pageData && current.templateContext?.data !== pageData) {
            return null
        }
        if (current != null) {
            PageForm.snapshot(current.templateContext?.rootView, current.data)
            PageForm.captureScroll(current.templateContext?.rootView, current.scrolls)
        }
        val scope = PageParams.merge(pageData ?: current?.data, itemData)
        val overlay = rawParams?.let { raw ->
            PageParams.evaluate(raw) { expression ->
                ExpressionWrapper.instance.getResult(expression, scope)
            }
        }
        if (!replace && current != null && current.name == page && PageParams.matches(current.data, overlay)) {
            return null
        }
        return Entry(route, current, overlay)
    }

    private fun createShown(page: String, entry: Entry, itemData: JSONObject?): Shown? {
        var created: TemplateContext? = null
        try {
            val base = if (entry.route.data != null) {
                AssetsUtils.parseAssetsToString(activity, entry.route.data).toJson()
            } else {
                null
            }
            val templateContext = OTEngine.instance.buildTemplate(bizId, templateId, entry.route.template)
            created = templateContext
            if (base != null || entry.overlay != null) {
                templateContext.setData(PageParams.merge(base, entry.overlay)!!.toJSONString())
            }
            val view = OTEngine.instance.createAndroidView(
                templateContext,
                OTEngine.OTViewPortSize(container.width.toFloat(), container.height.toFloat())
            )
            if (view == null) {
                templateContext.release()
                created = null
                toastCannotOpen()
                return null
            }
            val slot = PageParams.findItem(entry.current?.data, itemData)
            val frame = Frame(
                page,
                entry.route.template,
                templateContext.data,
                templateContext,
                slot?.first,
                slot?.second ?: -1
            )
            return Shown(frame, view)
        } catch (_: Exception) {
            created?.release()
            toastCannotOpen()
            return null
        }
    }

    private fun showFrame(frame: Frame, view: View) {
        endMotion()
        val covered = stack.lastOrNull()
        if (covered != null) {
            PageForm.snapshot(covered.templateContext?.rootView, covered.data)
            PageForm.captureScroll(covered.templateContext?.rootView, covered.scrolls)
            pendingDrop = covered
        }
        stack.add(frame)
        frames.push(frame.name)
        syncBack()
        slideIn(view)
        laidOutWidth = container.width
        laidOutHeight = container.height
    }

    private fun showReplacement(frame: Frame, view: View, covered: Frame) {
        endMotion()
        pendingDrop = covered
        stack.add(frame)
        frames.push(frame.name)
        syncBack()
        slideIn(view)
        laidOutWidth = container.width
        laidOutHeight = container.height
    }

    private fun swapFrame(frame: Frame, view: View, removed: Frame) {
        endMotion()
        stack.add(frame)
        frames.push(frame.name)
        syncBack()
        if (!view.isClickable) {
            view.isClickable = true
        }
        place(view, under = false)
        sever(removed)
        laidOutWidth = container.width
        laidOutHeight = container.height
    }

    private fun popNow(rawParams: JSONObject?): Boolean {
        if (released) {
            return false
        }
        Ime.dismiss(insetRoot)
        if (frames.pop() == null) {
            return false
        }
        val frame = stack.removeAt(stack.lastIndex)
        val revealed = stack.last()
        endMotion(keep = revealed)
        PageForm.snapshot(frame.templateContext?.rootView, frame.data)
        val result = evaluateBack(rawParams ?: declaredBackParams(frame), frame.data)
        if (result != null && result.isNotEmpty()) {
            applyResult(revealed, frame, result)
        }
        val keepLive = (result == null || result.isEmpty()) && revealed.templateContext?.rootView != null
        if (!keepLive) {
            sever(revealed)
            if (!materialize(revealed, under = frame.templateContext?.rootView != null)) {
                toastCannotOpen()
            }
        }
        syncBack()
        dismiss(frame)
        laidOutWidth = container.width
        laidOutHeight = container.height
        return true
    }

    private fun popToNow(page: String, rawParams: JSONObject?): Boolean {
        if (released) {
            return false
        }
        Ime.dismiss(insetRoot)
        val removedNames = frames.popTo(page) ?: return false
        if (removedNames.isEmpty()) {
            mergeIntoTop(rawParams)
            return true
        }
        val removed = List(removedNames.size) { stack.removeAt(stack.lastIndex) }
        val revealed = stack.last()
        val visible = removed.first()
        val covering = removed.last()
        endMotion(keep = revealed)
        PageForm.snapshot(visible.templateContext?.rootView, visible.data)
        val result = evaluateBack(rawParams, visible.data)
        if (result != null && result.isNotEmpty()) {
            applyResult(revealed, covering, result)
        }
        val keepLive = (result == null || result.isEmpty()) && revealed.templateContext?.rootView != null
        if (!keepLive) {
            sever(revealed)
            if (!materialize(revealed, under = visible.templateContext?.rootView != null)) {
                toastCannotOpen()
            }
        }
        syncBack()
        for (index in 1 until removed.size) {
            sever(removed[index])
        }
        dismiss(visible)
        laidOutWidth = container.width
        laidOutHeight = container.height
        return true
    }

    private fun mergeIntoTop(rawParams: JSONObject?) {
        val top = stack.last()
        endMotion(keep = top)
        PageForm.snapshot(top.templateContext?.rootView, top.data)
        val result = evaluateBack(rawParams, top.data)
        if (result != null && result.isNotEmpty()) {
            top.data = PageParams.merge(top.data, result)
            sever(top)
            if (!materialize(top, under = false)) {
                toastCannotOpen()
            }
        }
        laidOutWidth = container.width
        laidOutHeight = container.height
    }

    private fun applyResult(revealed: Frame, leaving: Frame, result: JSONObject) {
        val array = leaving.slotKey?.let { revealed.data?.get(it) as? JSONArray }
        val item = if (array != null && leaving.slotIndex in 0 until array.size) {
            array.get(leaving.slotIndex) as? JSONObject
        } else {
            null
        }
        if (item != null) {
            PageParams.mergeInto(item, result)
            return
        }
        revealed.data = PageParams.merge(revealed.data, result)
    }

    private fun evaluateBack(rawParams: JSONObject?, scope: JSONObject?): JSONObject? {
        if (rawParams == null) {
            return null
        }
        return PageParams.evaluate(rawParams) { expression ->
            ExpressionWrapper.instance.getResult(expression, scope)
        }
    }

    private fun declaredBackParams(frame: Frame): JSONObject? {
        val events = frame.templateContext?.events ?: return null
        val found = events.values.mapNotNull { event ->
            if (event.getString("class") != "nav") {
                return@mapNotNull null
            }
            val params = event.getJSONObject("params") ?: return@mapNotNull null
            if (params.getString("fun") != "back") {
                return@mapNotNull null
            }
            params.getJSONObject("params")
        }
        return found.singleOrNull()
    }

    private fun materialize(frame: Frame, under: Boolean): Boolean {
        val existing = frame.templateContext?.rootView
        if (existing != null) {
            if (existing.parent == null) {
                place(existing, under)
            }
            PageForm.restore(existing, frame.data)
            PageForm.restoreScroll(existing, frame.scrolls)
            relayout(frame)
            return true
        }
        var created: TemplateContext? = null
        try {
            val templateContext = OTEngine.instance.buildTemplate(bizId, templateId, frame.templatePath)
            created = templateContext
            frame.data?.let { templateContext.setData(it.toJSONString()) }
            val view = OTEngine.instance.createAndroidView(
                templateContext,
                OTEngine.OTViewPortSize(container.width.toFloat(), container.height.toFloat())
            )
            if (view == null) {
                templateContext.release()
                return false
            }
            frame.templateContext = templateContext
            frame.data = templateContext.data
            PageForm.restore(view, frame.data)
            place(view, under)
            PageForm.restoreScroll(view, frame.scrolls)
            relayout(frame)
            return true
        } catch (_: Exception) {
            if (frame.templateContext === created) {
                frame.templateContext = null
            }
            created?.release()
            return false
        }
    }

    private fun place(view: View, under: Boolean) {
        if (view.parent === stage) {
            return
        }
        if (under && stage.childCount > 0) {
            stage.addView(view, 0, matchParent())
        } else {
            stage.addView(view, matchParent())
        }
    }

    private fun slideIn(view: View) {
        if (!view.isClickable) {
            view.isClickable = true
        }
        holdTouches()
        place(view, under = false)
        val travel = travel()
        if (travel == 0f) {
            severPending()
            releaseTouches()
            return
        }
        view.translationX = travel
        enteringView = view
        val covered = pendingDrop
        val token = ++generation
        view.animate()
            .translationX(0f)
            .setDuration(motionDuration())
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
                defer {
                    if (token != generation || released) {
                        return@defer
                    }
                    if (enteringView === view) {
                        enteringView = null
                    }
                    if (pendingDrop === covered) {
                        severPending()
                    }
                    if (enteringView == null && dismissing == null) {
                        releaseTouches()
                    }
                }
            }
            .start()
    }

    private fun dismiss(frame: Frame) {
        val view = frame.templateContext?.rootView
        val travel = travel()
        if (view == null || travel == 0f) {
            sever(frame)
            releaseTouches()
            return
        }
        holdTouches()
        view.bringToFront()
        dismissing = frame
        leavingView = view
        val token = ++generation
        view.animate()
            .translationX(travel)
            .setDuration(motionDuration())
            .setInterpolator(DecelerateInterpolator())
            .withEndAction {
                defer {
                    if (token != generation || released) {
                        return@defer
                    }
                    if (leavingView === view) {
                        leavingView = null
                    }
                    if (dismissing === frame) {
                        dismissing = null
                        sever(frame)
                    }
                    if (enteringView == null && dismissing == null) {
                        releaseTouches()
                    }
                }
            }
            .start()
    }

    private fun holdTouches() {
        if (touchGuard.parent === stage) {
            touchGuard.bringToFront()
        } else {
            stage.addView(touchGuard, matchParent())
        }
    }

    private fun releaseTouches() {
        if (touchGuard.parent === stage) {
            stage.removeView(touchGuard)
        }
    }

    private fun endMotion(keep: Frame? = null) {
        generation += 1
        enteringView?.animate()?.cancel()
        enteringView?.translationX = 0f
        enteringView = null
        leavingView?.animate()?.cancel()
        leavingView = null
        releaseTouches()
        val drop = pendingDrop
        pendingDrop = null
        if (drop != null && drop !== keep) {
            sever(drop)
        }
        val closing = dismissing
        dismissing = null
        if (closing != null && closing !== keep) {
            sever(closing)
        }
    }

    private fun severPending() {
        val frame = pendingDrop ?: return
        pendingDrop = null
        sever(frame)
    }

    private fun sever(frame: Frame) {
        val data = frame.data
        val context = frame.templateContext ?: return
        context.rootView?.let { child ->
            child.animate().cancel()
            if (child.parent === stage) {
                stage.removeView(child)
            }
        }
        context.release()
        frame.templateContext = null
        frame.data = data
    }

    private fun travel(): Float {
        val width = if (stage.width > 0) stage.width else container.width
        if (width <= 0 || container.height <= 0) {
            return 0f
        }
        val scale = try {
            Settings.Global.getFloat(
                activity.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f
            )
        } catch (_: Exception) {
            1f
        }
        if (scale == 0f) {
            return 0f
        }
        val rtl = stage.layoutDirection == View.LAYOUT_DIRECTION_RTL
        return if (rtl) -width.toFloat() else width.toFloat()
    }

    private fun motionDuration(): Long {
        return activity.resources.getInteger(android.R.integer.config_shortAnimTime).toLong()
    }

    private fun relayout(frame: Frame) {
        val context = frame.templateContext ?: return
        OTEngine.instance.relayout(
            context,
            OTEngine.OTViewPortSize(container.width.toFloat(), container.height.toFloat())
        )
    }

    private fun syncBack() {
        backCallback?.isEnabled = !released && active[activity] === this && frames.depth > 1
    }

    private fun defer(action: () -> Unit) {
        if (released) {
            return
        }
        deferred.add(action)
        if (scheduled) {
            return
        }
        scheduled = true
        container.post {
            scheduled = false
            if (released) {
                deferred.clear()
                return@post
            }
            val jobs = deferred.toList()
            deferred.clear()
            jobs.forEach { it() }
        }
    }

    private fun exportState(): String? {
        if (released || stack.isEmpty()) {
            return null
        }
        val root = JSONObject()
        root["route"] = routePath
        root["bizId"] = bizId
        root["templateId"] = templateId
        val pages = JSONArray()
        for (frame in stack) {
            PageForm.snapshot(frame.templateContext?.rootView, frame.data)
            PageForm.captureScroll(frame.templateContext?.rootView, frame.scrolls)
            val page = JSONObject()
            page["name"] = frame.name
            page["data"] = frame.data?.toJSONString()
            if (frame.slotKey != null) {
                page["slotKey"] = frame.slotKey
                page["slotIndex"] = frame.slotIndex
            }
            if (frame.scrolls.isNotEmpty()) {
                val scrolls = JSONObject()
                for ((key, scroll) in frame.scrolls) {
                    val one = JSONObject()
                    one["position"] = scroll.position
                    one["offset"] = scroll.offset
                    scrolls[key] = one
                }
                page["scrolls"] = scrolls
            }
            pages.add(page)
        }
        root["pages"] = pages
        val text = root.toJSONString()
        if (text.length > MAX_STATE_CHARS) {
            return null
        }
        return text
    }

    private fun readRestored(bundle: Bundle?) {
        val text = bundle?.getString(STATE_JSON) ?: return
        val root = try {
            JSON.parseObject(text)
        } catch (_: Exception) {
            return
        }
        if (root.getString("route") != routePath ||
            root.getString("bizId") != bizId ||
            root.getString("templateId") != templateId
        ) {
            return
        }
        val pages = root.getJSONArray("pages") ?: return
        if (pages.isEmpty()) {
            return
        }
        val parsed = mutableListOf<SavedPage>()
        for (item in pages) {
            val page = item as? JSONObject ?: return
            val name = page.getString("name") ?: return
            if (routes.pages[name] == null) {
                return
            }
            val scrolls = linkedMapOf<String, ListScroll>()
            val scrollJson = page.getJSONObject("scrolls")
            if (scrollJson != null) {
                for (key in scrollJson.keys) {
                    val one = scrollJson.getJSONObject(key) ?: continue
                    scrolls[key] = ListScroll(one.getIntValue("position"), one.getIntValue("offset"))
                }
            }
            val slotKey = page.getString("slotKey")
            val slotIndex = if (page.containsKey("slotIndex")) page.getIntValue("slotIndex") else -1
            parsed.add(
                SavedPage(
                    name = name,
                    data = page.getString("data"),
                    slotKey = slotKey,
                    slotIndex = slotIndex,
                    scrolls = scrolls
                )
            )
        }
        restored = parsed
    }

    private fun toastCannotOpen() {
        Toast.makeText(activity, "这个页面还打不开", Toast.LENGTH_SHORT).show()
    }

    private fun matchParent(): ViewGroup.LayoutParams {
        return ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        )
    }

    private class Entry(
        val route: PageRoute,
        val current: Frame?,
        val overlay: JSONObject?
    )

    private class Shown(val frame: Frame, val view: View)

    private class Frame(
        val name: String,
        val templatePath: String,
        var data: JSONObject?,
        var templateContext: TemplateContext?,
        val slotKey: String?,
        val slotIndex: Int
    ) {
        val scrolls = linkedMapOf<String, ListScroll>()

        constructor(
            name: String,
            templatePath: String,
            data: JSONObject?,
            templateContext: TemplateContext?
        ) : this(name, templatePath, data, templateContext, null, -1)
    }

    private class SavedPage(
        val name: String,
        val data: String?,
        val slotKey: String?,
        val slotIndex: Int,
        val scrolls: Map<String, ListScroll>
    )

    companion object {
        private const val STATE_KEY = "com.dynamic.otter.nav.PageStack"
        private const val STATE_JSON = "json"
        private const val MAX_STATE_CHARS = 200_000
        private val groups = mutableMapOf<Activity, MutableList<PageStack>>()
        private val active = mutableMapOf<Activity, PageStack>()

        fun attach(
            activity: Activity,
            insetRoot: View,
            container: ViewGroup,
            routePath: String,
            bizId: String,
            templateId: String
        ): PageStack {
            val json = AssetsUtils.parseAssetsToString(activity, routePath)
            val routes = PageRouteParser.parse(json)
            OTEngine.instance.init(activity)
            Ime.install(activity)
            val list = groups.getOrPut(activity) { mutableListOf() }
            val stack = PageStack(activity, insetRoot, container, routes, routePath, bizId, templateId)
            val manageInsets = list.none { it.ownsInsets }
            list.add(stack)
            if (active[activity] == null) {
                active[activity] = stack
            }
            stack.install(manageInsets)
            return stack
        }

        fun find(context: Context): PageStack? {
            val activity = context.findActivity() ?: return null
            return active[activity]
        }

        private fun Context.findActivity(): Activity? {
            var current = this
            while (current is ContextWrapper) {
                if (current is Activity) {
                    return current
                }
                current = current.baseContext
            }
            return null
        }
    }
}
