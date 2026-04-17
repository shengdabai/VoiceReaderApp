# VoiceReaderApp (iOS)

一个面向个人使用的多语言朗读应用（中文/英文/德文），支持导入 PDF/EPUB/Markdown/TXT，录制声音样本，优先走远程克隆音色，失败时自动回退本地离线语音。

## 功能范围（MVP）

- 文件导入：本地文件、iCloud、外部分享打开（含微信分享到本 App）
- 链接导入：输入网址抓取正文后朗读
- 格式支持：PDF / EPUB / Markdown / TXT
- 语言：中文（简体）/ 英文（美式）/ 德文（德国）
- 固定语速档位：0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x, 2.5x, 3.0x
- 播放能力：后台播放、暂停恢复、断点续读
- 声音：录制本地样本，远程克隆音色优先，离线本地 TTS 兜底

## 项目结构

```text
VoiceReaderApp/
  project.yml                # XcodeGen 工程配置
  App/
    Sources/
      App/
      Features/
      Models/
      Services/
      Support/
      UI/
    Resources/Info.plist
    Tests/
```

## 本地开发

1. 安装 Xcode 15+（必须是完整 Xcode，不是 Command Line Tools）
2. 安装 XcodeGen
```bash
brew install xcodegen
```
3. 生成工程
```bash
cd /Users/tonysheng/VoiceReaderApp
xcodegen generate
open VoiceReaderApp.xcodeproj
```
4. 在 Xcode 中选择 `VoiceReaderApp` target，真机运行

## 远程克隆音色配置

在 App 的 `设置 -> 远程克隆` 中配置：

- API Endpoint：你的 TTS/克隆服务 HTTP 地址
- API Key：服务访问密钥

请求体约定：

```json
{
  "text": "需要朗读的文本",
  "languageCode": "zh-CN",
  "speed": 1.0,
  "voiceId": "your-remote-voice-id"
}
```

响应约定：返回 `audio/mpeg` 或 `audio/wav` 二进制音频。

## TestFlight 交付

1. Xcode `Product -> Archive`
2. 上传到 App Store Connect
3. 在 TestFlight 添加内部测试成员
4. iPhone 安装并验收

## 已知限制

- EPUB 解析为正文文本（不保留复杂排版）
- 网址正文提取使用轻量规则，复杂站点可能需要专项适配
- 远程克隆服务接口因厂商差异需按实际 API 对接
