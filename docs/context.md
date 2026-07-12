# Dialog Jumper

本 context 定义 macOS File Dialog 快速目录跳转产品中的核心术语，用于保持 specs、tickets 与后续实现语言一致。

## Language

**File Dialog**：
由 macOS 提供、用于选择打开位置或保存位置的标准窗口；MVP 范围包括 `NSOpenPanel`、`NSSavePanel` 及行为等同的系统标准 panel，不包括 app 自绘的文件选择 UI。
_Avoid_：文件选择器、任意 Open / Save 窗口

**Folder Jump**：
将当前活动的 File Dialog 导航到用户指定的目标文件夹，但不代替用户执行打开、选择或保存操作。
_Avoid_：Go to Folder、打开文件、自动保存

**Path Input**：
用户在附着 UI 中输入或粘贴目标文件夹路径并确认后执行 Folder Jump；支持绝对路径与 `~` 家目录展开；不是按名称模糊搜索。
_Avoid_：搜索框、Go to Folder 系统 sheet、fuzzy search

**Recent Folder**：
用户成功完成 Folder Jump 后，按最近使用顺序自动列出的文件夹候选（上限有限），供一键再次 Folder Jump；不是系统「最近打开的文件/文稿」。
_Avoid_：最近文件、Recent Documents、任意历史路径字符串、打开/保存落点观察（MVP 未做）

**Favorite Folder**：
用户显式固定、可长期保留的文件夹候选，供一键 Folder Jump。
_Avoid_：书签文件、Finder 边栏收藏（除非产品明确同步它们）
