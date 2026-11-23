# Enco 控制（iOS）

一个用 SwiftUI + CoreBluetooth 写的 iOS App 源码，目标是替代欢律做三件事：**连上耳机、看左右耳/充电盒电量、切换降噪/通透**。源码可直接编译成 IPA 侧载到 iPhone。

## 先说清楚能不能用（很重要）

- 这套代码使用社区逆向出来的 **OPOv1 BLE 协议**，控制服务是 `0000079A-D102-11E1-9B23-00025B00A5A5`。它在 OnePlus Nord Buds 3 Pro 上已确认可用，OPPO Enco X2 / Free2 / Air3 等型号被社区列为“很可能兼容”。
- **你手上的初代 Enco X（型号 ETI51，2020 年）不一定暴露这个 BLE 服务。** 很多 OPPO 耳机的控制通道走的是经典蓝牙 RFCOMM，而 iOS 不允许第三方 App 访问 RFCOMM，这种情况任何公开 API 都做不了。
- 所以：装好后先看 App 里的「发现的服务（诊断）」。能看到 `0000079A...` → 可以往下用；看不到 → 说明这台耳机在 iOS 上没有 BLE 控制通道，只能用耳机触控切降噪，或用 Android/Mac 上的社区工具。

## 文件说明

```
EncoXControl/
├── EncoXControl/
│   ├── EncoXControlApp.swift   # App 入口
│   ├── ContentView.swift       # 界面
│   ├── BLEController.swift     # CoreBluetooth 连接与协议时序
│   ├── OPOPackets.swift        # OPOv1 数据帧定义与电量解析
│   ├── Models.swift            # 数据模型
│   └── Info.plist              # 蓝牙权限声明
├── project.yml                 # XcodeGen 工程描述
├── ExportOptions.plist         # 导出 IPA 配置（可选）
├── build.sh                    # 一键打包脚本（可选，需 Mac）
├── .github/workflows/build-unsigned-ipa.yml  # 无 Mac 云端编译工作流
└── .gitignore
```

## 没有 Mac？用 GitHub Actions + Sideloadly（免费，推荐）

Xcode 只能在 macOS 上跑，但**不需要你买 Mac**：让 GitHub 的 macOS Runner 编译出**未签名 IPA**，再用 Windows 上的 Sideloadly 用你自己的 Apple ID 签名安装。

1. 注册 GitHub，新建一个仓库（建议 Public，macOS Runner 分钟数免费；Private 也有少量免费额度）。
2. 把本目录 `EncoXControl/` 下所有文件上传到仓库根目录，**保留 `.github/` 目录**（里面是编译工作流）。
3. 进仓库 → **Actions** → 找到 **Build unsigned IPA** → **Run workflow**，等 5~15 分钟。
4. 运行完成后点进这次 Run → **Artifacts** → 下载 `EncoXControl-unsigned`（是个 zip），解压得到 `EncoXControl-unsigned.ipa`。
5. Windows 上从 [sideloadly.io](https://sideloadly.io/) 下载安装 Sideloadly。Windows 需要先装 **Apple 官网版**的 iTunes 和 iCloud（不是 Microsoft Store 版）。
6. iPhone 数据线连电脑 → 解锁 → 弹窗点“信任此电脑”。iPhone 打开 **设置 → 隐私与安全性 → 开发者模式**（iOS 16+），按提示重启。
7. 打开 Sideloadly，把 IPA 拖进去，填 Apple ID（建议单独注册一个小号），点 **Start**，按提示输入密码和验证码。
8. 装好后到 iPhone **设置 → 通用 → VPN 与设备管理**，信任你的 Apple ID 描述文件，然后回桌面打开 App。

**限制**：免费 Apple ID 签的 App **7 天过期**，Sideloadly 可开自动刷新（电脑需保持开机，USB 或同一 Wi‑Fi）；同时最多装 3 个侧载 App；GitHub Artifact 下载链接 14 天后失效。只从你自己编译的仓库下载 IPA。

不想用 GitHub Actions，也可以租按天的云 Mac（约 $15/天）、用 Codemagic 的免费 macOS 分钟（每月 500 分钟），或按下面的方法在有 Mac 时编译。

## 编译方法（有 Mac 时）

需要在 Mac 上安装 Xcode。

### 方法一：Xcode 手动建工程（最稳）
1. Xcode → Create a new project → iOS → App，Interface 选 SwiftUI，Language 选 Swift。
2. 把 `EncoXControl/` 里的 5 个 `.swift` 文件和 `Info.plist` 拖进工程（勾选 Copy if needed）。
3. 选中 Target → Signing & Capabilities → Team 选你的 Apple ID（免费账号即可，签名 7 天有效）。
4. Target → Info 里确认 `Privacy - Bluetooth Always Usage Description` 存在（Info.plist 已写好）。
5. 连上真机，点 Run 直接安装；要 IPA 就 Archive → Distribute → Save as IPA。

### 方法二：用脚本一次性产出 IPA
```bash
brew install xcodegen          # 若尚未安装
cd EncoXControl
chmod +x build.sh
TEAM_ID=你的AppleTeamID ./build.sh
```
产物在 `build/ipa/EncoXControl.ipa`。可用 Xcode Devices and Simulators 或爱思/AltStore 等工具侧载。注意：**免费 Apple ID 签的 IPA 7 天后会掉签名**，需要重签；上架 App Store 需要付费开发者账号和审核，且这种逆向协议App通常过不了审核。

## 使用步骤

1. 先把耳机在系统蓝牙里配对连接好（参考之前说的 Enco X 配对步骤）。
2. 打开 App → 允许蓝牙权限 → 点右上角「扫描」。
3. 连上后 App 会自动发 HELLO → REGISTER 握手，日志区能看到 TX/RX 十六进制。
4. 点「查询电量」或「开启降噪 / 关闭降噪 / 通透模式」。
5. 如果命令发出但耳机没反应，把日志区内容复制出来，重点看有没有 `0000079A` 服务和 RX 回应。

## 协议致谢

数据帧定义来自以下公开逆向成果（MIT）：

- AasheeshLikePanner/cracked-oneplus-buds
- vedanth-jadhav/open-oneplus-buds（CoreBluetooth 实现参考）
- chiragverma11/melodyctl（OPOv1/RFCOMM 命令参考）

本项目与 OPPO、OnePlus、realme、欢律（HeyMelody）官方无关，仅用于个人设备控制研究。固件更新可能导致协议变化。
