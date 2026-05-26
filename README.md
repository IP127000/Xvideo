# Xvideo

[中文](README.md) | [English](README.en.md)

Xvideo 是一个原生 macOS 影视客户端，用 SwiftUI 写界面，通过资源站 API 拉取影片列表、详情和播放地址。

项目现在主要围绕日常观看体验在迭代：浏览分类、搜索影片、查看详情、切换剧集、收藏常看的内容，以及在本地播放器里播放视频。

## 界面预览

主界面把分类浏览、筛选搜索、详情和播放器放在同一个窗口里。

![Xvideo macOS 应用界面预览](Docs/images/app-preview-blurred.png)

## 主要功能

- 浏览最新更新和影片分类
- 搜索影片、演员等关键词
- 查看海报、简介、地区、年份、主演、导演和更新状态
- 支持多播放源切换，包括 m3u8 和网页播放器源
- 播放器内切换上一集、下一集
- 支持播放器快退/快进 15 秒，播放窗口可用 Esc 退出
- 收藏影片，并在“我的收藏”里快速打开继续观看
- 下载可用的 mp4 资源到 `~/Downloads/Xvideo`

## 运行

本项目使用 Swift Package Manager，最低支持 macOS 14。

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

当前数据来自资源站接口，播放是否可用会受到资源状态、网络环境和播放源限制影响。遇到某个源无法播放时，可以优先切换到另一个播放源试试。
