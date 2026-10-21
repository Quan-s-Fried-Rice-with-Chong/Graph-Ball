# 数维弹球 · B 侧界面原型

在 Godot 中导入本目录的 `project.godot`，按 **F5** 运行。主场景是 `scenes/main.tscn`。

当前包含四个候选关卡、函数模板选择、参数滑条与数值输入、实时曲线、坐标网格、缩放平移、运行/暂停/重试/重置、检查点、障碍、关卡解锁、结算和帮助。窗口基准为 1440 × 900，最小窗口为 1100 × 720。

**当前小球沿曲线匀速移动；重力、真实滚动、反弹和轨道衔接尚未接入。** 四关的参考解已在演示运动中验证，它们是界面联调用的候选关卡，不能据此认定真实物理中也能通关。演示进度独立保存在 `user://b_prototype_progress.cfg`，接入正式逻辑时不要把它当正式通关记录。

## 操作

- 选择本关提供的函数，拖滑条或输入数值后按 Enter。
- 蓝线需接到起点；黄色圆环是必经检查点，绿色区域是终点，红色区域是障碍。
- 运行前自动恢复全景；滚轮上下、Shift + 滚轮左右、Ctrl + 滚轮缩放，中键拖动。
- 空格运行/暂停，R 重试，Esc 关闭帮助/选关或暂停。
- 重试保留参数；重置恢复本关初始模板与参数。运行和暂停期间锁定参数。
- 帮助和关卡选择会暂停正在运行的小球，关闭后点击继续。

## 文件分工

| 文件 | 用途 |
|---|---|
| `scenes/main.tscn` / `scripts/ui/main.gd` | 主界面与流程连接 |
| `scenes/components/formula_panel.tscn` | 公式面板，可独立改布局 |
| `scenes/components/graph_canvas.tscn` | 坐标画布，统一处理坐标变换 |
| `scenes/components/result_dialog.tscn` | 成功/失败结算浮层 |
| `scripts/ui/ui_theme.gd` | 统一字体、颜色和控件样式 |
| `scripts/core/formula_catalog.gd` | 三种模板、参数范围与演示曲线采样 |
| `data/levels.json` | 四关位置、障碍、检查点和初始参数 |
| `scripts/adapters/demo_run_adapter.gd` | 可替换的演示运动层 |
| `docs/AB_INTERFACE.md` | 与 A 对接的数据和事件约定 |
| `tests/smoke_test.gd` | 引擎内自动检查 |

界面使用系统中文字体候选：微软雅黑、Noto Sans CJK 等。当前 Windows 环境已检查中文显示；浏览器和其他系统的字体效果需要另行实测。

## 检查

在项目根目录执行：

```text
Godot --headless --path . --script res://tests/smoke_test.gd -- --prototype-test
```

把 `Godot` 换成你本机的可执行文件路径。测试使用临时演示存档，结束时删除，不覆盖正常试玩进度。检查包括四关演示解、起点不匹配、连续障碍碰撞、检查点、边界、超时、暂停、参数双向同步与锁定、重试/重置、解锁、存档和缩放。报告写入 `artifacts/smoke_report.json`。

引擎版本：本机 Godot 4.7.2 / GDScript / Compatibility。当前验证针对本地原型；尚未宣称网页导出、网页字体或真实物理验证通过。
