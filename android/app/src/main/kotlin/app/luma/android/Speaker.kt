package app.luma.android

import android.content.Context
import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import java.util.UUID

/**
 * 朗读。用系统 TTS（与 iOS 版同样选择：离线、不依赖本地神经模型）。
 * `finishedAt` 用于算「播完到提交」的反应时延，和 macOS/iOS 的慢反应判定同一套阈值。
 */
class Speaker(private val context: Context) {

    enum class Accent(val label: String, val locale: Locale) {
        AMERICAN("美式发音", Locale.US),
        BRITISH("英式发音", Locale.UK),
    }

    private var tts: TextToSpeech? = null
    private var ready = false
    private var pending: (() -> Unit)? = null

    var accent: Accent = Accent.AMERICAN
        set(value) {
            field = value
            tts?.language = value.locale
        }

    /** 0.2–0.8，与设置页滑杆一致。 */
    var rate: Float = 0.45f
        set(value) {
            field = value.coerceIn(0.2f, 0.8f)
            tts?.setSpeechRate(field)
        }

    var repeatCount: Int = 1

    var finishedSpeakingAt: Long = 0L
        private set

    fun start() {
        if (tts != null) return
        tts = TextToSpeech(context) { status ->
            ready = status == TextToSpeech.SUCCESS
            val engine = tts ?: return@TextToSpeech
            if (!ready) return@TextToSpeech
            engine.language = accent.locale
            engine.setSpeechRate(rate)
            engine.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
                override fun onStart(utteranceId: String?) = Unit
                override fun onDone(utteranceId: String?) {
                    finishedSpeakingAt = System.currentTimeMillis()
                }

                @Deprecated("Deprecated in Java")
                override fun onError(utteranceId: String?) = Unit
            })
            pending?.invoke()
            pending = null
        }
    }

    fun speak(text: String, repeat: Int = repeatCount) {
        val engine = tts
        if (engine == null || !ready) {
            pending = { speak(text, repeat) }
            start()
            return
        }
        engine.stop()
        repeat.coerceIn(1, 3).let { times ->
            repeat(times) {
                engine.speak(text, TextToSpeech.QUEUE_ADD, null, UUID.randomUUID().toString())
            }
        }
    }

    fun stop() {
        tts?.stop()
    }

    fun shutdown() {
        tts?.shutdown()
        tts = null
        ready = false
    }
}
