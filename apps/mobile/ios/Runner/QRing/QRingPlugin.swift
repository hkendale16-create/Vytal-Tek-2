import CoreBluetooth
import Flutter
import Foundation
import UIKit

/// iOS host for QCBandSDK + CoreBluetooth scan/connect.
///
/// QCBandSDK binds an already-connected CBPeripheral via
/// `QCSDKManager.addPeripheral`. Scan/connect use CoreBluetooth; health
/// commands use `QCSDKCmdCreator` after `setTime` capability handshake.
final class QRingPlugin: NSObject {
  static let methodChannelName = "com.vytaltek.qring/methods"
  static let eventChannelName = "com.vytaltek.qring/events"

  private let methodChannel: FlutterMethodChannel
  private let eventChannel: FlutterEventChannel
  private var eventSink: FlutterEventSink?

  private var central: CBCentralManager?
  private var peripheralsById: [String: CBPeripheral] = [:]
  private var connectedPeripheral: CBPeripheral?
  private var pendingConnectResult: FlutterResult?
  private var connectTimeoutWork: DispatchWorkItem?
  private var scanStopWork: DispatchWorkItem?

  private var capabilities: [String: Any] = QRingPlugin.defaultCapabilities()
  private var lastDeviceName: String = "QRing"

  init(messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: QRingPlugin.methodChannelName, binaryMessenger: messenger)
    eventChannel = FlutterEventChannel(name: QRingPlugin.eventChannelName, binaryMessenger: messenger)
    super.init()
    methodChannel.setMethodCallHandler(handle)
    eventChannel.setStreamHandler(self)
  }

  static func register(with registrar: FlutterPluginRegistrar) {
    _ = QRingPlugin(messenger: registrar.messenger())
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(true)
    case "initialize":
      ensureCentral()
      result(nil)
    case "startScan":
      let args = call.arguments as? [String: Any]
      let timeoutMs = args?["timeoutMs"] as? Int ?? 12_000
      startScan(timeoutMs: timeoutMs)
      result(nil)
    case "stopScan":
      stopScan()
      result(nil)
    case "connect":
      let args = call.arguments as? [String: Any]
      guard let deviceId = args?["deviceId"] as? String, !deviceId.isEmpty else {
        result(FlutterError(code: "missing_device_id", message: "Device id required", details: nil))
        return
      }
      connect(deviceId: deviceId, result: result)
    case "disconnect":
      disconnect()
      result(nil)
    case "isConnected":
      result(connectedPeripheral?.state == .connected)
    case "getCapabilities":
      result(capabilities)
    case "readBattery":
      readBattery(result: result)
    case "syncHealth":
      syncHealth(result: result)
    case "startWorkoutMonitoring":
      QCSDKManager.shareInstance().realTimeHeartRate = { [weak self] hr in
        if hr > 0 {
          self?.emit(type: "heartRateUpdate", payload: ["bpm": hr])
        }
      }
      QCSDKCmdCreator.beginRealTimeHeartRateSuccess({ result(nil) }, fail: {
        result(FlutterError(code: "workout_failed", message: "Could not start heart-rate monitoring.", details: nil))
      })
    case "stopWorkoutMonitoring":
      QCSDKManager.shareInstance().realTimeHeartRate = nil
      QCSDKCmdCreator.endRealTimeHeartRateSuccess({ result(nil) }, fail: { result(nil) })
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ensureCentral() {
    if central == nil {
      central = CBCentralManager(delegate: self, queue: .main, options: nil)
    }
  }

  private func startScan(timeoutMs: Int) {
    ensureCentral()
    stopScan()
    guard let central, central.state == .poweredOn else {
      emit(type: "error", payload: [
        "code": "bluetooth_off",
        "message": "Bluetooth is turned off. Turn it on, then try again.",
      ])
      return
    }
    central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    let work = DispatchWorkItem { [weak self] in self?.stopScan() }
    scanStopWork = work
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: work)
  }

  private func stopScan() {
    scanStopWork?.cancel()
    scanStopWork = nil
    central?.stopScan()
    emit(type: "scanStopped", payload: [:])
  }

  private func connect(deviceId: String, result: @escaping FlutterResult) {
    ensureCentral()
    stopScan()
    pendingConnectResult?(.error(FlutterError(code: "cancelled", message: "Superseded", details: nil)))
    pendingConnectResult = result

    let timeout = DispatchWorkItem { [weak self] in
      self?.failConnect(code: "connect_timeout", message: "Connecting timed out. Keep the ring nearby and try again.")
    }
    connectTimeoutWork = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: timeout)

    if let peripheral = peripheralsById[deviceId] {
      central?.connect(peripheral, options: nil)
      return
    }

    // Reconnect by UUID if previously seen this session.
    if let uuid = UUID(uuidString: deviceId) {
      let known = central?.retrievePeripherals(withIdentifiers: [uuid]) ?? []
      if let peripheral = known.first {
        peripheralsById[deviceId] = peripheral
        central?.connect(peripheral, options: nil)
        return
      }
    }

    failConnect(code: "device_not_nearby", message: "We couldn’t find that wearable. Scan again while it is nearby.")
  }

  private func disconnect() {
    if let peripheral = connectedPeripheral {
      QCSDKManager.shareInstance().removePeripheral(peripheral)
      central?.cancelPeripheralConnection(peripheral)
    }
    connectedPeripheral = nil
  }

  private func bindAndHandshake(peripheral: CBPeripheral) {
    QCSDKManager.shareInstance().addPeripheral(peripheral) { [weak self] ok in
      guard let self else { return }
      guard ok else {
        self.failConnect(code: "bind_failed", message: "Could not bind to the wearable SDK session.")
        return
      }
      QCSDKCmdCreator.setTime(Date(), success: { featureList in
        self.capabilities = self.mapFeatureList(featureList)
        let payload: [String: Any] = [
          "state": "connected",
          "deviceId": peripheral.identifier.uuidString,
          "name": self.lastDeviceName,
          "capabilities": self.capabilities,
        ]
        self.connectTimeoutWork?.cancel()
        self.connectTimeoutWork = nil
        self.emit(type: "connection", payload: payload)
        self.pendingConnectResult?(payload)
        self.pendingConnectResult = nil
      }, failed: {
        self.failConnect(code: "handshake_failed", message: "Capability handshake failed. Try reconnecting.")
      })
    }
  }

  private func mapFeatureList(_ featureList: [AnyHashable: Any]?) -> [String: Any] {
    var map = QRingPlugin.defaultCapabilities()
    guard let featureList else { return map }

    func on(_ key: String) -> Bool {
      if let value = featureList[key] as? String {
        return value == "1" || value.lowercased() == "true"
      }
      if let value = featureList[key] as? NSNumber {
        return value.intValue == 1
      }
      return false
    }

    // Keys from QCDFU_Utils / setTime docs.
    map["supportTemperature"] = on(QCBandFeatureTemperature)
    map["supportBloodOxygen"] = on(QCBandFeatureBloodOxygen)
    map["supportBloodPressure"] = on(QCBandFeatureBloodPressure)
    map["supportManualHeart"] = on(QCBandFeatureManualHeartRate)
    map["supportAppMeasure"] = on(QCBandFeatureAppManual)
    map["supportManualBloodOxygen"] = on(QCBandFeatureManualBloodOxygen)
    map["supportHrv"] = on(QCBandFeatureHRV)
    map["supportPressure"] = on(QCBandFeatureStress)
    map["supportNewSleepProtocol"] = on(QCBandFeatureNewSleepProtocol)
    map["supportHeart"] = on(QCBandFeatureManualHeartRate) || on(QCBandFeatureAppManual)
    return map
  }

  private func readBattery(result: @escaping FlutterResult) {
    QCSDKCmdCreator.readBatterySuccess({ battery, charging in
      // Docs historically used a 0–8 level on some firmware; current API returns percent.
      let percent: Int
      let rawLevel: Int?
      if battery >= 0 && battery <= 8 {
        percent = Int((Double(battery) / 8.0 * 100.0).rounded())
        rawLevel = Int(battery)
      } else {
        percent = Int(battery)
        rawLevel = nil
      }
      result([
        "percent": percent,
        "charging": charging,
        "rawLevel": rawLevel as Any,
      ])
    }, failed: {
      result(nil)
    })
  }

  private func syncHealth(result: @escaping FlutterResult) {
    guard connectedPeripheral?.state == .connected else {
      result(FlutterError(code: "not_connected", message: "Wearable is not connected.", details: nil))
      return
    }

    var out: [String: Any] = [
      "sleepAvailable": true,
      "stepsAvailable": true,
    ]
    let group = DispatchGroup()

    group.enter()
    QCSDKCmdCreator.readBatterySuccess({ battery, charging in
      let percent: Int
      let rawLevel: Int?
      if battery >= 0 && battery <= 8 {
        percent = Int((Double(battery) / 8.0 * 100.0).rounded())
        rawLevel = Int(battery)
      } else {
        percent = Int(battery)
        rawLevel = nil
      }
      out["battery"] = [
        "percent": percent,
        "charging": charging,
        "rawLevel": rawLevel as Any,
      ]
      group.leave()
    }, failed: { group.leave() })

    group.enter()
    QCSDKCmdCreator.getSchedualHeartRateData(withDayIndexs: [0], success: { models in
      if let model = models?.first,
         let rates = model.heartRates as? [NSNumber],
         let last = rates.reversed().first(where: { $0.intValue > 0 }) {
        out["heartRateBpm"] = last.intValue
      }
      group.leave()
    }, fail: { group.leave() })

    group.enter()
    QCSDKCmdCreator.getCurrentSportSucess({ sport in
      if let sport {
        if sport.totalStepCount > 0 { out["steps"] = sport.totalStepCount }
        if sport.calories > 0 { out["calories"] = Int(sport.calories) }
        if sport.distance > 0 { out["distanceMeters"] = sport.distance }
      }
      group.leave()
    }, failed: { group.leave() })

    group.enter()
    QCSDKCmdCreator.getSleepDetailData(byDay: 0, sleepDatas: { sleeps in
      if let sleeps {
        let minutes = QCSleepModel.sleepDuration(sleeps)
        if minutes > 0 { out["sleepMinutes"] = minutes }
      }
      group.leave()
    }, fail: { group.leave() })

    group.enter()
    QCSDKCmdCreator.getBloodOxygenData(byDayIndex: 0) { samples, _ in
      if let samples = samples as? [QCBloodOxygenModel] {
        if let last = samples.reversed().first(where: { $0.soa2 > 0 }) {
          out["spo2Percent"] = Int(last.soa2.rounded())
        }
      }
      group.leave()
    }

    // Temperature / HRV are optional — omit when unsupported or empty.
    group.notify(queue: .main) {
      result(out)
    }
  }

  private func failConnect(code: String, message: String) {
    connectTimeoutWork?.cancel()
    connectTimeoutWork = nil
    emit(type: "connection", payload: ["state": "error", "code": code, "message": message])
    pendingConnectResult?(FlutterError(code: code, message: message, details: nil))
    pendingConnectResult = nil
  }

  private func emit(type: String, payload: [String: Any]) {
    eventSink?(["type": type, "payload": payload])
  }

  private static func defaultCapabilities() -> [String: Any] {
    [
      "supportHeart": false,
      "supportAppMeasure": false,
      "supportManualHeart": false,
      "supportIntervalHeartRate": false,
      "supportHrv": false,
      "supportBloodOxygen": false,
      "supportManualBloodOxygen": false,
      "supportIntervalBloodOxygen": false,
      "supportTemperature": false,
      "supportSkinTemperature": false,
      "supportIntervalTemperature": false,
      "supportPressure": false,
      "supportBloodPressure": false,
      "supportNewSleepProtocol": false,
      "supportEcg": false,
      "supportBlePair": false,
      "supportFirmwareUpdate": true,
    ]
  }
}

extension QRingPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

extension QRingPlugin: CBCentralManagerDelegate, CBPeripheralDelegate {
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state != .poweredOn {
      emit(type: "connection", payload: ["state": "disconnected"])
    }
  }

  func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber
  ) {
    let name = peripheral.name
      ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String)
    guard let name, !name.isEmpty else { return }
    let id = peripheral.identifier.uuidString
    peripheralsById[id] = peripheral
    emit(type: "scanResult", payload: [
      "deviceId": id,
      "name": name,
      "rssi": RSSI.intValue,
    ])
  }

  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    connectedPeripheral = peripheral
    lastDeviceName = peripheral.name ?? lastDeviceName
    peripheral.delegate = self
    bindAndHandshake(peripheral: peripheral)
  }

  func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    failConnect(
      code: "connect_failed",
      message: error?.localizedDescription ?? "Could not connect to the wearable."
    )
  }

  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    if connectedPeripheral?.identifier == peripheral.identifier {
      connectedPeripheral = nil
    }
    emit(type: "connection", payload: ["state": "disconnected"])
  }
}
