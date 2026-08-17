### 1. Demo Guide

**QCBandSDK Demo 使用说明**

1. Scan and connect the ring.  
   扫描并连接戒指。
2. Open **SDK Sample Home** (`QCSampleHomeViewController`).  
   进入 **SDK 示例首页**（`QCSampleHomeViewController`）。
3. Select a feature and review SDK calls and responses in the log panel.  
   点击对应功能项，在日志面板查看 SDK 调用与返回。

**Documentation:** `iOS SDK SDK Development Guide.pdf`, maintained with
`QCBandSDK/iOS SDK SDK Development Guide.md`; see `QCBandSDK/iOS SDK开发指南.md` for Chinese.  
**开发文档：** `iOS SDK SDK Development Guide.pdf`
与 `QCBandSDK/iOS SDK SDK Development Guide.md` 同步维护；中文内容见
`QCBandSDK/iOS SDK开发指南.md`。

### 2. Demo Modules

**示例模块索引**

| Entry<br>首页入口 | Class<br>示例类 | Description<br>说明 |
|---------|--------|------|
| Scan & Connect<br>扫描连接 | `QCScanViewController` | BLE scanning and binding<br>BLE 扫描与绑定 |
| Health Settings<br>健康设置 | `QCSampleHealthSettingsViewController` | Heart rate, blood oxygen, and other health features<br>心率、血氧等健康功能 |
| Touch & Gestures<br>触摸/手势 | `QCSampleTouchGesturesViewController` | Touch/gesture + ring FlipWrist model APIs<br>触摸/手势 + 戒指翻腕模型接口 |
| BLE Update<br>通过 BLE 更新 | `QCSampleFirmwareUpdateViewController` | Main firmware OTA (`syncOtaBinData`)<br>主固件 OTA |
| **Resource Update**<br>**资源升级** | `QCSampleResourceUpdateViewController` | `getNeededFileListFinished` + `syncResourceFileName` |
| Display / Device / Notifications / Advanced<br>显示 / 设备 / 通知 / 高级 | Matching `QCSample*ViewController` | Display Palm uses band raise-to-wake (`getFlipWristInfo` / `setFlipWristOn`). See guide §3.57–3.58 (CN) / §3.69–3.70 (EN)<br>显示页抬腕用手环接口；详见开发指南 |

### 3. Activity & Sleep Scores

**活动与睡眠评分演示**

- **Health Settings → Activity & Steps → Today’s Steps & Activity Score**: enter age,
  read today’s steps, and display a score from 0 to 100 with its level.  
  **健康设置 → 活动步数 → 今日步数与活动得分**：输入年龄，读取今日总步数并输出
  0～100 活动得分及等级。
- **Health Settings → Sleep → Today’s Sleep Score & Efficiency**: analyze today’s main
  sleep only; naps are excluded.  
  **健康设置 → 睡眠 → 今日睡眠评分与效率**：仅分析今日主睡眠；小睡不参与计算。
- Calculations are centralized in `Utils/QCSampleHealthScoreUtils`. Scores are Demo-side
  display logic rather than device-returned fields.  
  计算逻辑统一封装在 `Utils/QCSampleHealthScoreUtils`。评分属于 Demo 展示逻辑，
  不是设备直接返回字段。

### 4. Resource Update

**资源升级演示**

Entry: **Firmware Update → Resource Update**.  
入口：**固件更新 → 资源升级**。

Recommended flow:  
推荐流程：

1. **Step 1** — Use `setTime` to check related features (e.g. `QCBandFeatureTouchControl`).  
   **步骤 1** — 使用 `setTime` 检查相关能力（如 `QCBandFeatureTouchControl`）。
2. **Step 2** — Use `getNeededFileListFinished` to retrieve missing resource filenames.  
   **步骤 2** — 使用 `getNeededFileListFinished` 查看缺失资源文件名。
3. **Step 3** — When files are missing, load
   `TP_resource/RT08_TP_FILE_0x1FD4_250106_01` from the Bundle and upload it.  
   **步骤 3** — 缺失列表非空时，从 Bundle 读取
   `TP_resource/RT08_TP_FILE_0x1FD4_250106_01` 并上传。

Optional: **Select Resource File → Sync** simulates choosing a server or local file; its name
must exist in the missing-file list.  
可选：**选择资源文件 → 升级**，模拟从服务端或本地选择文件，文件名须在缺失列表中。

> In production, download the file identified by `getNeededFileListFinished`, then call
> `syncResourceFileName`. See **§3.34.1 Device resource file update**.  
> 正式环境中，根据 `getNeededFileListFinished` 返回的 `fileName` 下载文件，再调用
> `syncResourceFileName`。详见开发指南 **§3.34.1 设备资源文件升级**。

### 5. Notes

**QCBandSDK 说明**

- `QCSDKManager` manages App-device connections and live callbacks.  
  `QCSDKManager` 管理 App 与设备连接及 Live 回调。
- `QCSDKCmdCreator` provides command APIs. Execute commands sequentially because concurrent
  calls may fail.  
  `QCSDKCmdCreator` 提供指令接口；指令需按顺序调用，并发调用可能导致后续指令失败。

### 6. Changelog

**更新日志**

#### 2026-08-12

- Fixed raise-to-wake / FlipWrist read-write for band and ring demos.  
  修复手环抬腕亮屏与戒指翻腕读写下发异常。
- Updated Display Palm and Touch Gestures sample entry points.  
  更新显示抬腕与触摸/手势示例入口。
- Normalized Palm wear-hand default input to left/right.  
  规整抬腕佩戴手默认输入为左/右。
- Updated the Chinese and English development guides and PDF.  
  同步更新中英文开发指南及 PDF。

#### 2026-08-05

- Synced new `QCSDKCmdCreator` APIs into CN/EN development guides (music, AGPS, PXP, feature config, UI resources, display).  
  将新增 `QCSDKCmdCreator` API 同步写入中英文开发指南（音乐、AGPS、PXP、扩展能力、UI 资源、显示相关）。
- Renamed demo/docs **TP Resource Update** → **Resource Update**.  
  Demo/文档 **TP 资源升级** 更名为 **资源升级**。

#### 2026-08-04

- Improved main sleep, nap, cross-day assignment, and sleep-detail parsing.  
  完善主睡眠、小睡、跨天归属及睡眠详情解析。
- Unified health settings into switch cells with state verification and unsupported-firmware feedback.  
  健康设置统一为开关 Cell，支持状态回读与固件不支持提示。
- Added today’s activity score, sleep score, and sleep-efficiency demos.  
  新增今日活动得分、睡眠评分及睡眠效率演示。
- Updated the Chinese and English development guides and PDF.  
  同步更新中英文开发指南及 PDF。
