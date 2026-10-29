# 数维弹球 · 1.0.0

把数学函数变成真实轨道，让小球收集全部检查点后到达终点。最终合并版采用 A 的重力、刚体与碰撞，结合 B 的主菜单、选关、公式卡和数学画布美术。

## 启动

使用 Godot 4.7.2 导入本目录的 `project.godot`，按 F5 运行工程。启动场景为 `scenes/main.tscn`。

也可以在项目目录通过命令行启动：

```text
godot --path .
```

## 操作与规则

- 教程关按进度逐步开放函数添加、模板选择等功能；正式关卡最多三条轨道，轨道同时参与碰撞。
- 空格运行/暂停，R 重试，Esc 暂停或关闭弹层。输入框聚焦时优先输入。
- 编辑态可按画布提示拖动、缩放或适配全图；运行和暂停时锁定公式与视图。
- 检查点可任意顺序收集；全部收集后接触终点。到达终点后等待 1 秒再显示结算，小球仍会继续运动；红区接触、球心越界或超时失败。
- “重试”保留当前公式并清空本局状态；“重置”恢复关卡初始公式。
- 七关依次解锁，可以重玩。保存最佳用时与最少公式数，两项独立取优；结算按公式数量显示简洁度星级。

存档：Godot `user://progress.json`，Windows 默认 `%APPDATA%/ShuweiPinball/progress.json`。正式进度不导入 A/B 演示记录。

## 正式内容与结构

教程关卡：第一课·一线直达、第二课·分段绕障、第三课·一弧胜双线。正式关卡：弧线过点、谷底回弹、随波前行、三轨入画。七关均按真实物理重新设计并通过参考解验证。

教程使用“聚光灯引导”（spotlight onboarding）与渐进披露：非目标区域压暗，当前操作控件高亮；完成当前操作后由玩家点击“继续”，不会自动跳步。关卡 JSON 的 `tutorial.features` 控制添加函数与模板选择是否可见，`tutorial.steps` 配置目标、文案与推进方式。

| 目录 / 文件 | 用途 |
| --- | --- |
| scenes/main.tscn；scripts/ui/ | 最终 UI 与启动入口 |
| scripts/adapters/physics_run_adapter.gd | UI 与 A 核心适配 |
| scenes/core_world.tscn；scripts/core/ | 状态、采样、碰撞、存档 |
| data/levels.json | 正式关卡，schema_version 1 |
| tests/ | 自动验证与截图脚本 |
| tests/fixtures/legacy_level_data.gd | A 原三关归档，不在正式选关中 |
| artifacts/ | 测试日志与实际渲染截图 |
| A_CORE_INTERFACE.md | 合并后接口说明 |

## 后续加内容

加关卡时在 `data/levels.json` 追加唯一稳定 ID，填写模板白名单、起终点、检查点、危险区、提示、初始公式和可通关参考解。JSON 坐标/域为数组，读取后转 Godot 类型；复制现有关卡结构并通过格式校验、真实物理、选关和存档回归。

加函数时先扩展 `formula_catalog.gd` 注册信息，再扩展核心类型、模型、求值/导数、验证与材质，补充真实运行用例。当前注册表集中元数据，不是任意函数插件系统。

稳定保留已有关卡 ID；存档结构变化要增加版本与迁移。内容通过更新工程/导出包交付，按技术文档维护。项目不需要联网自动更新；首版不做热重载或玩家关卡编辑器。

## 验证

2026-10-29：核心检查通过 1210 项；完整场景检查通过 120 项，七个参考解均实际通关；弹性性能检查通过 97 项。实际 Compatibility 渲染检查覆盖教程聚光灯、七关选关页、1440×900 主要页面与 1100×720 游戏页。

在本目录执行：

```text
godot --headless --path . --fixed-fps 120 --script res://tests/core_smoke_test.gd
godot --headless --path . --fixed-fps 120 --script res://tests/runtime_smoke_test.gd
godot --headless --path . --fixed-fps 120 --script res://tests/elasticity_performance_test.gd
```

退出码 0 且日志 PASS 为通过；测试使用专用测试存档路径。Windows 日志采集可用 `Start-Process -Wait -PassThru -WindowStyle Hidden` 加标准输出/错误重定向。截图脚本为 `tests/visual_review.gd`，需实际图形渲染，结算截图为展示构造，七关通关证据以运行测试为准。

独立安装包、Web 导出、其他平台与浏览器物理一致性尚未验收。复杂曲线的碰撞形状数量随采样增长；增加高频函数前需评估采样精度与性能。

编辑参数时只生成曲线预览，点击运行后才建立物理碰撞体；物理以 120 Hz 运行，画布动态状态最多以 60 Hz 更新。二次轨道默认回弹 0.80、摩擦 0.08，直线与正弦轨道保持无回弹。

## 项目资料

仓库根目录中的 `DESIGN-CHECKLIST.md` 和 `DESIGN-CHECKLIST1.md` 是项目设计过程中的历史清单，仅供参考，不覆盖本 README 描述的最终规则。
