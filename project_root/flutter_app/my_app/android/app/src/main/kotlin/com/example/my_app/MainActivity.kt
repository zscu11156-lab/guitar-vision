package com.example.my_app

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "gv.tuner/audioStream"

    private var recorder: AudioRecord? = null
    private var recordingThread: Thread? = null
    @Volatile private var isRecording = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        Log.i("MicStream", "configureFlutterEngine CALLED")

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    Log.i("MicStream", "EventChannel onListen CALLED")
                    startRecording(events)
                }
                override fun onCancel(arguments: Any?) {
                    stopRecording()
                }
            })
    }

    private fun tryBuildRecorder(
        source: Int,
        sampleRate: Int,
        channelConfig: Int,
        audioFormat: Int,
        bufferSize: Int
    ): AudioRecord? {
        return try {
            val r = AudioRecord(source, sampleRate, channelConfig, audioFormat, bufferSize)
            if (r.state == AudioRecord.STATE_INITIALIZED) r else { r.release(); null }
        } catch (_: Throwable) {
            null
        }
    }

    private fun startRecording(events: EventChannel.EventSink) {
        if (isRecording) return

        val sampleRate = 44100
        val channelConfig = AudioFormat.CHANNEL_IN_MONO
        val audioFormat  = AudioFormat.ENCODING_PCM_16BIT

        val min = AudioRecord.getMinBufferSize(sampleRate, channelConfig, audioFormat)
        if (min <= 0) {
            runOnUiThread { events.error("INIT_FAIL", "getMinBufferSize()=$min", null) }
            return
        }
        val bufferSize = (min * 2).coerceAtLeast(4096)

        // 先試 VOICE_RECOGNITION，再退回 MIC（不同裝置相容性較好）
        val rec = tryBuildRecorder(MediaRecorder.AudioSource.VOICE_RECOGNITION,
                                   sampleRate, channelConfig, audioFormat, bufferSize)
            ?: tryBuildRecorder(MediaRecorder.AudioSource.MIC,
                                sampleRate, channelConfig, audioFormat, bufferSize)

        if (rec == null) {
            runOnUiThread { events.error("INIT_FAIL", "AudioRecord not initialized", null) }
            return
        }

        try {
            rec.startRecording()
        } catch (t: Throwable) {
            runOnUiThread { events.error("START_FAIL", t.message, null) }
            rec.release()
            return
        }

        recorder = rec
        isRecording = true

        recordingThread = Thread {
            android.os.Process.setThreadPriority(android.os.Process.THREAD_PRIORITY_AUDIO)
            val buf = ByteArray(bufferSize)
            while (isRecording) {
                val n = rec.read(buf, 0, buf.size)
                if (n > 0) {
                    val out = ByteArray(n)
                    System.arraycopy(buf, 0, out, 0, n)
                    // ★ EventSink 必須在主執行緒呼叫，否則會 crash
                    runOnUiThread { events.success(out) }
                } else if (n < 0) {
                    Log.e("MicStream", "read()=$n")
                    runOnUiThread { events.error("READ_FAIL", "read()=$n", null) }
                    break
                }
            }
            try { rec.stop() } catch (_: Throwable) {}
            rec.release()
            if (recorder === rec) recorder = null
            isRecording = false
        }.apply { start() }
    }

    private fun stopRecording() {
        isRecording = false
        try { recordingThread?.join(200) } catch (_: InterruptedException) {}
        recordingThread = null
        recorder?.let { r -> try { r.stop() } catch (_: Throwable) {}; r.release() }
        recorder = null
    }

    override fun onDestroy() {
        stopRecording()
        super.onDestroy()
    }
}
