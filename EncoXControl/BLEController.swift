import Foundation
import CoreBluetooth
import SwiftUI

final class BLEController: NSObject, ObservableObject {
    @Published private(set) var bluetoothState: CBManagerState = .unknown
    @Published private(set) var isConnected = false
    @Published private(set) var deviceName = ""
    @Published private(set) var opoServiceFound = false
    @Published private(set) var battery = BatteryStatus()
    @Published private(set) var logs: [LogEntry] = []
    @Published private(set) var discoveredServices: [String] = []

    var stateText: String {
        switch bluetoothState {
        case .poweredOn: return "已开启"
        case .poweredOff: return "已关闭"
        case .unauthorized: return "未授权（去系统设置打开蓝牙权限）"
        case .unsupported: return "不支持"
        case .resetting: return "重置中"
        case .unknown: return "未知"
        @unknown default: return "未知"
        }
    }

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var notifyCharacteristics: [CBCharacteristic] = []
    private var handshakeStarted = false
    private var handshakeDone = false
    private var pendingAction: (() -> Void)?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: .main)
    }

    // MARK: - 对外操作

    func startScanning() {
        guard central.state == .poweredOn else {
            addLog("蓝牙未就绪：\(stateText)", kind: .info)
            return
        }
        addLog("开始扫描附近耳机…", kind: .info)
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.central.stopScan()
            self?.addLog("扫描结束", kind: .info)
        }
    }

    func queryBattery() {
        ensureReady { [weak self] in
            self?.send(OPOPackets.batteryQuery, name: "BATTERY QUERY")
        }
    }

    func setANC(_ mode: ANCMode) {
        ensureReady { [weak self] in
            guard let self = self else { return }
            self.send(OPOPackets.ancQuery, name: "ANC QUERY")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.send(OPOPackets.ancSet(OPOPackets.modeByte(mode)), name: "ANC SET")
            }
        }
    }

    func disconnect() {
        if let peripheral = peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
    }

    // MARK: - 内部

    private func ensureReady(_ action: @escaping () -> Void) {
        pendingAction = action
        if handshakeDone {
            pendingAction?()
            pendingAction = nil
            return
        }
        if !isConnected {
            addLog("尚未连接耳机，请先点“扫描”", kind: .info)
            startScanning()
        }
    }

    private func startHandshake() {
        guard !handshakeStarted else { return }
        handshakeStarted = true
        addLog("发现 OPO 控制通道，开始握手…", kind: .info)

        send(OPOPackets.hello, name: "HELLO")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.send(OPOPackets.register, name: "REGISTER")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.6) { [weak self] in
            guard let self = self else { return }
            self.handshakeDone = true
            self.addLog("握手完成，可以下发命令", kind: .info)
            self.pendingAction?()
            self.pendingAction = nil
        }
    }

    private func send(_ bytes: [UInt8], name: String) {
        guard let peripheral = peripheral, let char = commandCharacteristic else {
            addLog("无法发送 \(name)：控制特征不可用", kind: .info)
            return
        }
        // OPOv1 要求 withoutResponse；用 .withResponse 会静默失败。
        peripheral.writeValue(Data(bytes), for: char, type: .withoutResponse)
        addLog("\(name): \(OPOPackets.hex(bytes))", kind: .tx)
    }

    private func addLog(_ text: String, kind: LogEntry.Kind) {
        DispatchQueue.main.async {
            self.logs.append(LogEntry(kind: kind, text: text))
            if self.logs.count > 80 {
                self.logs.removeFirst(self.logs.count - 80)
            }
        }
    }

    private func resetConnectionState() {
        isConnected = false
        opoServiceFound = false
        handshakeStarted = false
        handshakeDone = false
        commandCharacteristic = nil
        notifyCharacteristics.removeAll()
        discoveredServices.removeAll()
        deviceName = ""
        battery = BatteryStatus()
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEController: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        guard central.state == .poweredOn else { return }

        let connected = central.retrieveConnectedPeripherals(withServices: [OPOPackets.opoServiceUUID])
        if let first = connected.first {
            addLog("发现已连接设备：\(first.name ?? "未知")", kind: .info)
            peripheral = first
            first.delegate = self
            central.connect(first, options: nil)
        } else {
            startScanning()
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        let name = peripheral.name ?? ""
        let keywords = ["OPPO", "Enco", "OnePlus", "realme", "Buds"]
        guard keywords.contains(where: { name.localizedCaseInsensitiveContains($0) }) else { return }

        central.stopScan()
        addLog("找到设备：\(name)", kind: .info)
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        deviceName = peripheral.name ?? "未命名设备"
        addLog("已连接 \(deviceName)，正在发现服务…", kind: .info)
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        addLog("连接失败：\(error?.localizedDescription ?? "未知错误")", kind: .info)
        resetConnectionState()
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        addLog("设备已断开", kind: .info)
        resetConnectionState()
    }
}

// MARK: - CBPeripheralDelegate

extension BLEController: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            addLog("服务发现失败：\(error.localizedDescription)", kind: .info)
            return
        }
        let services = peripheral.services ?? []
        discoveredServices = services.map { $0.uuid.uuidString }
        addLog("发现 \(services.count) 个 BLE 服务", kind: .info)
        if services.isEmpty {
            addLog("未发现 BLE 服务：这款耳机可能只在经典蓝牙上提供控制通道，iOS 无法访问。", kind: .info)
        }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if let error = error {
            addLog("特征发现失败：\(error.localizedDescription)", kind: .info)
            return
        }
        for char in service.characteristics ?? [] {
            if char.uuid == OPOPackets.writeCharacteristicUUID {
                commandCharacteristic = char
                opoServiceFound = true
                addLog("找到 OPO 写入特征", kind: .info)
            }
            if char.properties.contains(.notify) || char.properties.contains(.indicate) {
                notifyCharacteristics.append(char)
                peripheral.setNotifyValue(true, for: char)
            }
        }
        if commandCharacteristic != nil && !handshakeDone {
            startHandshake()
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        if let error = error {
            addLog("读数失败：\(error.localizedDescription)", kind: .info)
            return
        }
        guard let data = characteristic.value else { return }
        let bytes = [UInt8](data)
        addLog("RX [\(characteristic.uuid.uuidString)]: \(OPOPackets.hex(bytes))", kind: .rx)

        if let parsed = OPOPackets.parseBattery(bytes) {
            battery = parsed
            addLog("电量已更新", kind: .info)
        }
    }
}
