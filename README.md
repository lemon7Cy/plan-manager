# Plan Manager

原生 iOS 个人计划与健身应用，使用 Swift 6、SwiftUI 和 SwiftData，最低支持 iOS 26。版本记录见 [CHANGELOG](CHANGELOG.md)。

**不需要登录，也不需要部署后端。** 计划、支出、喝水和健身记录保存在设备本地；只有主动生成健身计划时才调用用户配置的 LLM 服务。

## 功能

- 健身教练：身体档案、BMI/体脂估算、器材档案、每日训练安排、逐组记录和反馈。
- 训练记忆：根据实际记录沿用已适应重量、避开近期训练肌群，满足条件后提供小幅加重建议。
- 日常计划、分类支出、喝水记录和本地通知。
- 深浅主题及 JSON 备份/合并恢复。API Key 存 Keychain，不写入备份或源码。

健身使用方法和规则详见 [健身说明](Plan%20Manager/FITNESS_README.md)。身体指标估算仅供参考，训练时出现疼痛应暂停并评估原因。

## 开发

需要 macOS、完整的 Xcode 26 或更新版本，以及 XcodeGen。

```sh
brew install xcodegen
xcodegen generate --spec 'Plan Manager/project.yml'
open 'Plan Manager/Plan Manager.xcodeproj'
```

选择 `Plan Manager` scheme。模拟器不需要签名；安装真机时，在 Xcode 中选择自己的开发团队。仓库不内置签名凭据。

`Plan Manager/project.yml` 是工程配置来源，修改配置后重新生成工程。不要提交 `xcuserdata` 或本机 IDE 配置。

## 测试

```sh
# 不依赖模拟器的同源规则、存储测试
swift test --package-path 'Plan Manager'

# 编译 iOS 应用及测试
xcodebuild -project 'Plan Manager/Plan Manager.xcodeproj' \
  -scheme 'Plan Manager' -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build-for-testing

# 在完整模拟器环境下，替换 DEVICE_ID 后执行
xcodebuild -project 'Plan Manager/Plan Manager.xcodeproj' \
  -scheme 'Plan Manager' -destination 'platform=iOS Simulator,id=DEVICE_ID' \
  CODE_SIGNING_ALLOWED=NO test
```

GitHub Actions 会运行核心测试、iOS 模拟器测试和无签名的真机目标编译，不发布 App Store 或部署服务器。测试记录见 [实施与验收记录](FITNESS_IMPLEMENTATION.md)。

## 版本

每次代码改动后使用 `scripts/bump_plan_manager_version.sh` 递增营销版本 `+0.01`，同步 plist、Xcode 工程和 XcodeGen 配置。`--check` 只检查一致性。

## 目录

```text
Plan Manager/
  Plan Manager/            SwiftUI 应用源码与资源
  FitnessTests/            规则、持久化、模型协议测试
  FitnessUITests/          界面流程测试
  Plan Manager.xcodeproj/  Xcode 工程
  project.yml             XcodeGen 配置
  Package.swift           独立核心测试入口
scripts/                  版本维护工具
.github/workflows/        原生 iOS 持续集成
```

旧 Flutter/Android 工程、Go 后端、Vue 管理后台、Docker 和小精灵模块已退出当前代码库。

## 开源协议

本项目基于 [MIT License](LICENSE) 开源。
