# Desktop Sticky

一款轻量的 macOS 桌面便签应用。它常驻菜单栏，便签数据只保存在本机，无需账号。

## 功能

- 创建多张桌面便签
- 四种柔和配色
- 置顶、隐藏与完成状态
- 快捷或自定义时间提醒
- 自动保存内容、位置和窗口大小
- 启动时恢复未隐藏的便签

## 系统要求

- macOS 11.0 或更高版本
- Xcode Command Line Tools（提供 Swift 编译器）

## 构建与运行

```bash
cd DesktopSticky
./build.sh
open "dist/Desktop Sticky.app"
```

应用使用本地 ad-hoc 签名。首次打开时，如果 macOS 阻止运行，请在“系统设置 → 隐私与安全性”中允许打开。

## 数据存储

便签数据保存在：

```text
~/Library/Application Support/com.codex.desktopsticky/notes.json
```

删除应用不会自动删除便签数据。

## 项目结构

```text
DesktopSticky/
├── Assets/       # 应用图标与图标生成脚本
├── Sources/      # Swift 源码
├── Info.plist    # macOS 应用配置
└── build.sh      # 编译与打包脚本
```
