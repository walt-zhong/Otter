package com.dynamic.otter.render.view.components.tabpager

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Bundle
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView
import androidx.fragment.app.Fragment

/**
 * A simple [Fragment] subclass.
 * Use the [FragmentTab.newInstance] factory method to
 * create an instance of this fragment.
 */

class FragmentTab : Fragment() {
    // TODO: Rename and change types of parameters
    private var param1: String? = null
    private var param2: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        arguments?.let {
            param1 = it.getString(ARG_PARAM1)
            param2 = it.getString(ARG_PARAM2)
        }
    }

    @SuppressLint("MissingInflatedId")
    override fun onCreateView(
        inflater: LayoutInflater, container: ViewGroup?,
        savedInstanceState: Bundle?
    ): View? {
        // Inflate the layout for this fragment
       val rootView =  FrameLayout(requireContext())
        //        LogUtils.log("onCreateView");
        val textView = TextView(requireContext())
        textView.setTextColor(Color.RED)
        textView.setTextSize(30f)
        textView.text = param2
        rootView.addView(textView)
        return rootView
    }

    companion object {
        /**
         * Use this factory method to create a new instance of
         * this fragment using the provided parameters.
         *
         * @param param1 Parameter 1.
         * @param param2 Parameter 2.
         * @return A new instance of fragment FragmentTab.
         */

        private const val ARG_PARAM1 = "param1"
        private const val ARG_PARAM2 = "param2"
        // TODO: Rename and change types and number of parameters
        @JvmStatic
        fun newInstance(param1: String, param2: String) =
            FragmentTab().apply {
                arguments = Bundle().apply {
                    putString(ARG_PARAM1, param1)
                    putString(ARG_PARAM2, param2)
                }
            }
    }
}