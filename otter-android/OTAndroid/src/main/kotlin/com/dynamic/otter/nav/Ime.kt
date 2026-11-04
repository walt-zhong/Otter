package com.dynamic.otter.nav

import android.app.Activity
import android.content.ContextWrapper
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.Window
import android.view.inputmethod.InputMethodManager
import android.widget.EditText
import androidx.appcompat.view.WindowCallbackWrapper
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import kotlin.math.roundToInt

/**
 * 键盘只跟着输入框焦点走。
 * 显示用 [show]；消失用 [dismiss]，先丢掉焦点再收起，避免输入框还聚焦时系统把键盘立刻弹回来。
 */
object Ime {
    fun install(activity: Activity) {
        val window = activity.window ?: return
        val current = window.callback ?: return
        if (current is OutsideTap) {
            return
        }
        window.callback = OutsideTap(activity, current)
    }

    fun show(input: View) {
        if (!input.isFocused) {
            input.requestFocus()
        }
        val controller = controller(input)
        if (controller != null) {
            controller.show(WindowInsetsCompat.Type.ime())
            return
        }
        val manager = input.context.getSystemService(InputMethodManager::class.java)
        manager?.showSoftInput(input, InputMethodManager.SHOW_IMPLICIT)
    }

    fun dismiss(anchor: View) {
        val focused = anchor.rootView.findFocus()
        if (focused is EditText) {
            focused.clearFocus()
        }
        val controller = controller(anchor)
        if (controller != null) {
            controller.hide(WindowInsetsCompat.Type.ime())
            return
        }
        val manager = anchor.context.getSystemService(InputMethodManager::class.java)
        manager?.hideSoftInputFromWindow(anchor.windowToken, 0)
    }

    private fun controller(anchor: View): WindowInsetsControllerCompat? {
        var current = anchor.context
        while (current is ContextWrapper) {
            if (current is Activity) {
                return WindowCompat.getInsetsController(current.window, anchor)
            }
            current = current.baseContext
        }
        return null
    }

    private fun dismissIfOutside(activity: Activity, event: MotionEvent) {
        if (activity.currentFocus !is EditText) {
            return
        }
        val x = event.rawX.roundToInt()
        val y = event.rawY.roundToInt()
        if (activity.window.decorView.findEditor(x, y) != null) {
            return
        }
        dismiss(activity.window.decorView)
    }

    private fun View.findEditor(x: Int, y: Int): EditText? {
        if (visibility != View.VISIBLE || !isShown) {
            return null
        }
        if (this is ViewGroup) {
            for (index in childCount - 1 downTo 0) {
                val found = getChildAt(index).findEditor(x, y)
                if (found != null) {
                    return found
                }
            }
        }
        if (this !is EditText) {
            return null
        }
        val location = IntArray(2)
        getLocationOnScreen(location)
        val contains = x >= location[0] && x < location[0] + width &&
            y >= location[1] && y < location[1] + height
        return if (contains) this else null
    }

    private class OutsideTap(
        private val activity: Activity,
        delegate: Window.Callback
    ) : WindowCallbackWrapper(delegate) {
        override fun dispatchTouchEvent(event: MotionEvent): Boolean {
            val handled = super.dispatchTouchEvent(event)
            // 抬手再收。按下就收会改 inset，页面跟着挪，这次点击会点空。
            if (event.actionMasked == MotionEvent.ACTION_UP) {
                dismissIfOutside(activity, event)
            }
            return handled
        }
    }
}
