# VoiceReaderApp (iOS)

A multi-language text-to-speech app designed for personal use, supporting Chinese, English, and German. Import PDF/EPUB/Markdown/TXT files, record voice samples, with intelligent remote voice cloning fallback to offline TTS.

## Features

### File Import
- **Local Files**: Import from device storage or iCloud
- **External Sharing**: Open files shared from other apps (including WeChat)
- **Web Content**: Import URLs to extract and read article content

### Supported Formats
- PDF documents
- EPUB books
- Markdown files
- Plain text (TXT)

### Languages
- Chinese (Simplified)
- English (US)
- German (Germany)

### Playback Controls
- **Speed Settings**: 0.5x, 0.75x, 1.0x, 1.25x, 1.5x, 2.0x, 2.5x, 3.0x
- **Background Playback**: Continue reading while app is in background
- **Resume Playback**: Automatically resume from last position
- **Pause/Resume**: Full playback control

### Voice System
- **Local Recording**: Record personal voice samples
- **Remote Voice Cloning**: Priority use of remote cloned voices
- **Offline Fallback**: Automatic fallback to local TTS when remote service unavailable

## Technical Stack

- **Language**: Swift 5.10
- **UI Framework**: SwiftUI
- **Platform**: iOS 17.0+
- **Build Tool**: XcodeGen
- **Dependencies**: ZIPFoundation (for file handling)
- **Audio**: AVFoundation (speech synthesis)

## Architecture

### Project Structure
```
VoiceReaderApp/
├── project.yml              # XcodeGen project configuration
├── App/
│   ├── Sources/
│   │   ├── App/             # App entry point
│   │   ├── Features/        # Feature modules
│   │   │   ├── Library/     # Book library management
│   │   │   ├── Reader/      # Reading interface
│   │   │   └── Settings/    # App settings
│   │   ├── Models/          # Data models
│   │   ├── Services/        # Business logic
│   │   │   ├── Import/     # Document import
│   │   │   ├── Parsing/    # Text extraction
│   │   │   ├── TTS/        # Speech synthesis
│   │   │   ├── Playback/   # Audio playback
│   │   │   └── Persistence/ # Data storage
│   │   ├── UI/             # UI components
│   │   └── Support/        # App environment
│   ├── Resources/           # Assets and Info.plist
│   └── Tests/              # Unit tests
```

### Core Components

#### TTS Router
Intelligently routes speech requests:
1. Attempts remote voice cloning if configured
2. Falls back to local TTS if remote unavailable
3. Ensures continuous playback experience

#### Parser Factory
Handles multiple document formats:
- PDF: Extracts text while preserving readability
- EPUB: Converts to plain text (simple formatting)
- Markdown: Preserves basic structure
- TXT: Direct text processing

#### Voice Profile System
- Record personal voice samples
- Configure remote cloning services
- Automatic provider selection based on availability

## Installation & Development

### Requirements
- Xcode 15+ (full Xcode, not Command Line Tools)
- XcodeGen

### Setup
1. Install XcodeGen:
   ```bash
   brew install xcodegen
   ```

2. Generate project:
   ```bash
   cd /Users/tonysheng/Desktop/02-编程项目/VoiceReaderApp
   xcodegen generate
   open VoiceReaderApp.xcodeproj
   ```

3. Build and run:
   - In Xcode, select `VoiceReaderApp` target
   - Run on physical iOS device

## Remote Voice Cloning Configuration

Configure in App Settings → Remote Cloning:

- **API Endpoint**: Your TTS/cloning service HTTP URL
- **API Key**: Service access key

### API Request Format
```json
{
  "text": "Text to be read",
  "languageCode": "zh-CN",
  "speed": 1.0,
  "voiceId": "your-remote-voice-id"
}
```

### Expected Response
Binary audio data (audio/mpeg or audio/wav).

## Delivery

### TestFlight Distribution
1. Archive in Xcode (`Product → Archive`)
2. Upload to App Store Connect
3. Add internal testers in TestFlight
4. Install and test on iPhone

## Known Limitations

- EPUB parsing extracts plain text (complex formatting not preserved)
- URL content extraction uses lightweight rules; complex sites may require specific adaptation
- Remote cloning service interfaces vary by vendor and require custom API integration

---

# VoiceReaderApp (iOS)

一个面向个人使用的多语言朗读应用（中文/英文/德文），支持导入 PDF/EPUB/Markdown/TXT，录制声音样本，优先走远程克隆音色，失败时自动回退本地离线语音。

## 功能特性

### 文件导入
- **本地文件**：从设备存储或 iCloud 导入
- **外部分享**：打开从其他应用分享的文件（包括微信）
- **网页内容**：导入网址链接，提取并朗读文章内容

### 支持格式
- PDF 文档
- EPUB 电子书
- Markdown 文件
- 纯文本文件 (TXT)

### 语言支持
- 中文（简体）
- 英文（美式）
- 德文（德国）

### 播放控制
- **语速调节**：0.5x、0.75x、1.0x、1.25x、1.5x、2.0x、2.5x、3.0x
- **后台播放**：应用在后台时继续朗读
- **断点续读**：自动从上次位置恢复
- **暂停/继续**：完整的播放控制

### 声音系统
- **本地录制**：录制个人声音样本
- **远程克隆**：优先使用远程克隆的音色
- **离线兜底**：远程服务不可用时自动使用本地 TTS

## 技术栈

- **开发语言**：Swift 5.10
- **UI 框架**：SwiftUI
- **支持平台**：iOS 17.0+
- **构建工具**：XcodeGen
- **依赖库**：ZIPFoundation（文件处理）
- **音频处理**：AVFoundation（语音合成）

## 架构设计

### 项目结构
```
VoiceReaderApp/
├── project.yml              # XcodeGen 工程配置
├── App/
│   ├── Sources/
│   │   ├── App/             # 应用入口
│   │   ├── Features/        # 功能模块
│   │   │   ├── Library/     # 书库管理
│   │   │   ├── Reader/      # 阅读界面
│   │   │   └── Settings/    # 应用设置
│   │   ├── Models/          # 数据模型
│   │   ├── Services/        # 业务逻辑
│   │   │   ├── Import/     # 文档导入
│   │   │   ├── Parsing/    # 文本解析
│   │   │   ├── TTS/        # 语音合成
│   │   │   ├── Playback/   # 音频播放
│   │   │   └── Persistence/ # 数据存储
│   │   ├── UI/             # UI 组件
│   │   └── Support/        # 应用环境
│   ├── Resources/           # 资源文件和 Info.plist
│   └── Tests/              # 单元测试
```

### 核心组件

#### TTS 路由器
智能路由语音请求：
1. 优先尝试远程语音克隆（如果已配置）
2. 远程不可用时回退到本地 TTS
3. 确保持续的播放体验

#### 解析器工厂
处理多种文档格式：
- PDF：提取文本，保持可读性
- EPUB：转换为纯文本（简单格式）
- Markdown：保留基本结构
- TXT：直接文本处理

#### 声音配置系统
- 录制个人声音样本
- 配置远程克隆服务
- 根据可用性自动选择提供商

## 安装与开发

### 环境要求
- Xcode 15+（完整 Xcode，不是 Command Line Tools）
- XcodeGen

### 设置步骤
1. 安装 XcodeGen：
   ```bash
   brew install xcodegen
   ```

2. 生成工程：
   ```bash
   cd /Users/tonysheng/Desktop/02-编程项目/VoiceReaderApp
   xcodegen generate
   open VoiceReaderApp.xcodeproj
   ```

3. 构建运行：
   - 在 Xcode 中选择 `VoiceReaderApp` target
   - 在真机上运行

## 远程克隆音色配置

在应用设置 → 远程克隆中配置：

- **API 端点**：您的 TTS/克隆服务 HTTP 地址
- **API 密钥**：服务访问密钥

### 请求体格式
```json
{
  "text": "需要朗读的文本",
  "languageCode": "zh-CN",
  "speed": 1.0,
  "voiceId": "your-remote-voice-id"
}
```

### 响应格式
返回二进制音频数据（audio/mpeg 或 audio/wav）。

## 发布交付

### TestFlight 交付
1. 在 Xcode 中归档（`Product → Archive`）
2. 上传到 App Store Connect
3. 在 TestFlight 中添加内部测试成员
4. 在 iPhone 上安装并验收

## 已知限制

- EPUB 解析为正文文本（不保留复杂排版）
- 网址正文提取使用轻量规则，复杂站点可能需要专项适配
- 远程克隆服务接口因厂商差异需按实际 API 对接