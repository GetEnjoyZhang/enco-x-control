import Foundation
import CoreBluetooth

/// OPOv1 协议包定义。
/// 字节序列来自社区逆向项目 open-oneplus-buds（MIT），原始实现见 README 中的致谢链接。
enum OPOPackets {
    static let opoServiceUUID = CBUUID(string: "0000079A-D102-11E1-9B23-00025B00A5A5")
    static let writeCharacteristicUUID = CBUUID(string: "0100079A-D102-11E1-9B23-00025B00A5A5")
    static let notifyCharacteristicUUID = CBUUID(string: "0200079A-D102-11E1-9B23-00025B00A5A5")
    static let fe2cServiceUUID = CBUUID(string: "FE2C123A-8366-4814-8EB0-01DE32100BEA")

    // 会话握手
    static let hello: [UInt8] = [0xAA, 0x07, 0x00, 0x00, 0x00, 0x01, 0x23, 0x00, 0x00, 0x12]
    static let register: [UInt8] = [0xAA, 0x0C, 0x00, 0x00, 0x00, 0x85, 0x41, 0x05, 0x00, 0x00,
                                    0xB5, 0x50, 0xA0, 0x69]

    // 查询
    static let batteryQuery: [UInt8] = [0xAA, 0x07, 0x00, 0x00, 0x06, 0x01, 0x25, 0x00, 0x00]
    static let ancQuery: [UInt8] = [0xAA, 0x09, 0x00, 0x00, 0x04, 0x82, 0x44, 0x02, 0x00, 0x00, 0xF2]

    // 降噪档位：01=降噪开，04=降噪关，02=通透
    static func ancSet(_ mode: UInt8) -> [UInt8] {
        [0xAA, 0x0A, 0x00, 0x00, 0x04, 0x04, 0x42, 0x03, 0x00, 0x01, 0x01, mode]
    }

    static func modeByte(_ mode: ANCMode) -> UInt8 {
        switch mode {
        case .on: return 0x01
        case .off: return 0x04
        case .transparency: return 0x02
        }
    }

    /// 电量回应特征：CAT=0x06, SUB=0x81；左耳 bytes[12]，右耳 bytes[14]，盒 bytes[15]。
    static func parseBattery(_ bytes: [UInt8]) -> BatteryStatus? {
        guard bytes.count >= 16, bytes[4] == 0x06, bytes[5] == 0x81 else { return nil }
        func level(_ raw: UInt8) -> Int? { raw <= 100 ? Int(raw) : nil }
        return BatteryStatus(left: level(bytes[12]),
                             right: level(bytes[14]),
                             caseLevel: level(bytes[15]))
    }

    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
