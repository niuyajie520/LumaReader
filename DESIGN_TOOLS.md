# 设计工具（前端设计 skill）

LumaReader 的界面规范参考了两套开源的 AI 设计 skill。规范本身已经写进根目录 [`DESIGN.md`](DESIGN.md)，所以**不装这两个 skill 也能照规范改界面**：任何读 `AGENTS.md` 的 AI 工具都会被指向 `DESIGN.md`。

想让电脑上的 AI 编程工具（Claude Code、Codex、Cursor 等）长期带着这两套 skill 工作，就在 Mac 上装一次。

## 安装

打开「终端」（启动台 → 其他 → 终端），先进入项目文件夹：

```bash
cd 你的/LumaReader/文件夹
```

然后分别运行：

```bash
npx impeccable install
npx skills add https://github.com/Leonxlnx/taste-skill --skill "design-taste-frontend"
```

- 需要先装 Node.js（https://nodejs.org，选 LTS 版）。`npx` 随 Node.js 一起装好。
- 安装过程中如果问你用哪个 AI 工具，选你正在用的那个。
- 网页版 Claude（claude.ai 聊天）装不进去，因为这两个 skill 要在本机跑脚本。

## 两套 skill 各管什么

| skill | 地址 | 在本项目里用到的部分 |
|---|---|---|
| impeccable | https://github.com/pbakaus/impeccable | 最贴合。它把工具类界面单独当一种模式，要求界面「消失在任务里」。本项目用了它的拒绝清单和交付前自检。 |
| taste-skill | https://github.com/Leonxlnx/taste-skill | 主要面向营销网站，大部分不适用于 App。只借用三条：一套系统、克制的悬停、不用紫色做装饰。 |

Ant Design、Element、EasyUI 没有装代码，只参考了它们公开的组件原则：固定控件尺寸、8 点间距、由轻到重的反馈、标准空状态。这些也都已写进 `DESIGN.md`。

## 给 AI 工具的提示

改界面前先读 `DESIGN.md`，再读 `AGENTS.md` 的红线。两者冲突时以 `AGENTS.md` 为准。按钮只用 `LumaButtonSystem.swift` 里的样式。
