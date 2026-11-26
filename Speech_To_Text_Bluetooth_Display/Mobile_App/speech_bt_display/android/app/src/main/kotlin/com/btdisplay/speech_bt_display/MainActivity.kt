package com.btdisplay.speech_bt_display

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Bundle
import android.provider.Settings
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Bluetooth Classic SPP (serial port profile) for the HC-05.
 * Dart side: lib/services/bt_spp.dart
 *   MethodChannel "bt_spp/methods": isEnabled, bondedDevices, startDiscovery, cancelDiscovery,
 *                                   bond, connect, disconnect, write, openSettings
 *   EventChannel  "bt_spp/events":  {type: data|state|found|discovery_finished|bond, ...}
 * Runtime permissions are requested from Dart (permission_handler) before these calls.
 */
@SuppressLint("MissingPermission")
class MainActivity : FlutterActivity() {
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val main = Handler(Looper.getMainLooper())
    private val io = Executors.newSingleThreadExecutor()
    private var socket: BluetoothSocket? = null
    private var sink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    // ---------- speech recognition ----------
    private var recognizer: SpeechRecognizer? = null
    private var sttSink: EventChannel.EventSink? = null
    private fun sttEmit(event: Map<String, Any?>) = main.post { sttSink?.success(event) }

    private val adapter: BluetoothAdapter?
        get() = (getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager?)?.adapter

    private fun emit(event: Map<String, Any?>) = main.post { sink?.success(event) }

    private val discoveryReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                BluetoothDevice.ACTION_FOUND -> {
                    val d: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33)
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    else @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    if (d != null) emit(mapOf("type" to "found", "name" to (d.name ?: ""), "address" to d.address,
                        "bonded" to (d.bondState == BluetoothDevice.BOND_BONDED)))
                }
                BluetoothAdapter.ACTION_DISCOVERY_FINISHED -> emit(mapOf("type" to "discovery_finished"))
                BluetoothDevice.ACTION_BOND_STATE_CHANGED -> {
                    val d: BluetoothDevice? = if (Build.VERSION.SDK_INT >= 33)
                        intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                    else @Suppress("DEPRECATION") intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                    val state = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, -1)
                    emit(mapOf("type" to "bond", "address" to d?.address, "bonded" to (state == BluetoothDevice.BOND_BONDED)))
                }
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "bt_spp/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink) { sink = events }
            override fun onCancel(args: Any?) { sink = null }
        })

        EventChannel(messenger, "stt/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(args: Any?, events: EventChannel.EventSink) { sttSink = events }
            override fun onCancel(args: Any?) { sttSink = null }
        })
        MethodChannel(messenger, "stt/methods").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> startStt(call.argument<String>("lang") ?: "ar-EG", call.argument<Boolean>("mix") == true, result)
                "stop" -> { recognizer?.stopListening(); result.success(true) }
                "mixSupported" -> result.success(mixSupported())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "bt_spp/methods").setMethodCallHandler { call, result ->
            val bt = adapter
            when (call.method) {
                "isEnabled" -> result.success(bt?.isEnabled == true)
                "bondedDevices" -> {
                    if (bt == null) { result.success(emptyList<Map<String, Any>>()); return@setMethodCallHandler }
                    result.success(bt.bondedDevices.map { mapOf("name" to (it.name ?: ""), "address" to it.address, "bonded" to true) })
                }
                "startDiscovery" -> {
                    registerReceiverOnce()
                    if (bt?.isDiscovering == true) bt.cancelDiscovery()
                    result.success(bt?.startDiscovery() == true)
                }
                "cancelDiscovery" -> result.success(bt?.cancelDiscovery() == true)
                "bond" -> {
                    registerReceiverOnce()
                    val d = bt?.getRemoteDevice(call.argument<String>("address"))
                    result.success(d?.createBond() == true)   // Android shows the PIN dialog (1234 / 0000)
                }
                "connect" -> {
                    val address = call.argument<String>("address")
                    if (bt == null || address == null) { result.error("NO_BT", "Bluetooth not available", null); return@setMethodCallHandler }
                    io.execute { connect(bt, address, result) }
                }
                "disconnect" -> { closeSocket(); result.success(true) }
                "write" -> {
                    val bytes = call.argument<ByteArray>("bytes")
                    val s = socket
                    if (s == null || bytes == null) { result.error("NOT_CONNECTED", "Not connected", null); return@setMethodCallHandler }
                    io.execute {
                        try {
                            s.outputStream.write(bytes)
                            s.outputStream.flush()
                            main.post { result.success(true) }
                        } catch (e: IOException) {
                            closeSocket()
                            main.post { result.error("WRITE_FAILED", e.message, null) }
                        }
                    }
                }
                "openSettings" -> {
                    startActivity(Intent(Settings.ACTION_BLUETOOTH_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Arabic + English in one sentence: Android 14+ language switching, on-device recognizer only. */
    private fun mixSupported(): Boolean =
        Build.VERSION.SDK_INT >= 34 && SpeechRecognizer.isOnDeviceRecognitionAvailable(this)

    private fun startStt(lang: String, mix: Boolean, result: MethodChannel.Result) {
        if (!SpeechRecognizer.isRecognitionAvailable(this)) {
            result.error("STT_UNAVAILABLE", "No speech recognizer on this phone", null); return
        }
        recognizer?.destroy()
        val useMix = mix && mixSupported()
        val r = if (useMix && Build.VERSION.SDK_INT >= 34) SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                else SpeechRecognizer.createSpeechRecognizer(this)
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            private fun text(b: Bundle?): String =
                b?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull() ?: ""
            override fun onReadyForSpeech(params: Bundle?) { sttEmit(mapOf("type" to "ready")) }
            override fun onBeginningOfSpeech() {}
            override fun onRmsChanged(rmsdB: Float) {}
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() {}
            override fun onPartialResults(b: Bundle?) { sttEmit(mapOf("type" to "partial", "text" to text(b))) }
            override fun onResults(b: Bundle?) {
                sttEmit(mapOf("type" to "final", "text" to text(b)))
                sttEmit(mapOf("type" to "end"))
            }
            override fun onError(error: Int) {
                sttEmit(mapOf("type" to "error", "code" to error))
                sttEmit(mapOf("type" to "end"))
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, lang)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_PREFERENCE, lang)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 2500L)
            if (useMix && Build.VERSION.SDK_INT >= 34) {
                putExtra(RecognizerIntent.EXTRA_ENABLE_LANGUAGE_SWITCH, RecognizerIntent.LANGUAGE_SWITCH_BALANCED)
                putStringArrayListExtra(RecognizerIntent.EXTRA_LANGUAGE_SWITCH_ALLOWED_LANGUAGES, arrayListOf("ar-EG", "en-US"))
            }
        }
        r.startListening(intent)
        result.success(mapOf("mix" to useMix))
    }

    private fun registerReceiverOnce() {
        if (receiverRegistered) return
        val f = IntentFilter().apply {
            addAction(BluetoothDevice.ACTION_FOUND)
            addAction(BluetoothAdapter.ACTION_DISCOVERY_FINISHED)
            addAction(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(discoveryReceiver, f, Context.RECEIVER_EXPORTED)
        else registerReceiver(discoveryReceiver, f)
        receiverRegistered = true
    }

    private fun connect(bt: BluetoothAdapter, address: String, result: MethodChannel.Result) {
        closeSocket()
        bt.cancelDiscovery()                       // discovery makes connecting slow and unreliable
        val device = bt.getRemoteDevice(address)
        var s: BluetoothSocket? = null
        try {
            s = device.createRfcommSocketToServiceRecord(sppUuid)
            s.connect()
        } catch (first: IOException) {
            // Some phones fail the SDP lookup with the HC-05; channel 1 fallback works on those.
            try { s?.close() } catch (_: IOException) {}
            try {
                val m = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                s = m.invoke(device, 1) as BluetoothSocket
                s.connect()
            } catch (e: Exception) {
                try { s?.close() } catch (_: IOException) {}
                main.post { result.error("CONNECT_FAILED", first.message ?: e.message, null) }
                return
            }
        }
        socket = s
        emit(mapOf("type" to "state", "connected" to true, "address" to address))
        main.post { result.success(true) }
        readLoop(s!!)
    }

    private fun readLoop(s: BluetoothSocket) {
        Thread {
            val buf = ByteArray(256)
            try {
                while (true) {
                    val n = s.inputStream.read(buf)
                    if (n < 0) break
                    emit(mapOf("type" to "data", "bytes" to buf.copyOf(n)))
                }
            } catch (_: IOException) {
            }
            if (socket === s) {
                socket = null
                emit(mapOf("type" to "state", "connected" to false))
            }
        }.start()
    }

    private fun closeSocket() {
        val s = socket
        socket = null
        try { s?.close() } catch (_: IOException) {}
        if (s != null) emit(mapOf("type" to "state", "connected" to false))
    }

    override fun onDestroy() {
        recognizer?.destroy()
        closeSocket()
        if (receiverRegistered) unregisterReceiver(discoveryReceiver)
        super.onDestroy()
    }
}
