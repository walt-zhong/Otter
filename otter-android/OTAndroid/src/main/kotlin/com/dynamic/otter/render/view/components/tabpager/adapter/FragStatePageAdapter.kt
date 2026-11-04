package com.dynamic.otter.render.view.components.tabpager.adapter

import android.annotation.SuppressLint
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.Parcelable
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.collection.ArraySet
import androidx.collection.LongSparseArray
import androidx.core.util.Preconditions
import androidx.core.view.ViewCompat
import androidx.fragment.app.Fragment
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentManager
import androidx.fragment.app.FragmentTransaction
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.LifecycleOwner
import androidx.recyclerview.widget.RecyclerView
import androidx.recyclerview.widget.RecyclerView.AdapterDataObserver
import androidx.viewpager2.adapter.StatefulAdapter
import androidx.viewpager2.widget.ViewPager2
import com.dynamic.otter.render.view.components.tabpager.holder.MyFragmentViewHolder

abstract class FragStatePageAdapter
    : RecyclerView.Adapter<MyFragmentViewHolder>, StatefulAdapter {
    companion object {
        private const val KEY_PREFIX_FRAGMENT = "f#"
        private const val KEY_PREFIX_STATE = "s#"
        private const val GRACE_WINDOW_TIME_MS = 10_000

        private fun createKey(prefix: String, id: Long): String {
            return prefix + id
        }
    }

    private var mLifecycle: Lifecycle? = null
    private var mFragmentManager: FragmentManager? = null

    private val mFragments: LongSparseArray<Fragment> = LongSparseArray()
    private val mSavedStates: LongSparseArray<Fragment.SavedState> = LongSparseArray()
    private val mItemIdToViewHolder: LongSparseArray<Int> = LongSparseArray(0)

    private var mFragmentMaxLifecycleEnforcer: FragmentMaxLifecycleEnforcer? = null

    private var mIsInGracePeriod = false
    private var mHasStaleFragments: Boolean = false

    constructor(fragmentActivity: FragmentActivity)
            : this(
        fragmentActivity.supportFragmentManager,
        fragmentActivity.lifecycle
    )

    constructor(fragment: Fragment)
            : this(
        fragment.childFragmentManager,
        fragment.lifecycle
    )

    constructor(fragmentManager: FragmentManager, lifecycle: Lifecycle) {
        mFragmentManager = fragmentManager
        mLifecycle = lifecycle
        super.setHasStableIds(true)
    }

    @SuppressLint("RestrictedApi")
    override fun onAttachedToRecyclerView(recyclerView: RecyclerView) {
        Preconditions.checkArgument(mFragmentMaxLifecycleEnforcer == null)
        mFragmentMaxLifecycleEnforcer = FragmentMaxLifecycleEnforcer()
        mFragmentMaxLifecycleEnforcer!!.register(recyclerView)
    }

    override fun onDetachedFromRecyclerView(recyclerView: RecyclerView) {
        mFragmentMaxLifecycleEnforcer?.unregister(recyclerView)
        mFragmentMaxLifecycleEnforcer = null
    }


    fun shouldDelayFragmentTransactions(): Boolean {
        return mFragmentManager!!.isStateSaved
    }


    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): MyFragmentViewHolder {
        return MyFragmentViewHolder.create(parent)
    }

    override fun onBindViewHolder(holder: MyFragmentViewHolder, position: Int) {
        val itemId = holder.itemId
        val viewHolderId = holder.getContainer().id
        val boundItemId = itemForViewHolder(viewHolderId)
        if (boundItemId != null && boundItemId != itemId) {
            removeFragment(boundItemId)
            mItemIdToViewHolder.remove(boundItemId)
        }

        mItemIdToViewHolder.put(itemId, viewHolderId)
        ensureFragment(position)

        val container = holder.getContainer()
        if (container.isAttachedToWindow) {
            if (container.parent != null) {
                throw IllegalStateException("Design assumption violated")
            }

            container.addOnLayoutChangeListener(object : View.OnLayoutChangeListener {
                override fun onLayoutChange(
                    v: View?,
                    left: Int,
                    top: Int,
                    right: Int,
                    bottom: Int,
                    oldLeft: Int,
                    oldTop: Int,
                    oldRight: Int,
                    oldBottom: Int
                ) {
                    if (container.parent != null) {
                        container.removeOnLayoutChangeListener(this)
                        placeFragmentInViewHolder(holder)
                    }
                }
            })
        }
    }


    /**
     * @param holder that has been bound to a Fragment in the [.onBindViewHolder] stage.
     */
    fun placeFragmentInViewHolder(holder: MyFragmentViewHolder) {
        val fragment = mFragments[holder.getItemId()]
            ?: throw java.lang.IllegalStateException("Design assumption violated.")
        val container: FrameLayout = holder.getContainer()
        val view = fragment.view


        // { f:notAdded, v:created, v:attached } -> illegal state
        // { f:notAdded, v:created, v:notAttached } -> illegal state
        check(!(!fragment.isAdded && view != null)) { "Design assumption violated." }

        // { f:added, v:notCreated, v:notAttached} -> schedule callback for when created
        if (fragment.isAdded && view == null) {
            scheduleViewAttach(fragment, container)
            return
        }

        // { f:added, v:created, v:attached } -> check if attached to the right container
        if (fragment.isAdded && view!!.parent != null) {
            if (view!!.parent !== container) {
                addViewToContainer(view, container)
            }
            return
        }

        // { f:added, v:created, v:notAttached} -> attach view to container
        if (fragment.isAdded) {
            if (view != null) {
                addViewToContainer(view, container)
            }
            return
        }

        // { f:notAdded, v:notCreated, v:notAttached } -> add, create, attach
        if (!shouldDelayFragmentTransactions()) {
            scheduleViewAttach(fragment, container)
            mFragmentManager!!.beginTransaction()
                .add(fragment, "f" + holder.getItemId())
                .setMaxLifecycle(fragment, Lifecycle.State.STARTED)
                .commitNow()
            mFragmentMaxLifecycleEnforcer!!.updateFragmentMaxLifecycle(false)
        } else {
            if (mFragmentManager!!.isDestroyed) {
                return  // nothing we can do
            }
            mLifecycle!!.addObserver(object : LifecycleEventObserver {
                override fun onStateChanged(
                    source: LifecycleOwner,
                    event: Lifecycle.Event
                ) {
                    if (shouldDelayFragmentTransactions()) {
                        return
                    }
                    source.lifecycle.removeObserver(this)
                    if (ViewCompat.isAttachedToWindow(holder.getContainer())) {
                        placeFragmentInViewHolder(holder)
                    }
                }
            })
        }
    }

    fun gcFragments() {
        if (!mHasStaleFragments || shouldDelayFragmentTransactions()) {
            return
        }

        // Remove Fragments for items that are no longer part of the data-set
        val toRemove: MutableSet<Long> = ArraySet()
        for (ix in 0 until mFragments.size()) {
            val itemId = mFragments.keyAt(ix)
            if (!containsItem(itemId)) {
                toRemove.add(itemId)
                mItemIdToViewHolder.remove(itemId) // in case they're still bound
            }
        }

        // Remove Fragments that are not bound anywhere -- pending a grace period
        if (!mIsInGracePeriod) {
            mHasStaleFragments = false // we've executed all GC checks

            for (ix in 0 until mFragments.size()) {
                val itemId = mFragments.keyAt(ix)
                if (!isFragmentViewBound(itemId)) {
                    toRemove.add(itemId)
                }
            }
        }

        for (itemId in toRemove) {
            removeFragment(itemId)
        }
    }

    private fun isFragmentViewBound(itemId: Long): Boolean {
        if (mItemIdToViewHolder.containsKey(itemId)) {
            return true
        }

        val fragment = mFragments[itemId] ?: return false

        val view = fragment.view ?: return false

        return view.parent != null
    }

    private fun scheduleViewAttach(fragment: Fragment, container: FrameLayout) {
        // After a config change, Fragments that were in FragmentManager will be recreated. Since
        // ViewHolder container ids are dynamically generated, we opted to manually handle
        // attaching Fragment views to containers. For consistency, we use the same mechanism for
        // all Fragment views.
        mFragmentManager!!.registerFragmentLifecycleCallbacks(
            object : FragmentManager.FragmentLifecycleCallbacks() {
                // TODO(b/141956012): Suppressed during upgrade to AGP 3.6.
                override fun onFragmentViewCreated(
                    fm: FragmentManager,
                    f: Fragment, v: View,
                    savedInstanceState: Bundle?
                ) {
                    if (f === fragment) {
                        fm.unregisterFragmentLifecycleCallbacks(this)
                        addViewToContainer(v, container)
                    }
                }
            }, false
        )
    }

    fun addViewToContainer(v: View, container: FrameLayout) {
        check(container.childCount <= 1) { "Design assumption violated." }

        if (v.parent === container) {
            return
        }

        if (container.childCount > 0) {
            container.removeAllViews()
        }

        if (v.parent != null) {
            (v.parent as ViewGroup).removeView(v)
        }

        container.addView(v)
    }

    private fun itemForViewHolder(viewHolderId: Int): Long? {
        var boundItemId: Long? = null
        for (ix in 0 until mItemIdToViewHolder.size()) {
            if (mItemIdToViewHolder.valueAt(ix) == viewHolderId) {
                check(boundItemId == null) {
                    ("Design assumption violated: "
                            + "a ViewHolder can only be bound to one item at a time.")
                }
                boundItemId = mItemIdToViewHolder.keyAt(ix)
            }
        }
        return boundItemId
    }

    private fun removeFragment(itemId: Long) {
        val fragment = mFragments[itemId] ?: return

        if (fragment.view != null) {
            val viewParent = fragment.requireView().parent
            if (viewParent != null) {
                (viewParent as FrameLayout).removeAllViews()
            }
        }

        if (!containsItem(itemId)) {
            mSavedStates.remove(itemId)
        }

        if (!fragment.isAdded) {
            mFragments.remove(itemId)
            return
        }

        if (shouldDelayFragmentTransactions()) {
            mHasStaleFragments = true
            return
        }

        if (fragment.isAdded && containsItem(itemId)) {
            mSavedStates.put(itemId, mFragmentManager!!.saveFragmentInstanceState(fragment))
        }
        mFragmentManager!!.beginTransaction().remove(fragment).commitNow()
        mFragments.remove(itemId)
    }

    fun containsItem(itemId: Long): Boolean {
        return itemId >= 0 && itemId < itemCount
    }

    abstract fun createFragment(position: Int): Fragment

    private fun ensureFragment(position: Int) {
        val itemId = getItemId(position)
        //        if (!mFragments.containsKey(itemId)) {
        // TODO(133419201): check if a Fragment provided here is a new Fragment
        val newFragment: Fragment = createFragment(position)
        newFragment.setInitialSavedState(mSavedStates[itemId])
        mFragments.put(itemId, newFragment)
//        }
    }

    override fun onViewAttachedToWindow(holder: MyFragmentViewHolder) {
        super.onViewAttachedToWindow(holder)
        placeFragmentInViewHolder(holder)
        gcFragments()
    }

    override fun getItemId(position: Int): Long {
        return position.toLong()
    }

    override fun setHasStableIds(hasStableIds: Boolean) {
        throw UnsupportedOperationException(
            "Stable Ids are required for the adapter to function properly, and the adapter "
                    + "takes care of setting the flag."
        )
    }

    override fun saveState(): Parcelable {
        /** TODO(b/122670461): use custom [Parcelable] instead of Bundle to save space  */
        val savedState = Bundle(mFragments.size() + mSavedStates.size())

        /** save references to active fragments  */
        for (ix in 0 until mFragments.size()) {
            val itemId = mFragments.keyAt(ix)
            val fragment = mFragments[itemId]
            if (fragment != null && fragment.isAdded) {
                val key: String = createKey(
                    KEY_PREFIX_FRAGMENT,
                    itemId
                )
                mFragmentManager!!.putFragment(savedState, key, fragment)
            }
        }

        /** Write [) into a ][mSavedStates] */
        for (ix in 0 until mSavedStates.size()) {
            val itemId = mSavedStates.keyAt(ix)
            if (containsItem(itemId)) {
                val key: String = createKey(
                    KEY_PREFIX_STATE,
                    itemId
                )
                savedState.putParcelable(key, mSavedStates[itemId])
            }
        }

        return savedState
    }

    override fun restoreState(savedState: Parcelable) {
        check(!(!mSavedStates.isEmpty || !mFragments.isEmpty)) { "Expected the adapter to be 'fresh' while restoring state." }

        val bundle = savedState as Bundle
        if (bundle.classLoader == null) {
            /** TODO(b/133752041): pass the class loader from [ViewPager2.SavedState]  */
            bundle.classLoader = javaClass.classLoader
        }

        for (key in bundle.keySet()) {
            if (isValidKey(
                    key,
                    KEY_PREFIX_FRAGMENT
                )
            ) {
                val itemId: Long =
                    parseIdFromKey(
                        key,
                       KEY_PREFIX_FRAGMENT
                    )
                val fragment = mFragmentManager!!.getFragment(bundle, key)
                mFragments.put(itemId, fragment)
                continue
            }

            if (isValidKey(
                    key,
                    KEY_PREFIX_STATE
                )
            ) {
                val itemId: Long =
                    parseIdFromKey(
                        key,
                        KEY_PREFIX_STATE
                    )
                val state = bundle.getParcelable<Fragment.SavedState>(key)
                if (containsItem(itemId)) {
                    mSavedStates.put(itemId, state)
                }
                continue
            }

            throw IllegalArgumentException("Unexpected key in savedState: $key")
        }

        if (!mFragments.isEmpty) {
            mHasStaleFragments = true
            mIsInGracePeriod = true
            gcFragments()
            scheduleGracePeriodEnd()
        }
    }

    private fun scheduleGracePeriodEnd() {
        val handler = Handler(Looper.getMainLooper())
        val runnable = Runnable {
            mIsInGracePeriod = false
            gcFragments() // good opportunity to GC
        }

        mLifecycle!!.addObserver(object : LifecycleEventObserver {
            override fun onStateChanged(
                source: LifecycleOwner,
                event: Lifecycle.Event
            ) {
                if (event == Lifecycle.Event.ON_DESTROY) {
                    handler.removeCallbacks(runnable)
                    source.lifecycle.removeObserver(this)
                }
            }
        })

        handler.postDelayed(
            runnable,
            GRACE_WINDOW_TIME_MS.toLong()
        )
    }

    // Helper function for dealing with save / restore state
    private fun isValidKey(key: String, prefix: String): Boolean {
        return key.startsWith(prefix) && key.length > prefix.length
    }

    // Helper function for dealing with save / restore state
    private fun parseIdFromKey(key: String, prefix: String): Long {
        return key.substring(prefix.length).toLong()
    }


    override fun onViewRecycled(holder: MyFragmentViewHolder) {
        super.onViewRecycled(holder)
        val viewHolderId = holder.getContainer().id
        val boundItemId = itemForViewHolder(viewHolderId) // item currently bound to the VH
        if (boundItemId != null) {
            removeFragment(boundItemId)
            mItemIdToViewHolder.remove(boundItemId)
        }
    }

    override fun onFailedToRecycleView(holder: MyFragmentViewHolder): Boolean {
        return true
    }

    inner class FragmentMaxLifecycleEnforcer {
        private var mPageChangeCallback: ViewPager2.OnPageChangeCallback? = null
        private var mDataObserver: RecyclerView.AdapterDataObserver? = null
        private var mLifecycleObserver: LifecycleEventObserver? = null
        private var mViewPager: ViewPager2? = null
        private var mPrimaryItemId = RecyclerView.NO_ID

        fun register(recyclerView: RecyclerView) {
            mViewPager = inferViewPager(recyclerView)

            mPageChangeCallback = object : ViewPager2.OnPageChangeCallback() {
                override fun onPageScrollStateChanged(state: Int) {
                    updateFragmentMaxLifecycle(false)
                }

                override fun onPageSelected(position: Int) {
                    updateFragmentMaxLifecycle(false)
                }
            }

            mViewPager!!.registerOnPageChangeCallback(mPageChangeCallback as ViewPager2.OnPageChangeCallback)

            mDataObserver = object : FragStatePageAdapter.DataSetChangeObserver() {
                override fun onChanged() {
                    updateFragmentMaxLifecycle(true)
                }
            }

            registerAdapterDataObserver(mDataObserver as DataSetChangeObserver)


            // signal 3 of 3: we may have to catch-up after being in a lifecycle state that
            // prevented us to perform transactions
            mLifecycleObserver =
                LifecycleEventObserver { _, _ -> updateFragmentMaxLifecycle(false) }
            mLifecycle!!.addObserver(mLifecycleObserver!!)
        }

        fun unregister(recyclerView: RecyclerView) {
            val viewPager = inferViewPager(recyclerView)
            viewPager.unregisterOnPageChangeCallback(mPageChangeCallback!!)
            unregisterAdapterDataObserver(mDataObserver!!)
            mLifecycle!!.removeObserver(mLifecycleObserver!!)
            mViewPager = null
        }

        private fun inferViewPager(recyclerView: RecyclerView): ViewPager2 {
            val parent = recyclerView.parent
            if (parent is ViewPager2) {
                return parent
            }
            throw IllegalStateException("Expected ViewPager2 instance. Got: $parent")
        }

        fun updateFragmentMaxLifecycle(dataSetChanged: Boolean) {
            if (shouldDelayFragmentTransactions()) {
                return
                /** recovery step via [.mLifecycleObserver]  */
            }

            if (mViewPager!!.scrollState != ViewPager2.SCROLL_STATE_IDLE) {
                return  // do not update while not idle to avoid jitter
            }

            if (mFragments.isEmpty() || getItemCount() == 0) {
                return  // nothing to do
            }

            val currentItem = mViewPager!!.currentItem
            if (currentItem >= getItemCount()) {
                /** current item is yet to be updated; it is guaranteed to change, so we will be
                 * notified via [ViewPager2.OnPageChangeCallback.onPageSelected]   */
                return
            }

            val currentItemId: Long = getItemId(currentItem)
            if (currentItemId == mPrimaryItemId && !dataSetChanged) {
                return  // nothing to do
            }

            val currentItemFragment: Fragment? = mFragments.get(currentItemId)
            if (currentItemFragment == null || !currentItemFragment.isAdded) {
                return
            }

            mPrimaryItemId = currentItemId
            val transaction: FragmentTransaction = mFragmentManager?.beginTransaction()!!

            var toResume: Fragment? = null
            for (ix in 0 until mFragments.size()) {
                val itemId: Long = mFragments.keyAt(ix)
                val fragment: Fragment = mFragments.valueAt(ix)

                if (!fragment.isAdded) {
                    continue
                }

                if (itemId != mPrimaryItemId) {
                    transaction.setMaxLifecycle(fragment, Lifecycle.State.STARTED)
                } else {
                    toResume = fragment // itemId map key, so only one can match the predicate
                }

                fragment.setMenuVisibility(itemId == mPrimaryItemId)
            }
            if (toResume != null) { // in case the Fragment wasn't added yet
                transaction.setMaxLifecycle(toResume, Lifecycle.State.RESUMED)
            }

            if (!transaction.isEmpty) {
                transaction.commitNow()
            }
        }
    }

    /**
     * Simplified [RecyclerView.AdapterDataObserver] for clients interested in any data-set
     * changes regardless of their nature.
     */

    abstract class DataSetChangeObserver : AdapterDataObserver() {
        abstract override fun onChanged()

        override fun onItemRangeChanged(positionStart: Int, itemCount: Int) {
            onChanged()
        }

        override fun onItemRangeChanged(
            positionStart: Int, itemCount: Int,
            payload: Any?
        ) {
            onChanged()
        }

        override fun onItemRangeInserted(positionStart: Int, itemCount: Int) {
            onChanged()
        }

        override fun onItemRangeRemoved(positionStart: Int, itemCount: Int) {
            onChanged()
        }

        override fun onItemRangeMoved(fromPosition: Int, toPosition: Int, itemCount: Int) {
            onChanged()
        }
    }
}