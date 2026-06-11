# Oh My Website · AI 驱动的多页个人网站生成器

![GitHub stars](https://img.shields.io/github/stars/windy/oh-my-website?style=flat-square)
![License](https://img.shields.io/badge/License-AGPL--3.0-blue?style=flat-square)
![Claude Code](https://img.shields.io/badge/Claude_Code-Supported-D97706?style=flat-square)
![Codex](https://img.shields.io/badge/Codex-Supported-111111?style=flat-square)
![Skill](https://img.shields.io/badge/Skill-Agent-111111?style=flat-square)
![HTML](https://img.shields.io/badge/HTML-Multi%20Page-0A7CFF?style=flat-square)
![OpenClacky](https://img.shields.io/badge/OpenClacky-Supported-6B5B95?style=flat-square)

> 把「帮我做个个人网站」变成一句可执行的指令。

一个适配 任一 Agent 环境的个人网站技能——**按身份自动匹配页面结构，AI 撰写文案，多页独立 HTML 文件，CSS 变量一键换肤，发布即上线**。

查看真实案例：https://showcode.com/~yafeilee/

内置多套视觉系统（官方推荐「Apple 极简风」，其他风格持续完善中）：

- 🍎 **Apple 极简风 (Apple Style - 官方强推)**：极致打磨的高端美学设计。磨砂玻璃导航栏、精致微光卡片、大留白、柔和毛玻璃和高质感动画。深度适配所有页面，推荐所有人首选！
- 🤍 **极简白 (Minimal)**：经典细线分割，黑白灰 + 单一强调色。适合极客、技术开发者、求职简历。
- 🧸 **温暖工作室 (Warm Studio)**：温暖柔和的大地米色系、舒适色调、圆润阴影。适合个人工作室、文创、独立设计师。
- 📰 **杂志风 (Magazine)**：优雅的衬线大标题、鲜明视觉对比。适合写作者、编辑、创意总监。

> 由 [windy](https://github.com/windy) 在反复折腾个人网站的过程中沉淀而成——为什么每个人的个人站都要从零写一遍？

## 30 秒开始

在任一 Agent（ClaudeCode、Codex、WorkBuddy、OpenClacky 等）中，输入这段话即可自动安装：

```text
帮我安装这个 skill: https://github.com/windy/oh-my-website
```

已经安装过的话，用这段话更新：

```text
帮我更新这个 skill: https://github.com/windy/oh-my-website
```

安装后直接对 Agent 说：

```text
帮我做个个人网站，我是全栈工程师，主要用 Rails 和 Python，GitHub 是 windy。
```

也可以试这些请求：

```text
帮我做个极简的个人站，我是设计师，有 Dribbble 作品集。
帮我的产品做一个独立主页。
我的个人站太暗了，换个亮一点的配色。
在联系页加上我的 Telegram 和 Twitter。
```

## 效果

- **5 种身份映射**：程序员、设计师、写作者、创业者、学生求职，自动匹配页面结构（首页/关于/项目/博客/作品/产品/简历/联系）
- **多页独立文件**：8 个子页面各一个 HTML，共享 CSS/JS，普通 `<a href>` 导航，无 SPA 路由
- **5 套配色预设**：石墨、靛蓝、赭石、松绿、梅红，CSS 变量一键切换
- **AI 撰写文案**：根据名字、身份、收集到的信息自动撰写自然友好的自我介绍、项目描述
- **移动端优先**：响应式布局，小屏汉堡菜单，系统字体栈
- **零外部依赖**：不引用 CDN、Google Fonts、外部图片，纯静态可离线浏览
- **一键发布**：`publish.rb` 直接将网站目录发布上线，返回公开 URL
- **对话迭代**：发布后持续对话修改——换配色、加链接、改文案、调排版

## 适合 / 不适合

**合适**：想快速拥有个人主页的程序员、设计师、创业者 / 求职需要在线简历 / 产品独立介绍页 / 个人博客入口 / 名片式社交链接聚合

**不合适**：需要 CMS 后台编辑内容 / 需要用户登录和评论 / SEO 重度依赖（纯前端 HTML）/ 需要多语言 i18n

## 常见使用场景

| 任务 | 推荐方式 |
|------|---------|
| 程序员个人主页 | 说「我是 XX 方向工程师」，AI 自动匹配项目+博客结构 |
| 设计师作品集 | 说「我是设计师，有 Dribbble」，AI 自动用作品集页面 |
| 产品独立页 | 说「帮我的产品 XX 做个主页」，AI 用产品页+联系页 |
| 求职简历站 | 说「我在找 XX 方向的工作」，AI 匹配简历页+项目页 |
| 配色不满意 | 说「换个颜色」，AI 从 5 套主题里切换 |
| 加社交链接 | 说「加上我的 Twitter / GitHub / Instagram」 |
| 删掉某个页面 | 说「不要博客页」，AI 删文件+清理导航 |
| 改文案 | 说「自我介绍太官腔了，轻松一点」 |

## 为什么是多页 HTML

- **URL 即导航**：`/about.html` 可以直接分享、收藏、刷新，不需要前端路由
- **更适合 Agent 生成和修改**：每个页面独立文件，Agent 能精准定位、修改、验证
- **表现力更高**：CSS 可以做精细排版、空间定位、动画和响应式布局
- **交付更轻**：纯静态文件，不需要构建、不需要服务器、不需要 npm install
- **更好的用户体验**：普通链接导航，浏览器前进后退正常工作，没有 SPA 的「怪怪的」感觉
- **CSS 变量主题系统**：换一套配色只需替换 `:root` 块，不改任何 HTML

## 平台支持

| 平台 | 状态 | 说明 |
|------|------|------|
| OpenClacky | 支持 | 原生 Skill 工作流，适合生成和迭代多页网站 |
| Claude Code | 可用 | 需要能读写文件并执行 shell 命令 |
| Cursor / 其他本地 Agent | 可用 | 需要能读写文件并执行 shell 命令 |
| 普通 Chatbot | 不推荐 | 没有文件系统和浏览器预览时，很难稳定生成完整网站 |

## 安装

在任一 Clacky Agent 中，输入这段话即可自动安装：

```text
帮我安装这个 skill: https://github.com/windy/oh-my-website
```

或者通过命令行克隆到本地 Skill 目录：

```bash
git clone https://github.com/windy/oh-my-website.git ~/.clacky/skills/oh-my-website
```

### 触发方式

装好后，Agent 会在对话里自动发现并调用这个 skill。触发关键词：

- "帮我做个个人网站"
- "帮我做个人主页"
- "给我做个人站"
- "personal website"
- "生成我的主页"
- "我的网站"

## 使用流程

Skill 本身是结构化工作流，Agent 会逐步引导：

1. **识别身份** — 从你的对话中提取关键词，匹配 5 种身份之一
2. **收集信息** — 按身份追问 2-3 个关键问题（如 GitHub 用户名、技术栈、作品链接）
3. **选择风格** — 根据身份自动匹配极简白 / 杂志风 / 暗色极客（或尊重你的偏好）
4. **生成网站** — 复制种子模板目录 → 删不需要的页面 → 清理导航 → 替换 `:root` 配色 → 填充内容
5. **发布上线** — 运行 `publish.rb` 发布到线上，返回公开 URL
6. **对话迭代** — 看着成品改文案、换配色、加链接、调排版

详细说明见 [`SKILL.md`](./SKILL.md)。

## 极简白 · 配色方案

从 `references/themes-minimal.md` 里选一套——换配色只需替换 `css/style.css` 中的 `:root` 块。

| 主题 | 强调色 | 适合场景 |
|------|--------|---------|
| 🖤 **石墨 (Graphite)** | `#2d2d2d` | 程序员、创业者、通用默认 |
| 💙 **靛蓝 (Indigo)** | `#3347d0` | 技术管理者、产品人 |
| 🤎 **赭石 (Ochre)** | `#b8753e` | 写作者、设计师、创意人 |
| 💚 **松绿 (Pine)** | `#3d7a52` | 清新活力、学生求职 |
| 💜 **梅红 (Plum)** | `#b8485e` | 有温度、个人化表达 |

如果用户没有指定配色，根据身份自动选择。不确定时默认用石墨（最安全）。

## 核心设计原则

1. **多页独立优于 SPA** — URL 可分享可收藏，浏览器前进后退正常工作
2. **AI 决定视觉** — 不问用户配色偏好和排版喜好，从预设中自动选
3. **先上线再迭代** — 3 分钟内让用户看到成品，然后看着改
4. **留白大于填满** — 做减法，每个页面信息密度要低
5. **排版比装饰重要** — 字号对比、行距、间距比花哨 CSS 更重要
6. **文案要像人** — AI 写自我介绍时自然友好，不要官腔
7. **零外部依赖** — 不引用 CDN、Google Fonts、外部图片，系统字体栈
8. **移动端优先** — 响应式布局，小屏汉堡菜单

## 目录结构

```
oh-my-website/
├── SKILL.md                        ← Skill 主文件：工作流、内置原则、对话话术引导与错误防范
├── README.md                       ← 本文件
├── publish.rb                      ← 自动发布上线脚本（发布即产生 showcode.com 公开链接）
├── assets/
│   ├── template-apple/             ← 🍎 Apple 极简风种子模板（已就绪，官方主推🌟）
│   ├── template-minimal/           ← 🤍 极简白种子模板（已就绪）
│   ├── template-warm-studio/       ← 🧸 温暖工作室种子模板（已就绪）
│   └── template-magazine/          ← 📰 杂志风种子模板（已就绪）
└── references/
    └── themes-minimal.md           ← 极简白配色主题方案
```

## Roadmap

- [x] `assets/template-apple/` — Apple 极简风种子模板（已深度适配并推荐为默认首选）
- [x] `assets/template-warm-studio/` — 温暖工作室种子模板（已就绪）
- [x] `assets/template-magazine/` — 杂志风种子模板（已就绪）
- [x] `assets/template-minimal/` — 极简白种子模板（已就绪）
- [ ] 更多页面类型（FAQ、Timeline、Gallery）
- [ ] 多语言支持（英文模板）

## FAQ

**和单文件 SPA 模板有什么区别？**
每个页面是独立的 HTML 文件，用普通 `<a href>` 链接导航。URL 可以直接分享、收藏、刷新——没有前端路由的怪异感。对 Agent 来说，独立文件比单文件多 section 更容易精准修改。

**需要服务器吗？**
不需要。生成的网站是纯静态 HTML/CSS/JS，支持一键布署到 showcode.com 上。

**我能自己选配色吗？**
可以。目前多套高质感模板覆盖了不同审美方向，也允许你提具体色彩或视觉偏好。

**能加图片吗？**
可以在首页或关于页手动插入 `<img>` 标签。当前模板默认使用精心设计的优雅 SVG / 预设插画作为占位，若提供具体照片，AI 也会为你精准替换并适配。

**怎么更新到最新版？**
在任一 Agent 中发送：`帮我更新这个 skill: https://github.com/windy/oh-my-website`，或者在本地 skill 目录（`~/.clacky/skills/oh-my-website`）下执行 `git pull`。

**杂志风和暗色极客什么时候出？**
已全部就绪！您可以在对话中随意切换或由 AI 推荐。

## 贡献

Bug、排版问题、新页面类型需求——欢迎开 Issue 或 PR。改动请优先：

- 在 `template-minimal/css/style.css` 里补样式类
- 新增页面类型时同步更新 `SKILL.md` 的映射表
- 新主题色进 `references/themes-minimal.md` 并给出适合的场景
- 把踩过的坑写到 `SKILL.md` 的对应章节

## License

AGPL-3.0 © 2026 [windy](https://github.com/windy)
