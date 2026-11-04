package com.dynamic.otter.demo

import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.ViewGroup
import com.dynamic.otter.ExpansionCenter
import com.dynamic.otter.render.view.basic.Image
import com.dynamic.otter.render.view.basic.OTList
import com.dynamic.otter.render.view.basic.Playable
import com.dynamic.otter.render.view.basic.ProgressView
import com.dynamic.otter.render.view.basic.Text
import com.dynamic.otter.render.view.basic.adapter.OTListAdapter

class PlayerSession private constructor(
    private val playState: Text,
    private val cover: Image,
    private val title: Text,
    private val artist: Text,
    private val elapsed: Text,
    private val duration: Text,
    private val seek: ProgressView,
    private val playToggle: Image,
    private val meter: Playable,
    private val queue: OTList,
    private val adapter: OTListAdapter
) {
    private val handler = Handler(Looper.getMainLooper())
    private var index = 0
    private var playing = true
    private var scrubbing = false
    private var positionMs = 0L

    private val ticker = object : Runnable {
        override fun run() {
            if (playing && !scrubbing) {
                positionMs += TICK_MS
                val length = durationMs()
                if (positionMs >= length) {
                    show((index + 1) % adapter.itemCount, resetPosition = true)
                } else {
                    renderClock()
                }
            }
            handler.postDelayed(this, TICK_MS)
        }
    }

    private val itemClick = ExpansionCenter.ItemClick { item ->
        val found = indexOf(item)
        if (found >= 0) {
            show(found, resetPosition = true)
        }
    }

    fun release() {
        handler.removeCallbacks(ticker)
        if (ExpansionCenter.instance.itemClick === itemClick) {
            ExpansionCenter.instance.itemClick = null
        }
        seek.onSeekChanged = null
    }

    private fun start() {
        positionMs = (0.36f * durationMs()).toLong()
        seek.seekable = true
        seek.onSeekChanged = { fraction, settled ->
            scrubbing = !settled
            positionMs = (fraction * durationMs()).toLong()
            elapsed.onBindData(format(positionMs))
        }
        playToggle.setOnClickListener { toggle() }
        ExpansionCenter.instance.itemClick = itemClick
        renderClock()
        handler.postDelayed(ticker, TICK_MS)
    }

    private fun toggle() {
        playing = !playing
        renderTransport()
    }

    private fun show(rawIndex: Int, resetPosition: Boolean) {
        val count = adapter.itemCount
        if (count == 0) {
            return
        }
        val next = ((rawIndex % count) + count) % count
        val previous = index
        index = next
        if (resetPosition) {
            positionMs = 0
            playing = true
        }
        cover.onBindData(adapter.itemField(index, "cover"))
        title.onBindData(adapter.itemField(index, "title"))
        artist.onBindData(adapter.itemField(index, "artist"))
        duration.onBindData(adapter.itemField(index, "length"))
        renderTransport()
        renderClock()
        if (previous != index) {
            adapter.updateItem(previous, idleFields())
            adapter.updateItem(index, playingFields())
            queue.smoothScrollToPosition(index)
        }
    }

    private fun renderTransport() {
        playToggle.onBindData(if (playing) "res:ic_player_pause" else "res:ic_player_play")
        playState.onBindData(if (playing) "正在播放" else "已暂停")
        meter.setPlaying(playing)
    }

    private fun renderClock() {
        val length = durationMs()
        if (positionMs > length) {
            positionMs = length
        }
        elapsed.onBindData(format(positionMs))
        seek.setFraction(positionMs.toFloat() / length)
    }

    private fun durationMs(): Long {
        val parts = adapter.itemField(index, "length").split(":")
        val minutes = parts.getOrNull(0)?.toLongOrNull() ?: 0L
        val seconds = parts.getOrNull(1)?.toLongOrNull() ?: 0L
        return ((minutes * 60 + seconds) * 1000L).coerceAtLeast(1000L)
    }

    private fun indexOf(item: Map<String, String>): Int {
        for (i in 0 until adapter.itemCount) {
            if (adapter.itemField(i, "title") == item["title"] &&
                adapter.itemField(i, "artist") == item["artist"] &&
                adapter.itemField(i, "length") == item["length"]
            ) {
                return i
            }
        }
        return -1
    }

    companion object {
        private const val TICK_MS = 500L

        fun attach(root: View): PlayerSession? {
            val queue = root.findTagged("queue") as? OTList ?: return null
            val adapter = queue.adapter as? OTListAdapter ?: return null
            val session = PlayerSession(
                playState = root.findTagged("playState") as? Text ?: return null,
                cover = root.findTagged("cover") as? Image ?: return null,
                title = root.findTagged("trackTitle") as? Text ?: return null,
                artist = root.findTagged("trackArtist") as? Text ?: return null,
                elapsed = root.findTagged("elapsed") as? Text ?: return null,
                duration = root.findTagged("duration") as? Text ?: return null,
                seek = root.findTagged("seek") as? ProgressView ?: return null,
                playToggle = root.findTagged("playToggle") as? Image ?: return null,
                meter = root.findTagged("meter") as? Playable ?: return null,
                queue = queue,
                adapter = adapter
            )
            val prev = root.findTagged("playPrev")
            val next = root.findTagged("playNext")
            prev?.setOnClickListener { session.show(session.index - 1, resetPosition = true) }
            next?.setOnClickListener { session.show(session.index + 1, resetPosition = true) }
            session.start()
            return session
        }

        private fun playingFields() = mapOf(
            "titleColor" to "#F2C14E",
            "rowBg" to "#3A2A22",
            "mark" to "正在听"
        )

        private fun idleFields() = mapOf(
            "titleColor" to "#F6F1EA",
            "rowBg" to "#241F1C",
            "mark" to ""
        )
    }
}

private fun View.findTagged(name: String): View? {
    if (tag == name) {
        return this
    }
    if (this is ViewGroup) {
        for (index in 0 until childCount) {
            getChildAt(index).findTagged(name)?.let { return it }
        }
    }
    return null
}

private fun format(positionMs: Long): String {
    val totalSeconds = (positionMs / 1000L).toInt()
    return "%d:%02d".format(totalSeconds / 60, totalSeconds % 60)
}
