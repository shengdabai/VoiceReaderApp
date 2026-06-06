# 🔊 VoiceReaderApp

**English | [中文](#中文)**

> Turn any PDF, EPUB, Markdown, or web article into spoken audio — in your own voice. An iOS reader that clones your voice for narration and falls back to fast on-device speech when you're offline.

[![Last commit](https://img.shields.io/github/last-commit/shengdabai/VoiceReaderApp)](https://github.com/shengdabai/VoiceReaderApp/commits)
[![Stars](https://img.shields.io/github/stars/shengdabai/VoiceReaderApp?style=social)](https://github.com/shengdabai/VoiceReaderApp/stargazers)
[![Follow @shengdabai](https://img.shields.io/github/followers/shengdabai?style=social)](https://github.com/shengdabai)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-FA7343?logo=swift&logoColor=white)
![Platform iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-000000?logo=apple&logoColor=white)

---

## Why VoiceReaderApp

Reading apps read to you in a robot voice. VoiceReaderApp reads to you in *your* voice — or anyone's voice you've cloned through a remote TTS service — so listening to a book, paper, or long article feels personal instead of mechanical. Built for trilingual readers (Chinese / English / German) who want to *listen* to documents while walking, commuting, or resting their eyes, and who don't want to lose audio the moment they go offline.

It's a personal-use iOS app built in the open, designed around one idea: **import anything, listen to everything, in a voice you actually like.**

## ✨ Features

- **📥 Import from anywhere** — local files, iCloud, files shared from other apps (including WeChat), or paste a URL to extract and read an article.
- **📄 Four formats** — PDF, EPUB, Markdown, and plain text (TXT), routed through a pluggable parser factory.
- **🌍 Trilingual** — Simplified Chinese (`zh-CN`), US English (`en-US`), and German (`de-DE`).
- **🎙️ Voice cloning with smart fallback** — prefers your configured remote cloned voice; automatically falls back to on-device speech when the remote service is unavailable, so playback never stalls.
- **🎚️ Eight playback speeds** — 0.5×, 0.75×, 1.0×, 1.25×, 1.5×, 2.0×, 2.5×, 3.0×.
- **🔁 Resume where you left off** — reading position is persisted and restored automatically.
- **🎧 Background audio + lock-screen controls** — keeps reading when the app is backgrounded, with play / pause / stop from the Now Playing controls.
- **🗣️ Record your own samples** — capture personal voice samples on-device to feed a cloning workflow.

## 🧱 Tech stack

| Layer | Choice |
|-------|--------|
| Language | Swift 5.10 |
| UI | SwiftUI |
| Platform | iOS 17.0+ |
| Speech | AVFoundation (`AVSpeechSynthesizer` on-device + `AVAudioPlayer` for remote audio) |
| Audio session | `MPRemoteCommandCenter` for lock-screen controls, background `audio` mode |
| Project gen | XcodeGen (`project.yml`) — no `.xcodeproj` committed |
| Dependency | [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) (EPUB unpacking) |

**Architecture in one breath:** a `TTSRouter` decides between a `RemoteCloneProvider` and a `LocalSpeechSynthProvider`; a `ParserFactory` turns each file format into clean text; a `PlaybackEngine` drives both the synthesizer and the audio player behind a single playback state machine.

## 🚀 Build & run

**Requirements:** macOS with full Xcode 15+ (not just Command Line Tools), iOS 17+ device, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
# 1. Clone
git clone https://github.com/shengdabai/VoiceReaderApp.git
cd VoiceReaderApp

# 2. Install XcodeGen (if needed)
brew install xcodegen

# 3. Generate the Xcode project from project.yml
xcodegen generate

# 4. Open and run
open VoiceReaderApp.xcodeproj
```

In Xcode, select the **VoiceReaderApp** target and run on a physical iOS device (background audio and microphone behave best on real hardware).

## 📖 Usage

1. **Import** a document (PDF / EPUB / Markdown / TXT) from Files, iCloud, or another app's share sheet — or paste a web URL to pull in an article.
2. **Pick a language and a voice profile** (on-device, or a remote clone you've configured).
3. **Press play.** Adjust speed on the fly; lock your phone and keep listening.
4. **Reopen later** — VoiceReaderApp resumes from your last reading position.

### Remote voice cloning (optional)

Configure in **Settings → Remote Cloning**:

- **API Endpoint** — your TTS / cloning service HTTP URL
- **API Key** — service access key

Request body the app sends:

```json
{
  "text": "Text to be read",
  "languageCode": "zh-CN",
  "speed": 1.0,
  "voiceId": "your-remote-voice-id"
}
```

The endpoint should return **binary audio** (`audio/mpeg` or `audio/wav`). See [`Docs/remote-clone-api-contract.md`](Docs/remote-clone-api-contract.md) for the full contract and [`Docs/provider-cost-notes.md`](Docs/provider-cost-notes.md) for provider cost notes.

## 🗺️ Status

Active personal project, built and iterated in public. Distribution is via TestFlight (`Product → Archive` → App Store Connect → internal testers).

**Known limitations:**
- EPUB is extracted as plain body text — complex layout is not preserved.
- URL extraction uses lightweight HTML-stripping rules; some complex sites need site-specific tweaks.
- Remote cloning interfaces vary by vendor and require custom API integration.

## 🤝 Connect & about

Built by **Tony (Sheng)** — a Chinese-language teacher with 6,000+ students, building AI + Chinese-teaching tools in the open.

If a reading app that speaks in *your* voice sounds useful, **⭐ star this repo and [follow @shengdabai](https://github.com/shengdabai)** to follow along as it grows.

**More tools in the same family:**
- [QuickTranslate](https://github.com/shengdabai/QuickTranslate) — fast translation
- [LinguaLens](https://github.com/shengdabai/LinguaLens) — language-learning lens
- [chinese-learning-app](https://github.com/shengdabai/chinese-learning-app) — Chinese learning

## License

No license file is present yet — all rights reserved by default. If you'd like to use or build on this, please open an issue.

---

# 中文

> 把任意 PDF、EPUB、Markdown 或网页文章变成语音——用你自己的声音朗读。一款 iOS 朗读应用：优先用克隆音色朗读，离线时自动回退到快速的本地语音。

[![最近提交](https://img.shields.io/github/last-commit/shengdabai/VoiceReaderApp)](https://github.com/shengdabai/VoiceReaderApp/commits)
[![Star 数](https://img.shields.io/github/stars/shengdabai/VoiceReaderApp?style=social)](https://github.com/shengdabai/VoiceReaderApp/stargazers)
[![关注 @shengdabai](https://img.shields.io/github/followers/shengdabai?style=social)](https://github.com/shengdabai)
![Swift 5.10](https://img.shields.io/badge/Swift-5.10-FA7343?logo=swift&logoColor=white)
![平台 iOS 17+](https://img.shields.io/badge/iOS-17.0%2B-000000?logo=apple&logoColor=white)

## 为什么做它

普通朗读应用用机器音念给你听。VoiceReaderApp 用 **你自己的声音**(或你通过远程 TTS 服务克隆的任意音色)来念,让听书、听论文、听长文章变得亲切而不机械。它面向需要中/英/德三语朗读的读者——想在走路、通勤、闭眼休息时「听」文档,又不想一离线就没声音。

这是一款公开开发的个人 iOS 应用,核心理念只有一句:**任意导入,全部能听,用你喜欢的声音。**

## ✨ 功能特性

- **📥 随处导入**——本地文件、iCloud、其他应用分享进来的文件(含微信),或粘贴网址提取并朗读文章。
- **📄 四种格式**——PDF、EPUB、Markdown、纯文本(TXT),由可插拔的解析器工厂统一处理。
- **🌍 三语支持**——简体中文(`zh-CN`)、美式英语(`en-US`)、德语(`de-DE`)。
- **🎙️ 克隆音色 + 智能兜底**——优先使用你配置的远程克隆音色;远程不可用时自动回退到本地语音,播放从不中断。
- **🎚️ 八档语速**——0.5×、0.75×、1.0×、1.25×、1.5×、2.0×、2.5×、3.0×。
- **🔁 断点续读**——阅读位置自动保存与恢复。
- **🎧 后台播放 + 锁屏控制**——应用退到后台仍继续朗读,支持锁屏「正在播放」的播放 / 暂停 / 停止。
- **🗣️ 录制个人样本**——在设备本地录制声音样本,用于克隆流程。

## 🧱 技术栈

| 层 | 选型 |
|----|------|
| 语言 | Swift 5.10 |
| UI | SwiftUI |
| 平台 | iOS 17.0+ |
| 语音 | AVFoundation(本地 `AVSpeechSynthesizer` + 远程音频用 `AVAudioPlayer`) |
| 音频会话 | `MPRemoteCommandCenter` 锁屏控制,后台 `audio` 模式 |
| 工程生成 | XcodeGen(`project.yml`)——不提交 `.xcodeproj` |
| 依赖 | [ZIPFoundation](https://github.com/weichsel/ZIPFoundation)(EPUB 解包) |

**一句话架构:** `TTSRouter` 在 `RemoteCloneProvider` 与 `LocalSpeechSynthProvider` 之间决策;`ParserFactory` 把每种格式转成干净文本;`PlaybackEngine` 通过单一播放状态机同时驱动合成器与音频播放器。

## 🚀 构建运行

**环境要求:** 装有完整 Xcode 15+ 的 macOS(不是 Command Line Tools)、iOS 17+ 真机,以及 [XcodeGen](https://github.com/yonaskolb/XcodeGen)。

```bash
# 1. 克隆
git clone https://github.com/shengdabai/VoiceReaderApp.git
cd VoiceReaderApp

# 2. 安装 XcodeGen(如未安装)
brew install xcodegen

# 3. 由 project.yml 生成 Xcode 工程
xcodegen generate

# 4. 打开并运行
open VoiceReaderApp.xcodeproj
```

在 Xcode 中选择 **VoiceReaderApp** target,在 iOS 真机上运行(后台音频与麦克风在真机上表现最佳)。

## 📖 使用

1. 从「文件」、iCloud 或其他应用的分享面板**导入**文档(PDF / EPUB / Markdown / TXT),或粘贴网址抓取文章。
2. **选择语言与声音档案**(本地,或你已配置的远程克隆音色)。
3. **按播放。** 可随时调速;锁屏后继续听。
4. **下次打开**——自动从上次阅读位置续读。

### 远程克隆音色(可选)

在 **设置 → 远程克隆** 中配置:

- **API 端点**——你的 TTS / 克隆服务 HTTP 地址
- **API 密钥**——服务访问密钥

应用发送的请求体:

```json
{
  "text": "需要朗读的文本",
  "languageCode": "zh-CN",
  "speed": 1.0,
  "voiceId": "your-remote-voice-id"
}
```

端点应返回**二进制音频**(`audio/mpeg` 或 `audio/wav`)。完整契约见 [`Docs/remote-clone-api-contract.md`](Docs/remote-clone-api-contract.md),服务商成本说明见 [`Docs/provider-cost-notes.md`](Docs/provider-cost-notes.md)。

## 🗺️ 状态

公开开发、持续迭代中的个人项目。交付方式为 TestFlight(`Product → Archive` → App Store Connect → 内部测试)。

**已知限制:**
- EPUB 仅提取正文文本,不保留复杂排版。
- 网址提取使用轻量 HTML 清洗规则,部分复杂站点需专项适配。
- 远程克隆接口因厂商而异,需按实际 API 对接。

## 🤝 联系与关于

作者 **Tony(盛)**——拥有 6000+ 学员的中文老师,在公开场合构建 AI + 中文教学工具。

如果「用你自己的声音朗读的阅读器」对你有用,欢迎 **⭐ Star 本仓库,并[关注 @shengdabai](https://github.com/shengdabai)**,见证它持续成长。

**同系列工具:**
- [QuickTranslate](https://github.com/shengdabai/QuickTranslate) —— 快速翻译
- [LinguaLens](https://github.com/shengdabai/LinguaLens) —— 语言学习镜头
- [chinese-learning-app](https://github.com/shengdabai/chinese-learning-app) —— 中文学习

## 许可

暂无许可证文件——默认保留所有权利。如想使用或基于本项目开发,请提 issue 沟通。
