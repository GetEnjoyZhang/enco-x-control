import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var ble: BLEController

    var body: some View {
        NavigationStack {
            List {
                Section("连接状态") {
                    LabeledContent("蓝牙", value: ble.stateText)
                    LabeledContent("设备", value: ble.deviceName.isEmpty ? "未连接" : ble.deviceName)
                    LabeledContent("OPO 控制通道", value: ble.opoServiceFound ? "已发现" : "未发现")
                }

                Section("电量") {
                    HStack(spacing: 12) {
                        BatteryTile(title: "左耳", level: ble.battery.left)
                        BatteryTile(title: "右耳", level: ble.battery.right)
                        BatteryTile(title: "充电盒", level: ble.battery.caseLevel)
                    }
                    Button {
                        ble.queryBattery()
                    } label: {
                        Label("查询电量", systemImage: "battery.100")
                    }
                }

                Section("降噪模式") {
                    Button {
                        ble.setANC(.on)
                    } label: {
                        Label("开启降噪 (ANC)", systemImage: "waveform.path.ecg")
                    }
                    Button {
                        ble.setANC(.off)
                    } label: {
                        Label("关闭降噪", systemImage: "speaker.wave.2")
                    }
                    Button {
                        ble.setANC(.transparency)
                    } label: {
                        Label("通透模式", systemImage: "ear")
                    }
                }

                Section("发现的服务（诊断）") {
                    if ble.discoveredServices.isEmpty {
                        Text("尚未发现服务").foregroundStyle(.secondary)
                    } else {
                        ForEach(ble.discoveredServices, id: \.self) { uuid in
                            Text(uuid).font(.caption.monospaced())
                        }
                    }
                }

                Section("收发日志") {
                    if ble.logs.isEmpty {
                        Text("暂无日志").foregroundStyle(.secondary)
                    }
                    ForEach(ble.logs) { entry in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(entry.kind.rawValue)
                                .font(.caption2.bold())
                                .foregroundStyle(entry.kind == .tx ? Color.blue : (entry.kind == .rx ? Color.green : Color.secondary))
                            Text(entry.text)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                        }
                    }
                }

                Section("说明") {
                    Text("本 App 使用社区逆向的 OPOv1 BLE 协议（服务 0000079A）。如果“发现的服务”里看不到该服务，说明耳机在 iOS 上没有暴露 BLE 控制通道，本 App 无法替代官方欢律；此时请用耳机触控操作切换降噪。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Enco 控制")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("扫描") { ble.startScanning() }
                }
            }
        }
    }
}

private struct BatteryTile: View {
    let title: String
    let level: Int?

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(level.map { "\($0)%" } ?? "--")
                .font(.title3.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}
