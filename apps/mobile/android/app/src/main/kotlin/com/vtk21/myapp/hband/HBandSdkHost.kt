package com.vtk21.myapp.hband

import android.app.Application
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.inuker.bluetooth.library.Code
import com.inuker.bluetooth.library.Constants
import com.inuker.bluetooth.library.search.SearchResult
import com.inuker.bluetooth.library.search.response.SearchResponse
import com.veepoo.protocol.VPOperateManager
import com.veepoo.protocol.listener.base.IABleConnectStatusListener
import com.veepoo.protocol.listener.base.IBleWriteResponse
import com.veepoo.protocol.listener.base.IConnectResponse
import com.veepoo.protocol.listener.base.INotifyResponse
import com.veepoo.protocol.listener.data.IBatteryDataListener
import com.veepoo.protocol.listener.data.ICustomSettingDataListener
import com.veepoo.protocol.listener.data.IDeviceFuctionDataListener
import com.veepoo.protocol.listener.data.IHRVOriginDataListener
import com.veepoo.protocol.listener.data.IHeartDataListener
import com.veepoo.protocol.listener.data.IPersonInfoDataListener
import com.veepoo.protocol.listener.data.IPwdDataListener
import com.veepoo.protocol.listener.data.ISleepDataListener
import com.veepoo.protocol.listener.data.ISocialMsgDataListener
import com.veepoo.protocol.listener.data.ISpo2hOriginDataListener
import com.veepoo.protocol.listener.data.ISportDataListener
import com.veepoo.protocol.listener.data.ITemptureDataListener
import com.veepoo.protocol.model.datas.BatteryData
import com.veepoo.protocol.model.datas.DeviceFunctionPackage1
import com.veepoo.protocol.model.datas.DeviceFunctionPackage2
import com.veepoo.protocol.model.datas.DeviceFunctionPackage3
import com.veepoo.protocol.model.datas.DeviceFunctionPackage4
import com.veepoo.protocol.model.datas.DeviceFunctionPackage5
import com.veepoo.protocol.model.datas.FunctionDeviceSupportData
import com.veepoo.protocol.model.datas.FunctionSocailMsgData
import com.veepoo.protocol.model.datas.HRVOriginData
import com.veepoo.protocol.model.datas.HeartData
import com.veepoo.protocol.model.datas.PersonInfoData
import com.veepoo.protocol.model.datas.PwdData
import com.veepoo.protocol.model.datas.SleepData
import com.veepoo.protocol.model.datas.Spo2hOriginData
import com.veepoo.protocol.model.datas.SportData
import com.veepoo.protocol.model.datas.TemptureData
import com.veepoo.protocol.model.enums.EFunctionStatus
import com.veepoo.protocol.model.enums.EOprateStauts
import com.veepoo.protocol.model.enums.EPwdStatus
import com.veepoo.protocol.model.enums.ESex
import com.veepoo.protocol.model.settings.CustomSettingData
import com.veepoo.protocol.model.settings.ReadOriginSetting
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Host for the official HBand / Veepoo Android SDK (`VPOperateManager`).
 *
 * Lifecycle mirrors the vendor sample: Application init → scan → connect →
 * notify ready → confirmDevicePwd → syncPersonInfo → health queries.
 *
 * Method/Event channel names stay `com.vytaltek.qring/methods` and
 * `com.vytaltek.qring/events` so the existing Flutter bridge keeps working
 * while Android uses HBand underneath.
 */
object HBandSdkHost : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private const val TAG = "VytalHBand"
    private const val CONNECT_TIMEOUT_MS = 60_000L
    private const val DEFAULT_PWD = "0000"

    private lateinit var app: Application
    private val mainHandler = Handler(Looper.getMainLooper())
    private val noopWrite = IBleWriteResponse { }

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var capabilities: MutableMap<String, Any?> = defaultCapabilities()

    @Volatile
    private var firmwareVersion: String? = null

    @Volatile
    private var connectedMac: String? = null

    @Volatile
    private var connectedName: String = "Vytal"

    @Volatile
    private var pendingConnectResult: MethodChannel.Result? = null

    private var connectTimeoutRunnable: Runnable? = null

    @Volatile
    private var workoutMonitoringActive = false

    @Volatile
    private var handshakeFinishing = false

    private var connectStatusListener: IABleConnectStatusListener? = null

    fun init(application: Application) {
        app = application
        VPOperateManager.getMangerInstance(application.applicationContext)
        VPOperateManager.getInstance().init(application.applicationContext)
        VPOperateManager.getInstance().setDeviceShowConfirm(false)
        Log.i(TAG, "HBand / Veepoo SDK host initialized")
    }

    fun attachChannels(methods: MethodChannel, events: EventChannel) {
        methods.setMethodCallHandler(this)
        events.setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAvailable" -> result.success(true)
            "initialize" -> result.success(null)
            "startScan" -> {
                val timeoutMs = call.argument<Int>("timeoutMs") ?: 12_000
                startScan(timeoutMs)
                result.success(null)
            }
            "stopScan" -> {
                stopScan()
                result.success(null)
            }
            "connect" -> {
                val deviceId = call.argument<String>("deviceId")
                val name = call.argument<String>("name")
                if (deviceId.isNullOrBlank()) {
                    result.error("missing_device_id", "Device id required", null)
                } else {
                    connect(deviceId, name, result)
                }
            }
            "disconnect" -> {
                // `unbind` is accepted for Flutter API compatibility; HBand
                // disconnects via disconnectWatch either way.
                disconnect()
                result.success(null)
            }
            "isConnected" -> result.success(VPOperateManager.getInstance().isCurrentDeviceConnected)
            "getCapabilities" -> result.success(HashMap(capabilities))
            "readBattery" -> readBattery(result)
            "syncHealth" -> syncHealth(result)
            "startWorkoutMonitoring" -> {
                if (!VPOperateManager.getInstance().isCurrentDeviceConnected) {
                    result.error("not_connected", "Wearable is not connected.", null)
                    return
                }
                startWorkoutMonitoring()
                result.success(null)
            }
            "stopWorkoutMonitoring" -> {
                stopWorkoutMonitoring()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun startScan(timeoutMs: Int) {
        stopScan()
        val timeoutSec = (timeoutMs / 1000).coerceAtLeast(5)
        VPOperateManager.getInstance().startScanDevice(
            timeoutSec,
            object : SearchResponse {
                override fun onSearchStarted() {}

                override fun onDeviceFounded(device: SearchResult?) {
                    if (device == null) return
                    val name = device.name?.takeIf { it.isNotBlank() } ?: return
                    emit(
                        "scanResult",
                        mapOf(
                            "deviceId" to device.address,
                            "name" to name,
                            "rssi" to device.rssi,
                        ),
                    )
                }

                override fun onSearchStopped() {
                    emit("scanStopped", emptyMap<String, Any>())
                }

                override fun onSearchCanceled() {
                    emit("scanStopped", emptyMap<String, Any>())
                }
            },
        )
        mainHandler.postDelayed({ stopScan() }, timeoutMs.toLong())
    }

    private fun stopScan() {
        try {
            VPOperateManager.getInstance().stopScanDevice()
        } catch (e: Exception) {
            Log.w(TAG, "stopScan: ${e.message}")
        }
    }

    private fun connect(deviceId: String, name: String?, result: MethodChannel.Result) {
        stopScan()
        pendingConnectResult?.error("cancelled", "Superseded by a new connect", null)
        pendingConnectResult = result
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        val timeout = Runnable {
            failConnect("connect_timeout", "Connecting timed out. Keep the device nearby and try again.")
            try {
                VPOperateManager.getInstance().disconnectWatch(noopWrite)
            } catch (_: Exception) {
            }
        }
        connectTimeoutRunnable = timeout
        mainHandler.postDelayed(timeout, CONNECT_TIMEOUT_MS)

        connectedMac = deviceId
        connectedName = name?.takeIf { it.isNotBlank() } ?: "Vytal"
        capabilities = defaultCapabilities()
        firmwareVersion = null
        handshakeFinishing = false

        unregisterConnectListener()
        val listener = object : IABleConnectStatusListener() {
            override fun onConnectStatusChanged(mac: String?, status: Int) {
                if (status == Constants.STATUS_DISCONNECTED) {
                    emit(
                        "connection",
                        mapOf(
                            "state" to "disconnected",
                            "deviceId" to (mac ?: connectedMac ?: ""),
                        ),
                    )
                }
            }
        }
        connectStatusListener = listener
        VPOperateManager.getInstance().registerConnectStatusListener(deviceId, listener)

        VPOperateManager.getInstance().connectDevice(
            deviceId,
            connectedName,
            IConnectResponse { code, _, isOadModel ->
                if (code == Code.REQUEST_SUCCESS) {
                    Log.i(TAG, "GATT connected (oad=$isOadModel)")
                } else {
                    failConnect("connect_failed", "Bluetooth connection failed ($code).")
                }
            },
            INotifyResponse { state ->
                if (state == Code.REQUEST_SUCCESS) {
                    runHandshake()
                } else {
                    failConnect("notify_failed", "Device notifications failed to open ($state).")
                }
            },
        )
    }

    private fun runHandshake() {
        VPOperateManager.getInstance().confirmDevicePwd(
            noopWrite,
            object : IPwdDataListener {
                override fun onPwdDataChange(pwdData: PwdData?) {
                    if (pwdData == null) return
                    firmwareVersion = pwdData.deviceVersion
                    when (pwdData.getmStatus()) {
                        EPwdStatus.CHECK_FAIL ->
                            failConnect("password_failed", "Device password check failed.")
                        EPwdStatus.CHECK_SUCCESS,
                        EPwdStatus.CHECK_AND_TIME_SUCCESS,
                        -> {
                            // Fallback if custom-setting callback is delayed/missing.
                            mainHandler.postDelayed({
                                if (!handshakeFinishing && pendingConnectResult != null) {
                                    syncPersonInfoThenComplete()
                                }
                            }, 2_500)
                        }
                        else -> Unit
                    }
                }

                override fun onConnectionConfirmTimeout() {
                    failConnect("password_timeout", "Device password confirmation timed out.")
                }
            },
            object : IDeviceFuctionDataListener {
                override fun onFunctionSupportDataChange(functionSupport: FunctionDeviceSupportData?) {
                    if (functionSupport != null) {
                        mergeCapabilities(functionSupport)
                    }
                }

                override fun onDeviceFunctionPackage1Report(p: DeviceFunctionPackage1?) {}
                override fun onDeviceFunctionPackage2Report(p: DeviceFunctionPackage2?) {}
                override fun onDeviceFunctionPackage3Report(p: DeviceFunctionPackage3?) {}
                override fun onDeviceFunctionPackage4Report(p: DeviceFunctionPackage4?) {}
                override fun onDeviceFunctionPackage5Report(p: DeviceFunctionPackage5?) {}
            },
            object : ISocialMsgDataListener {
                override fun onSocialMsgSupportDataChange(data: FunctionSocailMsgData?) {}
                override fun onSocialMsgSupportDataChange2(data: FunctionSocailMsgData?) {}
            },
            object : ICustomSettingDataListener {
                override fun OnSettingDataChange(customSettingData: CustomSettingData?) {
                    syncPersonInfoThenComplete()
                }
            },
            DEFAULT_PWD,
            true,
        )
    }

    private fun syncPersonInfoThenComplete() {
        if (handshakeFinishing) return
        handshakeFinishing = true
        VPOperateManager.getInstance().syncPersonInfo(
            noopWrite,
            object : IPersonInfoDataListener {
                override fun OnPersoninfoDataChange(status: EOprateStauts?) {
                    completeConnectSuccess()
                }
            },
            // Placeholder profile until profile sync is wired from Flutter.
            PersonInfoData(ESex.MAN, 170, 65, 30, 8000),
        )
        // If person-info ack never arrives, still mark connected after pwd success.
        mainHandler.postDelayed({
            if (pendingConnectResult != null) {
                completeConnectSuccess()
            }
        }, 4_000)
    }

    private fun mergeCapabilities(support: FunctionDeviceSupportData) {
        val map = defaultCapabilities()
        fun supported(status: EFunctionStatus?): Boolean =
            status != null && status != EFunctionStatus.UNSUPPORT && status != EFunctionStatus.UNKONW

        val heart = supported(support.heartDetect)
        map["supportHeart"] = heart
        map["supportAppMeasure"] = heart
        map["supportManualHeart"] = heart
        map["supportIntervalHeartRate"] = heart
        map["supportHrv"] =
            supported(support.hrvFunction) || supported(support.hrvAppDetectFunction)
        map["supportBloodOxygen"] = supported(support.spo2H)
        map["supportManualBloodOxygen"] = supported(support.spo2H)
        map["supportIntervalBloodOxygen"] = supported(support.spo2H)
        val temp =
            supported(support.temperatureFunction) || support.temptureType > 0
        map["supportTemperature"] = temp
        map["supportSkinTemperature"] = temp
        map["supportIntervalTemperature"] = temp
        map["supportPressure"] = supported(support.fatigue)
        map["supportBloodPressure"] = supported(support.bp)
        map["supportNewSleepProtocol"] = supported(support.precisionSleep)
        map["supportEcg"] = supported(support.ecg)
        map["supportBlePair"] = false
        map["supportFirmwareUpdate"] = true
        capabilities = map
    }

    private fun completeConnectSuccess() {
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        connectTimeoutRunnable = null
        val payload = hashMapOf<String, Any?>(
            "deviceId" to (connectedMac ?: ""),
            "name" to connectedName,
            "firmwareVersion" to firmwareVersion,
            "capabilities" to HashMap(capabilities),
            "state" to "connected",
        )
        emit("connection", payload)
        pendingConnectResult?.success(payload)
        pendingConnectResult = null
    }

    private fun failConnect(code: String, message: String) {
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        connectTimeoutRunnable = null
        emit(
            "connection",
            mapOf("state" to "error", "code" to code, "message" to message),
        )
        pendingConnectResult?.error(code, message, null)
        pendingConnectResult = null
    }

    private fun disconnect() {
        stopWorkoutMonitoring()
        unregisterConnectListener()
        try {
            VPOperateManager.getInstance().disconnectWatch(noopWrite)
        } catch (e: Exception) {
            Log.w(TAG, "disconnect: ${e.message}")
        }
        connectedMac = null
    }

    private fun unregisterConnectListener() {
        val mac = connectedMac
        val listener = connectStatusListener
        if (mac != null && listener != null) {
            try {
                VPOperateManager.getInstance().unregisterConnectStatusListener(mac, listener)
            } catch (_: Exception) {
            }
        }
        connectStatusListener = null
    }

    private fun readBattery(result: MethodChannel.Result) {
        if (!VPOperateManager.getInstance().isCurrentDeviceConnected) {
            result.success(null)
            return
        }
        VPOperateManager.getInstance().readBattery(
            noopWrite,
            object : IBatteryDataListener {
                override fun onDataChange(data: BatteryData?) {
                    mainHandler.post {
                        if (data == null) {
                            result.success(null)
                            return@post
                        }
                        val percent =
                            if (data.isPercent) data.batteryPercent
                            else when (data.batteryLevel) {
                                in 0..4 -> (data.batteryLevel + 1) * 20
                                else -> data.batteryPercent
                            }
                        result.success(
                            mapOf(
                                "percent" to percent.coerceIn(0, 100),
                                "charging" to (data.state == 1),
                                "rawLevel" to data.batteryLevel,
                            ),
                        )
                    }
                }
            },
        )
    }

    private fun syncHealth(result: MethodChannel.Result) {
        if (!VPOperateManager.getInstance().isCurrentDeviceConnected) {
            result.error("not_connected", "Wearable is not connected.", null)
            return
        }
        Thread {
            val out = HashMap<String, Any?>()
            out["sleepAvailable"] = true
            out["stepsAvailable"] = true

            // Battery
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<BatteryData?>()
                VPOperateManager.getInstance().readBattery(
                    noopWrite,
                    object : IBatteryDataListener {
                        override fun onDataChange(data: BatteryData?) {
                            ref.set(data)
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(5, TimeUnit.SECONDS)) {
                    ref.get()?.let { data ->
                        val percent =
                            if (data.isPercent) data.batteryPercent
                            else when (data.batteryLevel) {
                                in 0..4 -> (data.batteryLevel + 1) * 20
                                else -> data.batteryPercent
                            }
                        if (percent > 0) {
                            out["battery"] = mapOf(
                                "percent" to percent.coerceIn(0, 100),
                                "charging" to (data.state == 1),
                                "rawLevel" to data.batteryLevel,
                            )
                        }
                    }
                }
            }

            // Steps / calories / distance
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<SportData?>()
                VPOperateManager.getInstance().readSportStep(
                    noopWrite,
                    object : ISportDataListener {
                        override fun onSportDataChange(sportData: SportData?) {
                            ref.set(sportData)
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    ref.get()?.let { sport ->
                        if (sport.step > 0) out["steps"] = sport.step
                        if (sport.kcal > 0) out["calories"] = sport.kcal
                        if (sport.dis > 0) out["distanceMeters"] = (sport.dis * 1000).toInt()
                    }
                }
            }

            // Sleep (today = day index 1 in vendor samples)
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<SleepData?>()
                VPOperateManager.getInstance().readSleepDataSingleDay(
                    noopWrite,
                    object : ISleepDataListener {
                        override fun onSleepDataChange(day: String?, sleepData: SleepData?) {
                            if (sleepData != null && sleepData.allSleepTime > 0) {
                                ref.set(sleepData)
                            }
                        }

                        override fun onSleepProgress(progress: Float) {}
                        override fun onSleepProgressDetail(day: String?, packNum: Int) {}
                        override fun onReadSleepComplete() {
                            latch.countDown()
                        }
                    },
                    1,
                    3,
                )
                if (latch.await(12, TimeUnit.SECONDS)) {
                    ref.get()?.allSleepTime?.takeIf { it > 0 }?.let { out["sleepMinutes"] = it }
                }
            }

            // HRV — last positive sample for day 1
            if (capabilities["supportHrv"] == true) {
                runCatching {
                    val latch = CountDownLatch(1)
                    var lastHrv = 0
                    VPOperateManager.getInstance().readHRVOrigin(
                        noopWrite,
                        object : IHRVOriginDataListener {
                            override fun onReadOriginProgress(progress: Float) {}
                            override fun onReadOriginProgressDetail(
                                day: Int,
                                date: String?,
                                allPackage: Int,
                                currentPackage: Int,
                            ) {
                            }

                            override fun onHRVOriginListener(data: HRVOriginData?) {
                                val v = data?.hrvValue ?: 0
                                if (v > 0) lastHrv = v
                            }

                            override fun onDayHrvScore(day: Int, date: String?, score: Int) {}
                            override fun onReadOriginComplete() {
                                latch.countDown()
                            }
                        },
                        1,
                    )
                    if (latch.await(15, TimeUnit.SECONDS) && lastHrv > 0) {
                        out["hrvMs"] = lastHrv
                    }
                }
            }

            // SpO2
            if (capabilities["supportBloodOxygen"] == true) {
                runCatching {
                    val latch = CountDownLatch(1)
                    var lastSpo2 = 0
                    VPOperateManager.getInstance().readSpo2hOrigin(
                        noopWrite,
                        object : ISpo2hOriginDataListener {
                            override fun onReadOriginProgress(progress: Float) {}
                            override fun onReadOriginProgressDetail(
                                day: Int,
                                date: String?,
                                allPackage: Int,
                                currentPackage: Int,
                            ) {
                            }

                            override fun onSpo2hOriginListener(data: Spo2hOriginData?) {
                                val v = data?.oxygenValue ?: 0
                                if (v > 0) lastSpo2 = v
                            }

                            override fun onReadOriginComplete() {
                                latch.countDown()
                            }
                        },
                        1,
                    )
                    if (latch.await(15, TimeUnit.SECONDS) && lastSpo2 > 0) {
                        out["spo2Percent"] = lastSpo2
                    }
                }
            }

            // Temperature
            if (capabilities["supportTemperature"] == true) {
                runCatching {
                    val latch = CountDownLatch(1)
                    var lastTemp = 0f
                    val setting = ReadOriginSetting(1, 1, true, 3)
                    VPOperateManager.getInstance().readTemptureDataBySetting(
                        noopWrite,
                        object : ITemptureDataListener {
                            override fun onTemptureDataListDataChange(list: MutableList<TemptureData>?) {
                                list?.forEach { item ->
                                    val t = item.tempture
                                    if (t > 0f) lastTemp = t
                                }
                            }

                            override fun onReadOriginProgressDetail(
                                day: Int,
                                date: String?,
                                allPackage: Int,
                                currentPackage: Int,
                            ) {
                            }

                            override fun onReadOriginProgress(progress: Float) {}
                            override fun onReadOriginComplete() {
                                latch.countDown()
                            }

                            override fun onReadTimeout(code: Int) {
                                latch.countDown()
                            }
                        },
                        setting,
                    )
                    if (latch.await(15, TimeUnit.SECONDS) && lastTemp > 0f) {
                        out["temperatureCelsius"] = lastTemp.toDouble()
                    }
                }
            }

            mainHandler.post { result.success(out) }
        }.start()
    }

    private fun startWorkoutMonitoring() {
        workoutMonitoringActive = true
        VPOperateManager.getInstance().startDetectHeart(
            noopWrite,
            object : IHeartDataListener {
                override fun onDataChange(heart: HeartData?) {
                    if (!workoutMonitoringActive) return
                    val bpm = heart?.data ?: 0
                    if (bpm > 0) {
                        emit("heartRateUpdate", mapOf("bpm" to bpm))
                    }
                }
            },
        )
    }

    private fun stopWorkoutMonitoring() {
        workoutMonitoringActive = false
        try {
            VPOperateManager.getInstance().stopDetectHeart(noopWrite)
        } catch (e: Exception) {
            Log.w(TAG, "stopDetectHeart: ${e.message}")
        }
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to type, "payload" to payload))
        }
    }

    private fun defaultCapabilities(): MutableMap<String, Any?> = mutableMapOf(
        "supportHeart" to false,
        "supportAppMeasure" to false,
        "supportManualHeart" to false,
        "supportIntervalHeartRate" to false,
        "supportHrv" to false,
        "supportBloodOxygen" to false,
        "supportManualBloodOxygen" to false,
        "supportIntervalBloodOxygen" to false,
        "supportTemperature" to false,
        "supportSkinTemperature" to false,
        "supportIntervalTemperature" to false,
        "supportPressure" to false,
        "supportBloodPressure" to false,
        "supportNewSleepProtocol" to false,
        "supportEcg" to false,
        "supportBlePair" to false,
        "supportFirmwareUpdate" to true,
    )
}
