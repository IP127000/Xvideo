# Xvideo

[中文](README.md) | [English](README.en.md)

Xvideo 是一个原生 macOS 影视客户端，用 SwiftUI 写界面，通过用户配置的媒体 API 拉取影片列表、详情和播放地址。`ios` 分支同时提供 iPhone 触屏入口，复用同一套数据源、片库、详情、播放、收藏和继续观看能力。

项目现在主要围绕日常观看体验在迭代：浏览分类、搜索影片、查看详情、切换剧集、记录本地追番进度、收藏常看的内容，以及在本地播放器里播放视频。

## 界面预览

主界面采用两栏影院式布局：左侧是媒体库、分类和数据源管理，右侧上半部分显示当前影片详情，下半部分是精选影片和全部影片。点击影片卡片会显示快捷详情并刷新上方详情，双击卡片或点击“开始播放”后进入独立播放页。

![Xvideo macOS 应用界面预览](Docs/images/app-preview-blurred.png)

## 主要功能

- 浏览最新更新和影片分类
- 两栏影院式界面，上方详情面板和播放页分离
- 精选影片优先展示收藏内容，全部影片支持按两排换一批浏览
- 搜索影片、演员等关键词
- 查看海报、简介、地区、年份、主演、导演和更新状态
- 不内置任何数据源，首次使用需添加自己的采集接口
- 支持多数据源和播放源切换，兼容 JSON、XML 以及扁平 XML 分类接口
- 播放器内切换上一集、下一集
- 支持播放器快退/快进 15 秒，播放窗口可用 Esc 退出
- 播放剧集时会在本地记录观看进度，可从“继续观看”恢复上次剧集和播放时间
- 收藏影片会记录所属数据源，并可在“我的收藏”里点击或双击进入播放器继续观看
- 下载可用的 mp4 资源到 `~/Downloads/Xvideo`
- iPhone 版提供片库、搜索、收藏、继续观看和视频源五个底部标签入口

## 运行

本项目使用 Swift Package Manager。macOS 版最低支持 macOS 14，iPhone 版最低支持 iOS 17。

```bash
swift run Xvideo
```

## 打包成 macOS App

```bash
./Scripts/build_app.sh
open .build/app/Xvideo.app
```

打包脚本会生成：

```text
.build/app/Xvideo.app
```

## 构建 iPhone App 包

```bash
./Scripts/build_ios_app.sh
```

脚本会生成：

```text
.build/ios-device/Xvideo.app
```

安装到真机需要本机钥匙串里有可用的 Apple Development 签名证书，并提供匹配 `IOS_BUNDLE_ID` 的 provisioning profile：

```bash
IOS_SIGNING_IDENTITY="Apple Development: Your Name (TEAMID)" \
IOS_PROVISIONING_PROFILE="/path/to/profile.mobileprovision" \
./Scripts/build_ios_app.sh

IOS_DEVICE_ID="<paired-device-id>" ./Scripts/install_ios_app.sh
```

如果只是临时探测安装通道，可尝试 ad-hoc 签名；手机必须开启 Developer Mode，且系统仍可能要求正式 provisioning profile：

```bash
IOS_AD_HOC_SIGN=1 ./Scripts/build_ios_app.sh
IOS_ALLOW_AD_HOC=1 IOS_DEVICE_ID="<paired-device-id>" ./Scripts/install_ios_app.sh
```

## 项目结构

```text
Sources/Xvideo
├── App                  # 应用入口和依赖装配
├── Presentation         # SwiftUI 界面和 ViewModel
├── Domain               # 模型、协议、播放源解析
├── Data                 # API 请求和仓储实现
├── Infrastructure       # 下载、收藏等本地能力
└── Shared               # 通用扩展
```

更细的设计说明放在 [Docs/Architecture.md](Docs/Architecture.md)。

## 说明

应用不内置任何数据源，当前数据来自用户自行配置的接口。播放是否可用会受到资源状态、网络环境和播放源限制影响。启用数据源前会先验证接口可用性，验证失败时会保留当前数据源。遇到某个播放源无法播放时，可以优先切换到另一个播放源试试。
