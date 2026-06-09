# Xvideo

[中文](README.md) | [English](README.en.md)

Xvideo 是一个 Web 影视客户端，通过用户配置的媒体采集 API 拉取影片列表、详情和播放地址。当前 `web` 分支使用 React、Vite 和 TypeScript 实现浏览、搜索、选片、播放、收藏、继续观看、下载和数据源管理。

应用不内置任何数据源。首次使用时需要添加自己的采集接口，接口内容和可播放性取决于用户配置的资源站。

## 主要功能

- 浏览最新更新、顶级分类和子分类
- 深色影院式 Web 工作台，左侧媒体库导航，右侧浏览与播放区域
- 精选影片优先展示收藏内容，全部影片支持按批次换一批
- 搜索影片、演员等关键词
- 分类筛选支持类型、年份和地区
- 查看海报、简介、地区、年份、主演、导演、评分、更新状态和播放列表
- 支持多数据源添加、测试、启用、切换和删除
- 兼容 JSON、XML 以及扁平 XML 分类接口
- 直链播放通过浏览器 `<video>`，m3u8 通过 hls.js，`/share/` 网页播放地址提供 iframe 与新窗口打开
- 播放器支持上一集、下一集、快退/快进 15 秒
- 继续观看记录保存播放源、剧集、播放位置和所属数据源
- 收藏记录保存所属数据源，可从“我的收藏”继续打开
- 下载可用直链资源，浏览器会保存到用户默认下载位置
- 数据源、收藏、继续观看和首页预览缓存保存在浏览器 localStorage
- Vite dev/preview 内置本地代理，用于开发时请求用户配置的媒体 API、解析网页播放地址和代理媒体文件

## 运行

```bash
npm install
npm run dev
```

默认开发地址：

```text
http://127.0.0.1:5173
```

## 构建与预览

```bash
npm test
npm run build
npm run preview
```

构建产物会生成到：

```text
dist/
```

## 项目结构

```text
src
├── App.tsx              # 应用外壳和路由级状态
├── appContext.tsx       # 共享上下文
├── components           # React 视图组件
├── hooks                # Library、收藏、继续观看、下载等状态逻辑
├── services             # API、XML/JSON 解析、播放源解析、本地存储、格式化
├── styles.css           # 设计系统和响应式布局
└── types.ts             # 产品模型和 TypeScript 类型
```

开发流程、分层约定和验证规则放在 [AGENTS.md](AGENTS.md) 与 [Docs/Workflow/](Docs/Workflow/)。

## Web 版说明

- Web 版开发/预览依赖本地 Vite 代理绕过常见 CORS 限制；静态部署时需要提供等价代理能力。
- 浏览器无法像原生桌面应用一样固定保存到 `~/Downloads/Xvideo` 或在 Finder 中显示文件，下载会交给浏览器处理。
- m3u8、mp4、网页播放器是否能播放取决于资源站、浏览器媒体能力、跨域策略、iframe 策略和资源状态。
- 启用数据源前会先验证接口可用性，验证失败时会保留当前数据源。
