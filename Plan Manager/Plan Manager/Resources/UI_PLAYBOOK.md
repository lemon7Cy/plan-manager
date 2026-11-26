# Plan Manager UI Playbook (SwiftUI)

## 1. Goal
统一 App 的视觉、交互和信息层级，保持 `Liquid Glass` 风格但避免花哨与 AI 感。

## 2. Design Direction
- 风格关键词: `Calm`, `Clear`, `Soft Glass`, `Readable`
- 主色策略: `Blue-first`
- 动效策略: 少而准，优先功能反馈，避免表演型动画

## 3. Global Rules

### 3.1 Layout Grid
- 页面横向安全边距: `16`
- 模块间距: `16`
- 卡片内边距: `12` 或 `14`
- 圆角层级:
  - 输入/按钮: `12`
  - 业务卡片: `16`
  - 顶层面板/弹层: `20+`

### 3.2 Navigation
- 顶栏高度和按钮尺寸统一
- 返回按钮固定位置和触控面积（最小 `40x40`）
- 标题信息采用两级（主标题 + 状态/副标题）

### 3.3 Color Rules
- 主色: 蓝色（`DesignTokens.skyBlue`）
- 功能色:
  - 成功: 绿色
  - 警告: 橙色
  - 危险: 红色
- 禁止事项:
  - 紫色作为主按钮渐变
  - 每个页面自定义随机渐变

### 3.4 Material Rules (Liquid Glass)
- 可交互元素优先使用 `regularMaterial`/`ultraThinMaterial`
- 玻璃组件统一有:
  - 1px 亮边描边
  - 轻阴影（不要重投影）
- 不要叠太多玻璃层，防止发灰

### 3.5 Typography
- 标题: `17~22`，`semibold/bold`
- 正文: `15~16`
- 辅助信息: `12~13`
- 同一页面最多 3 级字号

## 4. Component Catalog

### 4.1 Buttons
- Primary Button:
  - 纯色填充（蓝）
  - 白字
  - 胶囊或圆角矩形
- Secondary Button:
  - 玻璃底 + 描边
  - 文本次级色
- Danger Button:
  - 红色文本或浅红底

### 4.2 Top Bars
- 组成: `Back` + `Title/Status` + `Action`
- 不要再套一层重容器背景（可浮动）

### 4.3 Input Bars
- 输入框和发送按钮可独立浮动
- 保持内容区的视觉分层，不要厚重底板

### 4.4 Settings Cards
- 图标 + 标题 + 说明 + 右箭头
- 卡片高度统一，说明不超过一行

## 5. Feature-Specific Guidance

### 5.1 Offline Settings
- 备份/恢复使用同一张设置卡片模版
- 所有“保存”和主要操作按钮统一蓝色纯色

## 6. Interaction Rules
- 轻触反馈: 重要动作触发 haptic
- 动画时长建议:
  - 入场/退场: `0.22 ~ 0.3`
  - 状态切换: `0.18 ~ 0.25`

## 7. Do / Don't

### Do
- 用统一 token
- 保持信息密度可读
- 同一类按钮保持一致

### Don't
- 紫色渐变主按钮
- 过度光效/过度模糊
- 每页换一套交互语言

## 8. Implementation Backlog

### P0 (本周)
- 设置页、备份恢复、通知设置统一风格

### P1 (下周)
- 计划页/支出页顶部导航与按钮体系统一
- 提取通用组件: `PMGlassCard`, `PMPrimaryButton`, `PMTopBar`

### P2
- 建立 UI snapshot 对比基线
- 增加深浅色一致性检查

## 9. Acceptance Checklist
- [ ] 主按钮不再出现蓝紫渐变
- [ ] 顶栏和底栏风格统一
- [ ] 设置页操作卡片可读性良好
- [ ] 深浅色模式均可读
