package com.example.app3

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.provider.Settings
import android.util.Log
// 讯飞SDK相关import
import com.iflytek.sparkchain.core.SparkChain
import com.iflytek.sparkchain.core.SparkChainConfig
import com.iflytek.sparkchain.core.asr.ASR
import com.iflytek.sparkchain.core.asr.AsrCallbacks

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.app3/iflytek_asr"
    private var asr: ASR? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 获取 android_id 作为设备唯一标识
        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            when (call.method) {
                "initIflytek" -> {
                    val appId = call.argument<String>("appId") ?: ""
                    val apiKey = call.argument<String>("apiKey") ?: ""
                    val apiSecret = call.argument<String>("apiSecret") ?: ""
                    val config = SparkChainConfig.builder()
                        .appID(appId)
                        .apiKey(apiKey)
                        .apiSecret(apiSecret)
                        .uid(androidId) // 关键：自定义设备唯一标识
                    Log.d("SparkChainInit", "init with appId=$appId, apiKey=$apiKey, apiSecret=$apiSecret, uid=$androidId")
                    val ret = SparkChain.getInst().init(applicationContext, config)
                    Log.d("SparkChainInit", "init return: $ret")
                    result.success(ret == 0)
                }
                "startIflytekAsr" -> {
                    asr = ASR("zh_cn", "slm", "mandarin")
                    Log.d("SparkChainASR", "ASR 实例已创建")
                    asr?.registerCallbacks(object : AsrCallbacks {
                        override fun onResult(asrResult: ASR.ASRResult, usrContext: Any?) {
                            val text = asrResult.bestMatchText
                            val status = asrResult.status
                            val sid = asrResult.sid
                            Log.d("SparkChainASR", "onResult: text=$text, status=$status, sid=$sid")
                            runOnUiThread {
                                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                                    .invokeMethod("onIflytekResult", text)
                            }
                        }
                        override fun onError(asrError: ASR.ASRError, usrContext: Any?) {
                            val errMsg = asrError.errMsg
                            val errCode = asrError.code
                            val sid = asrError.sid
                            Log.e("SparkChainASR", "onError: code=$errCode, msg=$errMsg, sid=$sid")
                            runOnUiThread {
                                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                                    .invokeMethod("onIflytekError", errMsg)
                            }
                        }
                        override fun onBeginOfSpeech() {
                            Log.d("SparkChainASR", "onBeginOfSpeech")
                        }
                        override fun onEndOfSpeech() {
                            Log.d("SparkChainASR", "onEndOfSpeech")
                        }
                    })
                    asr?.start(null)
                    Log.d("SparkChainASR", "asr.start(null) 已调用")
                    result.success(true)
                }
                "stopIflytekAsr" -> {
                    asr?.stop(false)
                    Log.d("SparkChainASR", "asr.stop(false) 已调用")
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}
