package com.vytaltek.vytal_tek.qring

import android.app.Application
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import com.oudmon.ble.base.bluetooth.BleAction
import com.oudmon.ble.base.bluetooth.BleOperateManager
import com.oudmon.ble.base.bluetooth.DeviceManager
import com.oudmon.ble.base.bluetooth.QCBluetoothCallbackCloneReceiver
import com.oudmon.ble.base.communication.CommandHandle
import com.oudmon.ble.base.communication.Constants
import com.oudmon.ble.base.communication.ICommandResponse
import com.oudmon.ble.base.communication.LargeDataHandler
import com.oudmon.ble.base.communication.req.DeviceSupportReq
import com.oudmon.ble.base.communication.req.RealTimeHeartRate
import com.oudmon.ble.base.communication.req.SetTimeReq
import com.oudmon.ble.base.communication.req.SimpleKeyReq
import com.oudmon.ble.base.communication.rsp.RealTimeHeartRateRsp
import com.oudmon.ble.base.communication.rsp.BaseRspCmd
import com.oudmon.ble.base.communication.rsp.BatteryRsp
import com.oudmon.ble.base.communication.rsp.DeviceSupportFunctionRsp
import com.oudmon.ble.base.communication.rsp.HRVRsp
import com.oudmon.ble.base.communication.rsp.ReadHeartRateRsp
import com.oudmon.ble.base.communication.rsp.SetTimeRsp
import com.oudmon.ble.base.communication.bigData.BloodOxygenEntity
import com.oudmon.ble.base.communication.bigData.bean.IntervalTemperatureEntity
import com.oudmon.ble.base.bean.SleepDisplay
import com.oudmon.ble.base.communication.entity.BleStepTotal
import com.oudmon.ble.base.scan.BleScannerHelper
import com.oudmon.ble.base.scan.ScanRecord
import com.oudmon.ble.base.scan.ScanWrapperCallback
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

/**
 * Host for the official QRing Android AAR (`BleOperateManager`).
 *
 * Lifecycle mirrors the vendor sample: Application init → register callback
 * receiver → scan/connect → onServiceDiscovered → LargeDataHandler.initEnable →
 * SetTime + DeviceSupport before health queries.
 */
object QRingSdkHost : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {
    private const val TAG = "VytalQRing"
    private const val CONNECT_TIMEOUT_MS = 60_000L

    private lateinit var app: Application
    private val mainHandler = Handler(Looper.getMainLooper())

    @Volatile
    private var eventSink: EventChannel.EventSink? = null

    @Volatile
    private var capabilities: MutableMap<String, Any?> = defaultCapabilities()

    @Volatile
    private var firmwareVersion: String? = null

    @Volatile
    private var supportBlePair: Boolean = false

    @Volatile
    private var pendingConnectResult: MethodChannel.Result? = null

    private var connectTimeoutRunnable: Runnable? = null

    @Volatile
    private var workoutMonitoringActive = false

    private var workoutHrPollRunnable: Runnable? = null

    fun init(application: Application) {
        app = application
        BleOperateManager.getInstance(application)
        BleOperateManager.getInstance().init()
        BleOperateManager.getInstance().isBleLogEnabled = false

        ContextCompat.registerReceiver(
            application,
            GattReceiver(),
            BleAction.getIntentFilter(),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
        ContextCompat.registerReceiver(
            application,
            AdapterStateReceiver(),
            BleAction.getDeviceIntentFilter(),
            ContextCompat.RECEIVER_EXPORTED,
        )
        Log.i(TAG, "QRing SDK host initialized")
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
                if (deviceId.isNullOrBlank()) {
                    result.error("missing_device_id", "Device id required", null)
                } else {
                    connect(deviceId, result)
                }
            }
            "disconnect" -> {
                val unbind = call.argument<Boolean>("unbind") == true
                disconnect(unbind)
                result.success(null)
            }
            "isConnected" -> result.success(BleOperateManager.getInstance().isConnected)
            "getCapabilities" -> result.success(HashMap(capabilities))
            "readBattery" -> readBattery(result)
            "syncHealth" -> syncHealth(result)
            "startWorkoutMonitoring" -> {
                if (!BleOperateManager.getInstance().isConnected) {
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
        BleScannerHelper.getInstance().reSetCallback()
        BleScannerHelper.getInstance().setTimeOut(timeoutMs / 1000)
        BleScannerHelper.getInstance().scanDevice(
            app,
            null,
            object : ScanWrapperCallback {
                override fun onStart() {}
                override fun onStop() {
                    emit("scanStopped", emptyMap<String, Any>())
                }

                override fun onLeScan(device: BluetoothDevice?, rssi: Int, scanRecord: ByteArray?) {
                    if (device == null) return
                    val name = device.name ?: return
                    if (name.isBlank()) return
                    emit(
                        "scanResult",
                        mapOf(
                            "deviceId" to device.address,
                            "name" to name,
                            "rssi" to rssi,
                        ),
                    )
                }

                override fun onScanFailed(errorCode: Int) {
                    emit(
                        "error",
                        mapOf("code" to "scan_failed", "message" to "Scan failed ($errorCode)"),
                    )
                }

                override fun onParsedData(device: BluetoothDevice?, scanRecord: ScanRecord?) {}
                override fun onBatchScanResults(results: MutableList<android.bluetooth.le.ScanResult>?) {}
            },
        )
        mainHandler.postDelayed({ stopScan() }, timeoutMs.toLong())
    }

    private fun stopScan() {
        try {
            BleScannerHelper.getInstance().stopScan(app)
        } catch (e: Exception) {
            Log.w(TAG, "stopScan: ${e.message}")
        }
    }

    private fun connect(deviceId: String, result: MethodChannel.Result) {
        stopScan()
        pendingConnectResult?.error("cancelled", "Superseded by a new connect", null)
        pendingConnectResult = result
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        val timeout = Runnable {
            failConnect("connect_timeout", "Connecting timed out. Keep the ring nearby and try again.")
            try {
                BleOperateManager.getInstance().disconnect()
            } catch (_: Exception) {
            }
        }
        connectTimeoutRunnable = timeout
        mainHandler.postDelayed(timeout, CONNECT_TIMEOUT_MS)
        DeviceManager.getInstance().deviceAddress = deviceId
        BleOperateManager.getInstance().connectDirectly(deviceId)
    }

    private fun disconnect(unbind: Boolean) {
        try {
            if (unbind || supportBlePair) {
                BleOperateManager.getInstance().unBindDevice()
            } else {
                BleOperateManager.getInstance().disconnect()
            }
        } catch (e: Exception) {
            Log.w(TAG, "disconnect: ${e.message}")
        }
    }

    private fun onServiceReady() {
        LargeDataHandler.getInstance().initEnable()
        runHandshake()
    }

    private fun runHandshake() {
        val setTimeLatch = CountDownLatch(1)
        val supportLatch = CountDownLatch(1)
        val setTime = AtomicReference<SetTimeRsp?>()
        val support = AtomicReference<DeviceSupportFunctionRsp?>()

        CommandHandle.getInstance().executeReqCmd(
            SetTimeReq(1),
            ICommandResponse<SetTimeRsp> { rsp ->
                setTime.set(rsp)
                setTimeLatch.countDown()
            },
        )
        CommandHandle.getInstance().executeReqCmd(
            DeviceSupportReq.getReadInstance(),
            ICommandResponse<DeviceSupportFunctionRsp> { rsp ->
                support.set(rsp)
                supportLatch.countDown()
            },
        )

        Thread {
            setTimeLatch.await(8, TimeUnit.SECONDS)
            supportLatch.await(8, TimeUnit.SECONDS)
            mainHandler.post {
                mergeCapabilities(setTime.get(), support.get())
                supportBlePair = support.get()?.supportBlePair == true
                if (supportBlePair) {
                    try {
                        BleOperateManager.getInstance().bleCreateBond()
                    } catch (e: Exception) {
                        Log.w(TAG, "bleCreateBond: ${e.message}")
                    }
                }
                try {
                    CommandHandle.getInstance().executeReqCmd(
                        SimpleKeyReq(Constants.CMD_BIND_SUCCESS),
                        null,
                    )
                } catch (_: Exception) {
                }
                completeConnectSuccess()
            }
        }.start()
    }

    private fun mergeCapabilities(setTime: SetTimeRsp?, support: DeviceSupportFunctionRsp?) {
        val map = defaultCapabilities()
        if (setTime != null) {
            map["supportTemperature"] = setTime.mSupportTemperature
            map["supportBloodOxygen"] = setTime.mSupportBloodOxygen
            map["supportBloodPressure"] = setTime.mSupportBloodPressure
            map["supportManualHeart"] = setTime.mSupportManualHeart
            map["supportHrv"] = setTime.mSupportHrv
            map["supportPressure"] = setTime.mSupportPressure
            map["supportManualBloodOxygen"] = setTime.mSupportManualBloodOxygen
            map["supportAppMeasure"] = setTime.mSupportAppMeasure
            map["supportNewSleepProtocol"] = setTime.mNewSleepProtocol
        }
        if (support != null) {
            map["supportHeart"] = support.supportHeart
            map["supportIntervalHeartRate"] = support.supportIntervalHeartRate
            map["supportIntervalBloodOxygen"] = support.supportIntervalBloodOxygen
            map["supportIntervalTemperature"] = support.supportIntervalTemperature
            map["supportSkinTemperature"] = support.supportSkinTemperature
            map["supportEcg"] = support.supportEcg
            map["supportBlePair"] = support.supportBlePair
        }
        // Heart family: SetTime may not set supportHeart; DeviceSupport does.
        if (setTime?.mSupportManualHeart == true || setTime?.mSupportAppMeasure == true) {
            map["supportHeart"] = true
        }
        capabilities = map
    }

    private fun completeConnectSuccess() {
        connectTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        connectTimeoutRunnable = null
        val deviceId = DeviceManager.getInstance().deviceAddress ?: ""
        val name = DeviceManager.getInstance().deviceName ?: "QRing"
        val payload = hashMapOf<String, Any?>(
            "deviceId" to deviceId,
            "name" to name,
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

    private fun readBattery(result: MethodChannel.Result) {
        if (!BleOperateManager.getInstance().isConnected) {
            result.success(null)
            return
        }
        CommandHandle.getInstance().executeReqCmd(
            SimpleKeyReq(Constants.CMD_GET_DEVICE_ELECTRICITY_VALUE),
            ICommandResponse<BatteryRsp> { rsp ->
                mainHandler.post {
                    if (rsp.status == BaseRspCmd.RESULT_OK) {
                        result.success(
                            mapOf(
                                "percent" to rsp.batteryValue,
                                "charging" to rsp.isCharging,
                            ),
                        )
                    } else {
                        result.success(null)
                    }
                }
            },
        )
    }

    private fun syncHealth(result: MethodChannel.Result) {
        if (!BleOperateManager.getInstance().isConnected) {
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
                val ref = AtomicReference<BatteryRsp?>()
                CommandHandle.getInstance().executeReqCmd(
                    SimpleKeyReq(Constants.CMD_GET_DEVICE_ELECTRICITY_VALUE),
                    ICommandResponse<BatteryRsp> { rsp ->
                        ref.set(rsp)
                        latch.countDown()
                    },
                )
                if (latch.await(5, TimeUnit.SECONDS)) {
                    val rsp = ref.get()
                    if (rsp != null && rsp.status == BaseRspCmd.RESULT_OK) {
                        out["battery"] = mapOf(
                            "percent" to rsp.batteryValue,
                            "charging" to rsp.isCharging,
                        )
                    }
                }
            }

            // Heart rate — last non-zero from today history (never invent).
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<ReadHeartRateRsp?>()
                BleOperateManager.getInstance().getTodayHeartRate(
                    object : BleOperateManager.HealthDataCallback<ReadHeartRateRsp> {
                        override fun onSuccess(data: ReadHeartRateRsp?) {
                            ref.set(data)
                            latch.countDown()
                        }

                        override fun onError(code: Int, message: String?) {
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    lastNonZero(ref.get()?.array)?.let { out["heartRateBpm"] = it }
                }
            }

            // HRV — last positive sample from byte array when present.
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<HRVRsp?>()
                BleOperateManager.getInstance().getTodayHrv(
                    object : BleOperateManager.HealthDataCallback<HRVRsp> {
                        override fun onSuccess(data: HRVRsp?) {
                            ref.set(data)
                            latch.countDown()
                        }

                        override fun onError(code: Int, message: String?) {
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    lastPositiveByte(ref.get()?.hrvArray)?.let { out["hrvMs"] = it }
                }
            }

            // SpO2
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<BloodOxygenEntity?>()
                BleOperateManager.getInstance().getTodayBloodOxygen(
                    object : BleOperateManager.HealthDataCallback<BloodOxygenEntity> {
                        override fun onSuccess(data: BloodOxygenEntity?) {
                            ref.set(data)
                            latch.countDown()
                        }

                        override fun onError(code: Int, message: String?) {
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    lastNonZero(ref.get()?.array)?.let { out["spo2Percent"] = it }
                }
            }

            // Temperature
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<IntervalTemperatureEntity?>()
                BleOperateManager.getInstance().getTodayTemperature(
                    object : BleOperateManager.HealthDataCallback<IntervalTemperatureEntity> {
                        override fun onSuccess(data: IntervalTemperatureEntity?) {
                            ref.set(data)
                            latch.countDown()
                        }

                        override fun onError(code: Int, message: String?) {
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    lastPositiveFloat(ref.get()?.array)?.let { out["temperatureCelsius"] = it }
                }
            }

            // Sleep duration (minutes from SDK total)
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<SleepDisplay?>()
                BleOperateManager.getInstance().getTodaySleep(
                    object : BleOperateManager.HealthDataCallback<SleepDisplay> {
                        override fun onSuccess(data: SleepDisplay?) {
                            ref.set(data)
                            latch.countDown()
                        }

                        override fun onError(code: Int, message: String?) {
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    val minutes = ref.get()?.totalSleepDuration ?: 0
                    if (minutes > 0) out["sleepMinutes"] = minutes
                }
            }

            // Steps / calories / distance
            runCatching {
                val latch = CountDownLatch(1)
                val ref = AtomicReference<BleStepTotal?>()
                BleOperateManager.getInstance().getTodayStepTotal(
                    object : BleOperateManager.HealthDataCallback<BleStepTotal> {
                        override fun onSuccess(data: BleStepTotal?) {
                            ref.set(data)
                            latch.countDown()
                        }

                        override fun onError(code: Int, message: String?) {
                            latch.countDown()
                        }
                    },
                )
                if (latch.await(8, TimeUnit.SECONDS)) {
                    val total = ref.get()
                    if (total != null) {
                        if (total.totalSteps > 0) out["steps"] = total.totalSteps
                        if (total.calorie > 0) out["calories"] = total.calorie
                        if (total.walkDistance > 0) out["distanceMeters"] = total.walkDistance
                    }
                }
            }

            mainHandler.post { result.success(out) }
        }.start()
    }

    private fun lastNonZero(values: List<Int>?): Int? {
        if (values == null) return null
        for (i in values.indices.reversed()) {
            val v = values[i]
            if (v > 0) return v
        }
        return null
    }

    private fun lastPositiveByte(bytes: ByteArray?): Int? {
        if (bytes == null) return null
        for (i in bytes.indices.reversed()) {
            val v = bytes[i].toInt() and 0xFF
            if (v > 0) return v
        }
        return null
    }

    private fun lastPositiveFloat(values: List<Float>?): Double? {
        if (values == null) return null
        for (i in values.indices.reversed()) {
            val v = values[i]
            if (v > 0f) return v.toDouble()
        }
        return null
    }

    private fun emit(type: String, payload: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(mapOf("type" to type, "payload" to payload))
        }
    }

    private fun startWorkoutMonitoring() {
        workoutMonitoringActive = true
        sendRealTimeHeartCommand(1)
        scheduleHrPoll()
    }

    private fun stopWorkoutMonitoring() {
        workoutMonitoringActive = false
        workoutHrPollRunnable?.let { mainHandler.removeCallbacks(it) }
        workoutHrPollRunnable = null
        sendRealTimeHeartCommand(2)
    }

    private fun sendRealTimeHeartCommand(type: Int) {
        try {
            CommandHandle.getInstance().executeReqCmd(
                RealTimeHeartRate(type),
                null,
            )
        } catch (e: Exception) {
            Log.w(TAG, "RealTimeHeartRate($type): ${e.message}")
        }
    }

    private fun scheduleHrPoll() {
        workoutHrPollRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = object : Runnable {
            override fun run() {
                if (!workoutMonitoringActive) return
                pollRealTimeHeart()
                mainHandler.postDelayed(this, 2000)
            }
        }
        workoutHrPollRunnable = runnable
        mainHandler.post(runnable)
    }

    private fun pollRealTimeHeart() {
        val latch = CountDownLatch(1)
        val ref = AtomicReference<RealTimeHeartRateRsp?>()
        try {
            CommandHandle.getInstance().executeReqCmd(
                RealTimeHeartRate(3),
                ICommandResponse<RealTimeHeartRateRsp> { rsp ->
                    ref.set(rsp)
                    latch.countDown()
                },
            )
            if (latch.await(3, TimeUnit.SECONDS)) {
                val hr = ref.get()?.heart ?: 0
                if (hr > 0) {
                    emit("heartRateUpdate", mapOf("bpm" to hr))
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "pollRealTimeHeart: ${e.message}")
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

    private class GattReceiver : QCBluetoothCallbackCloneReceiver() {
        override fun connectStatue(device: BluetoothDevice?, connected: Boolean) {
            if (device != null && connected) {
                if (device.name != null) {
                    DeviceManager.getInstance().deviceName = device.name
                }
                DeviceManager.getInstance().deviceAddress = device.address
            } else {
                emit(
                    "connection",
                    mapOf("state" to "disconnected"),
                )
            }
        }

        override fun onServiceDiscovered() {
            Log.i(TAG, "GATT services discovered")
            onServiceReady()
        }

        override fun onCharacteristicRead(uuid: String?, data: ByteArray?) {
            if (uuid != null && data != null) {
                val version = String(data, Charsets.UTF_8)
                if (uuid.contains("firmware", ignoreCase = true) ||
                    uuid.equals(com.oudmon.ble.base.communication.Constants.CHAR_FIRMWARE_REVISION.toString(), ignoreCase = true)
                ) {
                    firmwareVersion = version
                }
            }
        }

        override fun onCharacteristicChange(address: String?, uuid: String?, data: ByteArray?) {}
    }

    private class AdapterStateReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == BluetoothAdapter.ACTION_STATE_CHANGED) {
                val state = intent.getIntExtra(BluetoothAdapter.EXTRA_STATE, -1)
                if (state == BluetoothAdapter.STATE_OFF) {
                    BleOperateManager.getInstance().setBluetoothTurnOff(false)
                    emit("connection", mapOf("state" to "disconnected"))
                } else if (state == BluetoothAdapter.STATE_ON) {
                    BleOperateManager.getInstance().setBluetoothTurnOff(true)
                }
            }
        }
    }
}
