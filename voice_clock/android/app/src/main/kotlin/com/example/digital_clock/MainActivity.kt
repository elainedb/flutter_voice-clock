package com.example.digital_clock

import ai.picovoice.porcupinemanager.KeywordCallback
import ai.picovoice.porcupinemanager.PorcupineManager
import ai.picovoice.porcupinemanager.PorcupineManagerException
import android.Manifest
import android.app.assist.AssistContent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.util.Log
import android.widget.*
import androidx.core.app.ActivityCompat
import io.flutter.app.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONObject
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.IOException
import java.lang.Exception

class MainActivity: FlutterActivity() {

    private var porcupineManager: PorcupineManager? = null
    private lateinit var hotwordChannel: MethodChannel
    private lateinit var configChannel: MethodChannel
    private val HOTWORD_CHANNEL = "dev.elainedb.voice_clock/hotword"
    private val STT_CHANNEL = "dev.elainedb.voice_clock/stt"
    private val CONFIG_CHANNEL = "dev.elainedb.voice_clock/config"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Flutter
        GeneratedPluginRegistrant.registerWith(this)
        hotwordChannel = MethodChannel(flutterView, HOTWORD_CHANNEL)
        configChannel = MethodChannel(flutterView, CONFIG_CHANNEL)
        MethodChannel(flutterView, STT_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "final") {
                process()
            }
        }

        // Porcupine
        try {
            copyPorcupineResourceFiles()
        } catch (e: IOException) {
            Toast.makeText(this, "Failed to copy resource files", Toast.LENGTH_SHORT).show()
        }
        process()

        // Deeplink / App Actions
        // adb -s FA69V0308233 shell am start -a android.intent.action.VIEW
        // -d "https://assistant.google.com/services/invoke/uid/0000191fc6b2bb5d?intent=actions.intent.OPEN_APP_FEATURE\&param.feature=%22History%22"
        val action: String? = intent?.action
        val data: Uri? = intent?.data
        when (action) {
            // When the action is triggered by a deep-link, Intent.Action_VIEW will be used
            Intent.ACTION_VIEW -> {
                when (intent.data.getQueryParameter("feature").toLowerCase()) {
                    "dark" -> {
                        Handler().postDelayed({
                            configChannel.invokeMethod("dark", "")
                        }, 5000)
                    }
                }
            }
            // When the action is triggered by the Google search action, the ACTION_SEARCH will be used
//            SearchIntents.ACTION_SEARCH -> handleSearchIntent(intent.getStringExtra(SearchManager.QUERY))
        }
    }

    override fun onProvideAssistContent(outContent: AssistContent) {
        super.onProvideAssistContent(outContent)

        // JSON-LD object based on Schema.org structured data
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            // This is just an example, more accurate information should be provided
            outContent.structuredData = JSONObject()
                    .put("@type", "Config")
                    .put("name", "Clock")
                    .put("url", "https://dynamiclinkssandbox.page.link/dark")
                    .toString()
        }
    }

    private fun hasRecordPermission(): Boolean {
        return ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestRecordPermission() {
        ActivityCompat.requestPermissions(this, arrayOf<String>(Manifest.permission.RECORD_AUDIO), 0)
    }

    @kotlin.jvm.Throws(IOException::class)
    private fun copyResourceFile(resourceID: Int, filename: String) {
        BufferedInputStream(resources.openRawResource(resourceID), 256).use { `is` ->
            BufferedOutputStream(openFileOutput(filename, Context.MODE_PRIVATE), 256).use { os ->
                var r = 0
                while (`is`.read().also { r = it } != -1) {
                    os.write(r)
                }
                os.flush()
            }
        }
    }

    @kotlin.jvm.Throws(IOException::class)
    private fun copyPorcupineResourceFiles() {
        copyResourceFile(R.raw.hey_pico, resources.getResourceEntryName(R.raw.hey_pico).toString() + ".ppn")
        copyResourceFile(R.raw.porcupine_params, resources.getResourceEntryName(R.raw.porcupine_params).toString() + ".pv")
    }

    private fun showErrorToast() {
        Toast.makeText(this, "Something went wrong", Toast.LENGTH_SHORT).show()
    }

    private fun process() {
        try {
            if (hasRecordPermission()) {
                porcupineManager = initPorcupine()
                porcupineManager?.start()
            } else {
                requestRecordPermission()
            }
        } catch (e: PorcupineManagerException) {
            showErrorToast()
        }
    }

    private fun initPorcupine(): PorcupineManager? {
        val keywordFilePath: String = File(this.filesDir, "hey_pico.ppn").absolutePath
        val modelFilePath: String = File(this.filesDir, "porcupine_params.pv").absolutePath
        return PorcupineManager(modelFilePath, keywordFilePath, 0.5f, KeywordCallback {
            Log.d("porcupine", "hotword detected!")
            runOnUiThread {
                try {
                    hotwordChannel.invokeMethod("hotword", "")
                    porcupineManager?.stop()
                } catch (e: Exception) {
                    Log.d("porcupine", e.message)
                }
            }
        })
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (grantResults.isEmpty() || grantResults[0] == PackageManager.PERMISSION_DENIED) {
//            val tbtn: ToggleButton = findViewById(R.id.record_button)
//            tbtn.toggle()
        } else {
            try {
                porcupineManager = initPorcupine()
                porcupineManager?.start()
            } catch (e: PorcupineManagerException) {
                showErrorToast()
            }
        }
    }
}
