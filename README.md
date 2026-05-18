# xvideo macOS

一个基于 `https://lzizy.net/api.php/provide/vod/` 的原生 macOS 影视客户端。

## 当前目标

这个仓库现在按“可维护、可扩展、可提交追踪”的方向整理，适合作为持续迭代的软件项目基础。

## 架构分层

```text
Sources/xvideo
├── App
├── Presentation
│   ├── ViewModels
│   └── Views
├── Domain
│   ├── Models
│   ├── Repositories
│   └── Services
├── Data
│   ├── Network
│   └── Repositories
├── Infrastructure
│   └── Downloads
└── Shared
    ├── Extensions
    └── Support
```

各层职责：

- `App`：应用入口、依赖装配
- `Presentation`：SwiftUI 界面与状态管理
- `Domain`：核心模型、仓储协议、业务解析
- `Data`：远程 API 与数据仓储实现
- `Infrastructure`：下载、文件、系统能力
- `Shared`：公共扩展与通用支持代码

更详细的架构说明见 [Docs/Architecture.md](Docs/Architecture.md)。

## 功能

- 最新资源列表和分类浏览
- 影片搜索
- 海报、简介、地区、年份、主演、导演等详情
- m3u8 在线播放
- mp4 下载到 `~/Downloads/xvideo`

## 开发运行

```bash
cd xvideo
swift run xvideo
```

## 打包为 .app

```bash
cd xvideo
./Scripts/build_app.sh
open .build/app/xvideo.app
```

## Git 使用建议

建议每次“大改动”按下面节奏提交：

```bash
git status
git add .
git commit -m "feat: 描述这次结构或功能改动"
```

推荐提交类型：

- `feat`: 新功能
- `fix`: 缺陷修复
- `refactor`: 重构
- `docs`: 文档更新
- `chore`: 工程调整
