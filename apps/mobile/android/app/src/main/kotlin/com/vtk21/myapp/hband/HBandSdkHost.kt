package com.vtk21.myapp.hband

import android.Manifest
import android.app.Application
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
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
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.atomic.AtomicReference

/**
 * Host for the official HBand / Veepoo Android SDK (`VPOperateManager`).
 *
 * Crash guards (critical on connect):
 * - Flutter [MethodChannel.Result] is answered **once**, on the **main thread**
 * - Stale BLE callbacks from a previous connect attempt are ignored via [connectGeneration]
 * - BLE [SecurityException] is converted to channel errors instead of crashing
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

    /** Ensures MethodChannel.Result is only answered once per connect attempt. */
    private val connectReplySent = AtomicBoolean(false)

    /** Bumps on every new connect/disconnect so stale BLE callbacks cannot reply. */
    private val connectGeneration = AtomicInteger(0)

    private var connectTimeoutRunnable: Runnable? = null
    private var handshakeFallbackRunnable: Runnable? = null
    private var personInfoFallbackRunnable: Runnable? = null

    @Volatile
    private var workoutMonitoringActive = false

    @Volatile
    private var handshakeFinishing = false

    private var connectStatusListener: IABleConnectStatusListener? = null

    fun init(application: Application) {
        app = application
        try {
            VPOperateManager.getMangerInstance(application.applicationContext)
            VPOperateManager.getInstance().init(application.applicationContext)
            VPOperateManager.getInstance().setDeviceShowConfirm(false)
            Log.i(TAG, "HBand / Veepoo SDK host initialized")
        } catch (e: Exception) {
            Log.e(TAG, "SDK init failed: ${e.message}", e)
        }
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
        try {
            when (call.method) {
                "isAvailable" -> result.success(true)
                "initialize" -> result.success(null)
                "startScan" -> {
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 12_000
                    startScan(timeoutMs, result)
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
                    disconnect()
                    result.success(null)
                }
                "isConnected" -> result.success(
                    runCatching { VPOperateManager.getInstance().isCurrentDeviceConnected }
                        .getOrDefault(false),
                )
                "getCapabilities" -> result.success(HashMap(capabilities))
                "readBattery" -> readBattery(result)
                "syncHealth" -> syncHealth(result)
                "startWorkoutMonitoring" -> {
                    if (!isSdkConnected()) {
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
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException on ${call.method}: ${e.message}", e)
            result.error(
                "bluetooth_permission",
                "Bluetooth permission is required. Allow Bluetooth and try again.",
                null,
            )
        } catch (e: Exception) {
            Log.e(TAG, "Unhandled on ${call.method}: ${e.message}", e)
            result.error("native_error", e.message ?: "Unexpected Bluetooth error", null)
        }
    }

    private fun isSdkConnected(): Boolean =
        runCatching { VPOperateManager.getInstance().isCurrentDeviceConnected }.getOrDefault(false)

    private fun hasBlePermissions(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            val fine = ContextCompat.checkSelfPermission(
                app,
                Manifest.permission.ACCESS_FINE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
            val coarse = ContextCompat.checkSelfPermission(
                app,
                Manifest.permission.ACCESS_COARSE_LOCATION,
            ) == PackageManager.PERMISSION_GRANTED
            return fine || coarse
        }
        val scan = ContextCompat.checkSelfPermission(
            app,
            Manifest.permission.BLUETOOTH_SCAN,
        ) == PackageManager.PERMISSION_GRANTED
        val connect = ContextCompat.checkSelfPermission(
            app,
            Manifest.permission.BLUETOOTH_CONNECT,
        ) == PackageManager.PERMISSION_GRANTED
        return scan && connect
    }

    private fun startScan(timeoutMs: Int, result: MethodChannel.Result) {
        if (!hasBlePermissions()) {
            result.error(
                "bluetooth_permission",
                "Bluetooth permission is required. Allow Bluetooth and try again.",
                null,
            )
            return
        }
        stopScan()
        val timeoutSec = (timeoutMs / 1000).coerceAtLeast(5)
        try {
            VPOperateManager.getInstance().startScanDevice(
                timeoutSec,
                object : SearchResponse {
                    override fun onSearchStarted() {}

                    override fun onDeviceFounded(device: SearchResult?) {
                        if (device == null) return
                        try {
                            val name = device.name?.takeIf { it.isNotBlank() } ?: return
                            val address = device.address ?: return
                            emit(
                                "scanResult",
                                mapOf(
                                    "deviceId" to address,
                                    "name" to name,
                                    "rssi" to device.rssi,
                                ),
                            )
                        } catch (e: SecurityException) {
                            Log.w(TAG, "scan result blocked: ${e.message}")
                        }
                    }

                    override fun onSearchStopped() {
                        emit("scanStopped", emptyMap<String, Any>())
                    }

                    override fun onSearchCanceled() {
                        emit("scanStopped", emptyMap<String, Any>())
                    }
                },
            )
            result.success(null)
        } catch (e: SecurityException) {
            result.error(
                "bluetooth_permission",
                "Bluetooth permission is required. Allow Bluetooth and try again.",
                null,
            )
        } catch (e: Exception) {
            Log.e(TAG, "startScan failed: ${e.message}", e)
            result.error("scan_failed", e.message ?: "Scan failed", null)
        }
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
        if (!hasBlePermissions()) {
            result.error(
                "bluetooth_permission",
                "Bluetooth permission is required. Allow Bluetooth and try again.",
                null,
            )
            return
        }

        // Finish any in-flight connect safely before accepting a new Result.
        // Bump generation first so stale BLE callbacks cannot touch the new Result.
        cancelConnectTimers()
        val generation = connectGeneration.incrementAndGet()
        if (connectReplySent.compareAndSet(false, true)) {
            val previous = pendingConnectResult
            pendingConnectResult = null
            mainHandler.post {
                try {
                    previous?.error("cancelled", "Superseded by a new connect", null)
                } catch (_: Exception) {
                }
            }
        } else {
            pendingConnectResult = null
        }

        connectReplySent.set(false)
        pendingConnectResult = result
        handshakeFinishing = false
        capabilities = defaultCapabilities()
        firmwareVersion = null
        connectedName = name?.takeIf { it.isNotBlank() } ?: "Vytal"

        stopScan()

        // Unregister using the previous MAC before overwriting.
        unregisterConnectListener()
        connectedMac = deviceId

        val timeout = Runnable {
            failConnect(
                generation,
                "connect_timeout",
                "Connecting timed out. Keep the device nearby and try again.",
            )
            try {
                VPOperateManager.getInstance().disconnectWatch(noopWrite)
            } catch (_: Exception) {
            }
        }
        connectTimeoutRunnable = timeout
        mainHandler.postDelayed(timeout, CONNECT_TIMEOUT_MS)

        val listener = object : IABleConnectStatusListener() {
            override fun onConnectStatusChanged(mac: String?, status: Int) {
                if (generation != connectGeneration.get()) return
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

        try {
            VPOperateManager.getInstance().registerConnectStatusListener(deviceId, listener)
            VPOperateManager.getInstance().connectDevice(
                deviceId,
                connectedName,
                IConnectResponse { code, _, isOadModel ->
                    if (generation != connectGeneration.get()) return@IConnectResponse
                    if (code == Code.REQUEST_SUCCESS) {
                        Log.i(TAG, "GATT connected (oad=$isOadModel) gen=$generation")
                    } else {
                        failConnect(
                            generation,
                            "connect_failed",
                            "Bluetooth connection failed ($code).",
                        )
                    }
                },
                INotifyResponse { state ->
                    if (generation != connectGeneration.get()) return@INotifyResponse
                    if (state == Code.REQUEST_SUCCESS) {
                        runHandshake(generation)
                    } else {
                        failConnect(
                            generation,
                            "notify_failed",
                            "Device notifications failed to open ($state).",
                        )
                    }
                },
            )
        } catch (e: SecurityException) {
            failConnect(
                generation,
                "bluetooth_permission",
                "Bluetooth permission is required. Allow Bluetooth and try again.",
            )
        } catch (e: Exception) {
            Log.e(TAG, "connectDevice failed: ${e.message}", e)
            failConnect(generation, "connect_failed", e.message ?: "Bluetooth connection failed.")
        }
    }

    private fun runHandshake(generation: Int) {
        if (generation != connectGeneration.get()) return
        try {
            VPOperateManager.getInstance().confirmDevicePwd(
                noopWrite,
                object : IPwdDataListener {
                    override fun onPwdDataChange(pwdData: PwdData?) {
                        if (generation != connectGeneration.get() || pwdData == null) return
                        firmwareVersion = pwdData.deviceVersion
                        when (pwdData.getmStatus()) {
                            EPwdStatus.CHECK_FAIL ->
                                failConnect(
                                    generation,
                                    "password_failed",
                                    "Device password check failed.",
                                )
                            EPwdStatus.CHECK_SUCCESS,
                            EPwdStatus.CHECK_AND_TIME_SUCCESS,
                            -> {
                                handshakeFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
                                val fallback = Runnable {
                                    if (generation != connectGeneration.get()) return@Runnable
                                    if (!handshakeFinishing && !connectReplySent.get()) {
                                        syncPersonInfoThenComplete(generation)
                                    }
                                }
                                handshakeFallbackRunnable = fallback
                                mainHandler.postDelayed(fallback, 2_500)
                            }
                            else -> Unit
                        }
                    }

                    override fun onConnectionConfirmTimeout() {
                        failConnect(
                            generation,
                            "password_timeout",
                            "Device password confirmation timed out.",
                        )
                    }
                },
                object : IDeviceFuctionDataListener {
                    override fun onFunctionSupportDataChange(functionSupport: FunctionDeviceSupportData?) {
                        if (generation != connectGeneration.get()) return
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
                        if (generation != connectGeneration.get()) return
                        syncPersonInfoThenComplete(generation)
                    }
                },
                DEFAULT_PWD,
                true,
            )
        } catch (e: Exception) {
            Log.e(TAG, "confirmDevicePwd failed: ${e.message}", e)
            failConnect(generation, "handshake_failed", e.message ?: "Device handshake failed.")
        }
    }

    private fun syncPersonInfoThenComplete(generation: Int) {
        if (generation != connectGeneration.get()) return
        if (handshakeFinishing) return
        handshakeFinishing = true
        try {
            VPOperateManager.getInstance().syncPersonInfo(
                noopWrite,
                object : IPersonInfoDataListener {
                    override fun OnPersoninfoDataChange(status: EOprateStauts?) {
                        if (generation != connectGeneration.get()) return
                        completeConnectSuccess(generation)
                    }
                },
                PersonInfoData(ESex.MAN, 170, 65, 30, 8000),
            )
        } catch (e: Exception) {
            Log.e(TAG, "syncPersonInfo failed: ${e.message}", e)
            // Password already succeeded — still treat as connected.
            completeConnectSuccess(generation)
            return
        }
        personInfoFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        val fallback = Runnable {
            if (generation != connectGeneration.get()) return@Runnable
            if (!connectReplySent.get()) {
                completeConnectSuccess(generation)
            }
        }
        personInfoFallbackRunnable = fallback
        mainHandler.postDelayed(fallback, 4_000)
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

    private fun completeConnectSuccess(generation: Int) {
        if (generation != connectGeneration.get()) return
        if (!connectReplySent.compareAndSet(false, true)) return
        cancelConnectTimers()
        val payload = hashMapOf<String, Any?>(
            "deviceId" to (connectedMac ?: ""),
            "name" to connectedName,
            "firmwareVersion" to firmwareVersion,
            "capabilities" to HashMap(capabilities),
            "state" to "connected",
        )
        val result = pendingConnectResult
        pendingConnectResult = null
        // Flutter MethodChannel.Result must be used on the platform (main) thread.
        mainHandler.post {
            try {
                emit("connection", payload)
                result?.success(payload)
            } catch (e: Exception) {
                Log.e(TAG, "connect success reply failed: ${e.message}", e)
            }
        }
    }

    private fun failConnect(generation: Int, code: String, message: String) {
        if (generation != connectGeneration.get()) return
        invalidatePendingConnect(code, message, emitEvent = true)
    }

    /**
     * Answers the pending connect [MethodChannel.Result] at most once, on the main thread.
     * Also bumps [connectGeneration] when [bumpGeneration] is true so stale BLE callbacks stop.
     */
    private fun invalidatePendingConnect(
        code: String,
        message: String,
        emitEvent: Boolean,
        bumpGeneration: Boolean = false,
    ) {
        if (bumpGeneration) {
            connectGeneration.incrementAndGet()
        }
        if (!connectReplySent.compareAndSet(false, true)) {
            pendingConnectResult = null
            return
        }
        cancelConnectTimers()
        val result = pendingConnectResult
        pendingConnectResult = null
        mainHandler.post {
            try {
                if (emitEvent) {
                    emit(
                        "connection",
                        mapOf("state" to "error", "code" to code, "message" to message),
                    )
                }
                result?.error(code, message, null)
            } catch (e: Exception) {
                Log.e(TAG, "connect error reply failed: ${e.message}", e)
            }
        }
    }

    private fun cancelConnectTimers() {
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        connectTimeoutRunnable = null
        handshakeFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        handshakeFallbackRunnable = null
        personInfoFallbackRunnable?.let { mainHandler.removeCallbacks(it) }
        personInfoFallbackRunnable = null
    }

    private fun disconnect() {
        stopWorkoutMonitoring()
        cancelConnectTimers()
        invalidatePendingConnect(
            "disconnected",
            "Disconnected",
            emitEvent = false,
            bumpGeneration = true,
        )
        handshakeFinishing = false
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
        if (!isSdkConnected()) {
            result.success(null)
            return
        }
        try {
            VPOperateManager.getInstance().readBattery(
                noopWrite,
                object : IBatteryDataListener {
                    override fun onDataChange(data: BatteryData?) {
                        mainHandler.post {
                            try {
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
                            } catch (e: Exception) {
                                Log.e(TAG, "readBattery reply: ${e.message}", e)
                            }
                        }
                    }
                },
            )
        } catch (e: Exception) {
            Log.e(TAG, "readBattery: ${e.message}", e)
            result.success(null)
        }
    }

    private fun syncHealth(result: MethodChannel.Result) {
        if (!isSdkConnected()) {
            result.error("not_connected", "Wearable is not connected.", null)
            return
        }
        Thread {
            val out = HashMap<String, Any?>()
            out["sleepAvailable"] = true
            out["stepsAvailable"] = true

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

            mainHandler.post {
                try {
                    result.success(out)
                } catch (e: Exception) {
                    Log.e(TAG, "syncHealth reply: ${e.message}", e)
                }
            }
        }.start()
    }

    private fun startWorkoutMonitoring() {
        workoutMonitoringActive = true
        try {
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
        } catch (e: Exception) {
            Log.e(TAG, "startDetectHeart: ${e.message}", e)
            workoutMonitoringActive = false
        }
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
            try {
                eventSink?.success(mapOf("type" to type, "payload" to payload))
            } catch (e: Exception) {
                Log.w(TAG, "emit($type) failed: ${e.message}")
            }
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
