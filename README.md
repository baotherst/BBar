# BBar (极简菜单栏)

BBar 是一款专为 macOS (支持 Apple Silicon M 芯片) 设计的轻量级菜单栏图标自动/自定义隐藏工具。

## 项目结构

- `Sources/BBar/main.swift`: 程序入口点，引导 AppKit 启动。
- `Sources/BBar/AppDelegate.swift`: 核心控制器，管理状态栏图标创建、点击与右键事件、自动启动管理、悬停检测、以及自动隐藏延时器。
- `Package.swift`: Swift Package Manager 配置文件。
- `Info.plist`: 应用属性配置文件，配置其作为 Agent (LSUIElement) 无后台图标静默运行。
- `icon.png`: 应用的高清图源图标。
- `build.sh`: 自动化编译与打包脚本。

## 编译与打包

在终端中运行以下命令，即可在本地重新编译并打包生成 App Bundle：

```bash
chmod +x build.sh
./build.sh
```

编译完成后，会在当前目录下生成 `BBar.app`。您可以直接运行，或将其移动至系统的 `/Applications` (应用程序) 目录中。
