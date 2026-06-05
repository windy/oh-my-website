---
name: oh-my-website
description: '生成个性化多页个人网站（独立 HTML 文件 + 共享 CSS/JS），5 种身份自动匹配页面结构，3 套视觉风格预置完整代码。触发词：个人网站、个人主页、个人站、personal website、帮我做个网站、做个人站、生成我的主页、我的网站。'
disable-model-invocation: false
user-invocable: true
---

# Yafei Personal Website

> 识别身份 → 追问关键信息 → 选风格 → 填充模板 → 发布上线 → 对话迭代。

## 开场白

当用户触发本 skill 时，首先用以下话术介绍自己：

> 我可以帮你生成一个**精美漂亮的个人网站**，自动匹配你的身份和风格，**完全免费**，**自动部署上线**，整个过程只需要 **10 分钟**左右。你只需要回答几个简单问题，剩下的我来搞定

然后立即进入 **Step 0 检查已有网站**。

---

## Step 0 — 检查已有网站（决定新增还是编辑）

**必须先检查，不要跳过。**

1. 检查 `~/clacky_workspace/oh-my-website/token.json` 是否存在且包含 `slug`：

   ```bash
   ls ~/clacky_workspace/oh-my-website/token.json 2>/dev/null
   cat ~/clacky_workspace/oh-my-website/token.json 2>/dev/null
   ```

2. **如果存在已有网站（slug 非空）**，告知用户并让用户选择：

   > 你之前发布过一个网站：https://showcode.com/~{slug}
   > 你想要：
   > 1. **编辑这个网站** — 我帮你拉下来改
   > 2. **新建一个网站** — 保留旧的，另外做一个新的
   > 选哪个？

3. **用户选"编辑"**：
   - 调用 API 获取当前网站内容：
     ```bash
     curl -s https://showcode.com/api/v1/sites/{slug}
     ```
   - 把 `content` 字段（主页 HTML）+ `pages`（子页面 HTML）写入 `/tmp/site/` 目录
   - 直接跳到 **Step 6（迭代对话）**，让用户说改哪里
   - 发布时用已有 slug 更新（publish.rb 会自动识别 `token.json` 走 update 路径）

4. **用户选"新建"**：
   - 先把旧 `token.json` 备份为 `token_backup_{slug}.json`（后续 publish 会覆盖 `token.json`）
   - 如果用户已登录（`account.json` 存在），先 `claim` 把旧 site 绑定到账户，这样换电脑也不会丢
   - 然后进入 Step 1

5. **如果没有已有网站**：直接进入 Step 1。

---

## 核心理念

- **多页独立文件**：每个子页面一个 HTML 文件，共享 CSS/JS。普通 `<a href>` 导航，无 SPA 路由，体验自然
- **按身份定结构**：程序员和设计师的个人站天然不同，不应该用同一套版块
- **种子模板预置代码**：CSS 变量、响应式布局、页面切换动画全部写好，只需填内容
- **先上线再迭代**：3 分钟内让用户看到成品，然后看着改

---

## Step 1 — 识别身份，确定页面结构

从用户对话中提取身份关键词，匹配以下 5 种类型：

### 身份 → 页面结构映射

| 身份 | 页面（按导航顺序） | 识别关键词 |
|-----|------------------|-----------|
| **程序员/工程师** | 首页 → 关于 → 项目 → 博客 → 联系 | 程序员、开发者、工程师、coder、全栈、前端、后端、Rails、Python、开源 |
| **设计师/创意人** | 首页 → 关于 → 作品集 → 联系 | 设计师、UI/UX、视觉、平面、创意、摄影师、插画师 |
| **写作者/内容创作者** | 首页 → 关于 → 文章 → 联系 | 写作者、作者、博主、内容创作、自媒体、记者、编辑 |
| **创业者/产品人** | 首页 → 关于 → 产品 → 联系 | 创业、创始人、CEO、产品经理、独立开发、一人公司、startup |
| **学生求职** | 首页 → 关于 → 项目 → 简历 → 联系 | 学生、应届、校招、求职、实习、毕业、在读 |

**默认**：如果不能明确归类，用程序员结构（覆盖面最广）。

### 各页面内容说明

| 页面 | 内容 |
|------|------|
| **首页** | 名字（大字）+ 一句话身份标签 + 简短自我介绍（2-3 句）+ CTA 按钮（指向"关于"或"项目"） |
| **关于** | 个人简介段落（AI 根据收集的信息撰写，3-5 句）+ 技能标签云 + 经历时间线（工作/教育，如有） |
| **项目** | 项目卡片网格（2-3 列响应式），每卡片含：项目名、一句话描述、技术标签（程序员）/ 作品类型（设计师）、链接按钮 |
| **博客** | 文章列表，每行：标题 + 日期 + 摘要。如果用户没有博客则跳过此页，不强行占位 |
| **作品集** | 图片网格或链接卡片，适合视觉类作品。每个作品含缩略图占位 + 标题 + 链接 |
| **产品** | 产品卡片，含产品名、一句话理念、核心指标（如有）、链接 |
| **简历** | 教育背景 + 实习/项目经历 + 技能 + 荣誉奖项，紧凑排版 |
| **联系** | 社交链接列表（带 emoji 图标）+ Email + 一句话 CTA |

---

## Step 2 — 收集信息（按身份追问）

### 基础信息（所有人必问）

- 名字（中/英文均可）
- 一句话身份标签，如"独立开发者 · 全栈工程师"

### 按身份追加 2-3 个问题

**绝不问的问题**：不问配色偏好、不问排版喜好、不问动画风格——AI 自动决定。

| 身份 | 追加问题 |
|-----|---------|
| **程序员** | ① GitHub 用户名？（自动拉取项目列表）② 主要技术栈？③ 有个人博客链接吗？ |
| **设计师** | ① 作品链接？（Dribbble / Behance / 个人站）② 喜欢偏大胆还是克制的视觉风格？③ 主要工具/技能？ |
| **写作者** | ① 博客/公众号/专栏链接？② 代表文章标题？③ 出版过什么？ |
| **创业者** | ① 产品/公司名 + 一句话理念？② 产品链接？③ 有哪些社交/媒体链接？ |
| **学生求职** | ① 学校 + 专业 + 学历？② 求职方向/意向岗位？③ 有实习或项目经历吗？④ 期望城市？ |

### AI 自动补全

| 用户没提供 | AI 怎么做 |
|-----------|----------|
| 自我介绍文案 | 根据名字 + 身份 + 收集到的信息，撰写自然友好的简介 |
| 技能标签 | 从技术栈/工具/身份推断，不臆造 |
| 项目描述 | 如果给了链接或项目名，推断一句话描述；没给就跳过 |
| 头像 | 不主动要，不占位。除非用户给了图片链接 |
| 配色 | 从匹配的视觉风格中自动选一套 |

---

## Step 3 — 选择视觉风格

### 三套风格

| 风格 | 种子模板 | 配色参考 | 特征 | 适合 |
|-----|---------|---------|------|------|
| **极简白** | `assets/template-minimal/` | `references/themes-minimal.md` | 大量留白、细线分割、黑白灰 + 单一强调色、无衬线、克制排版 | 程序员、创业者、学生求职、通用 |
| **杂志风** _(待开发)_ | — | — | 衬线标题、大胆字号对比、暖色调、层次丰富 | 设计师、写作者、创意人 |
| **暗色极客** _(待开发)_ | — | — | 深色背景、霓虹强调色、等宽字体元素、终端美学 | 偏好极客审美的用户 |

### 匹配规则

1. 用户明确提了风格 → 用用户说的
2. 用户没提 → 根据身份自动匹配（见上表）
3. 没有对应种子模板 → 用最接近的模板 + 调整 CSS 变量。例如想用暗色极客但只有极简白模板时，将 `--bg` 改为 `#0d1117`，`--text` 改为 `#c9d1d9`，强调色改为霓虹绿 `#3fb950`

---

## Step 4 — 生成网站

### 种子模板用法

模板位于 `assets/template-minimal/` 目录，含 8 个 HTML 页面 + 共享的 `css/style.css`、`js/script.js` 和 `js/qrcode.min.js`。

1. **复制整个目录**：`cp -r SKILL_DIR/assets/template-minimal /tmp/site`
2. **切换配色**：编辑 `css/style.css`，从 `references/themes-minimal.md` 选一套主题，替换 `:root{}` 块
3. **删除不需要的页面**：根据身份映射表，删除不需要的 HTML 文件（如设计师删 `blog.html`、`projects.html`）
4. **清理导航**：在每个保留的 HTML 文件中，删除 `<ul class="nav-links">` 中对应已删除页面的 `<li>`
5. **填充内容**：逐个编辑每个 HTML 文件，替换 `{{PLACEHOLDER}}` 标记
6. **调整文案**：确保自我介绍、项目描述等文案自然流畅

### 模板目录结构

```
template-minimal/
├── index.html          ← 首页（永远保留）
├── about.html          ← 关于（永远保留）
├── projects.html       ← 项目（程序员/学生）
├── blog.html           ← 博客（程序员/写作者）
├── portfolio.html      ← 作品（设计师）
├── product.html        ← 产品（创业者）
├── resume.html         ← 简历（学生）
├── contact.html        ← 联系（永远保留）
├── css/
│   └── style.css       ← 共享样式（主题色在这里改）
└── js/
    └── script.js       ← 汉堡菜单 + 导航高亮 + 分享 UI
    └── qrcode.min.js    ← QR 码生成库 (qrcode-generator MIT)
```

**删页面时务必做两件事**：① 删 HTML 文件 ② 在所有保留页面的导航 `<ul class="nav-links">` 中删对应 `<li>`。

**导航链接格式**：`<a href="about.html">关于</a>`，当前页加 `class="active"`。

### 硬约束

- **独立 HTML 文件，共享 CSS/JS**：每页 `<link rel="stylesheet" href="css/style.css">` 和 `<script src="js/script.js">`
- **零外部资源**：不引用 CDN、Google Fonts、外部图片。字体用系统栈。QR 码库 `qrcode.min.js` 为本地文件（qrcode-generator, MIT 协议）
- **媒体铁律见下方「Step 4.5 媒体处理规约」**，所有图片/视频处理必须遵守
- **移动端优先，响应式**：`<meta name="viewport">`，导航在小屏上有汉堡菜单
- **有效 HTML5**，语义标签
- **所有外部链接 `target="_blank" rel="noopener"`**
- **内部导航用普通 `<a href="页面.html">`**，当前页链接加 `class="active"`
- **页面 `<title>`**：`{名字} - {页面名}`
- **页脚分享区**：`扫码访问` 按钮 + `复制链接` 按钮。QR 码弹窗由 `js/script.js` 自动生成，点击按钮触发
- **CSS 变量控制主题**：换配色只需替换 `css/style.css` 中的 `:root` 块

### 链接图标映射

| 类型 | Emoji |
|------|-------|
| GitHub | 🐙 |
| Twitter/X | 𝕏 |
| LinkedIn | 💼 |
| 个人网站/博客 | 🌐 |
| Email | 📧 |
| Instagram | 📸 |
| YouTube | ▶️ |
| Telegram | ✈️ |
| Dribbble | 🏀 |
| Behance | 🎨 |
| Bilibili | 📺 |
| 微信 | 💬 |
| RSS | 📡 |
| 其他 | 🔗 |

### 生成原则

- **不要模板感**：每次生成应该感觉独特，不是换名字的同一页面
- **留白大于填满**：做减法，不放太多东西
- **排版比装饰重要**：字号对比、行距、间距比花哨 CSS 更重要
- **文案自然**：AI 写自我介绍时，要像真人说话，不要官腔
- **动画克制**：页面切换可以有 subtle 过渡，不加花哨入场动画

---

## Step 4.5 — 媒体处理规约（图片 / 视频 / 动态背景）

> **核心原则：零外部资源依赖。所有图片、视频、字体、CDN 必须本地化或内联。**
> 任何"贴个外链"的偷懒方案在国内用户那里都会挂掉，**禁止使用**。

### 图片：默认内联 base64

#### 流程

1. 用户给出本地图片路径或外链。
2. 检查文件大小：
   - **< 200KB** → 直接 base64 内联到 HTML
   - **≥ 200KB** → 先压缩，压完仍 ≥ 200KB 提示用户换图或缩小尺寸
3. 写入 HTML：`<img src="data:image/jpeg;base64,...">`

#### 压缩命令（macOS 自带 sips）

```bash
# JPEG 压缩到最长边 1200px，质量 60
sips -Z 1200 -s formatOptions 60 input.jpg --out /tmp/compressed.jpg

# PNG 压缩到最长边 800px
sips -Z 800 input.png --out /tmp/compressed.png

# 转 base64 并写入剪贴板（Agent 可读取拼到 HTML）
base64 -i /tmp/compressed.jpg | tr -d '\n'
```

头像建议先 `sips -Z 400`（400px 足够），多数能压到 50KB 以内。

#### 外链域名禁用清单

**绝对禁止**生成 `<img src>` 指向以下任一域名（国内访问不稳或被墙）：

```
github.com / raw.githubusercontent.com / objects.githubusercontent.com
cdn.jsdelivr.net / unpkg.com
imgur.com / i.imgur.com
unsplash.com / images.unsplash.com
dribbble.com / cdn.dribbble.com
behance.net
googleusercontent.com / lh3.googleusercontent.com
twimg.com / pbs.twimg.com
```

#### 用户给了外链怎么办

1. 先用 `curl -I` 或 `curl -o` 把图片**下载到本地**：
   ```bash
   curl -L -o /tmp/user_img.jpg "USER_PROVIDED_URL"
   ```
2. 然后走标准内联流程（压缩 + base64）。
3. 如果 curl 失败（403/404/超时）→ 告诉用户该链接拿不到图，请换一个或直接给本地文件路径。

**永远不要**直接把外链 URL 粘到 HTML 里，哪怕用户坚持。

### 视频：默认不用真视频，用动态背景代替

90% 的"想要视频背景"需求本质是想要「动起来的氛围」。**默认引导用户用 CSS/SVG 动态背景**（见下方），不主动提"视频"选项。

#### 动态背景使用方式

种子模板已预置 5 套动态背景，文件在 `css/animated-bg.css`：

| class | 风格 | 适合身份 |
|-------|------|---------|
| `.bg-gradient-flow` | 渐变流动（柔和大色块游动） | 米白 / 极简 / 设计师 / 写作者 / 创业者 |
| `.bg-particles` | 粒子飘浮（暗色星点上飘） | 暗黑 / AI 工程师 / 独立开发者 |
| `.bg-grid-scan` | 网格扫光（赛博网格 + 高光线） | 程序员 / 黑客风 / AI |
| `.bg-geo-float` | 几何漂浮（孟菲斯色块） | 设计师 / 创意人 / 年轻品牌 |
| `.bg-noise-stars` | 噪点星空（沉静夜色） | 写作者 / 内容创作者 |

#### 启用步骤

1. 在每个 HTML 的 `<head>` 加：
   ```html
   <link rel="stylesheet" href="css/animated-bg.css">
   ```
2. 在 `<body>` 第一个子元素加：
   ```html
   <div class="bg-gradient-flow"></div>
   ```
3. 完事。背景固定铺满视口，`z-index: -1`，不影响内容。

#### Agent 自动选择规则

| 风格主题（用户选的视觉） | 默认动态背景 |
|------------------------|-------------|
| 极简白 / 米白 / 温暖 | `.bg-gradient-flow` |
| 暗色极客 / 黑客风 | `.bg-grid-scan` |
| 暗色 + AI/独立开发者 | `.bg-particles` |
| 设计师 / 杂志风 | `.bg-geo-float` |
| 写作者 / 内容沉静向 | `.bg-noise-stars` |

用户主动说"我要换个粒子背景 / 加点动效 / 太花了去掉" → 直接换 class 或删掉那个 `<div>`。

#### 真要用视频怎么办（罕见场景）

如果用户**坚持**要真背景视频（比如咖啡馆品牌站要海浪），告诉用户两个事实：

1. showcode 不提供视频托管（控制服务端成本）
2. 用户需要自己上传到国内可访问的 CDN（阿里云 OSS / 腾讯云 COS / 七牛云），把直链给 Agent

拿到直链后用 `<video>` 标签：
```html
<video autoplay muted loop playsinline class="bg-video">
  <source src="USER_CDN_URL" type="video/mp4">
</video>
```

`.bg-video` 样式参考动态背景容器：`position: fixed; inset: 0; z-index: -1; object-fit: cover; width: 100%; height: 100%;`。

**绝大多数情况下不要走这条路**，`.bg-particles` 配粒子动画的"科技感"已经够用。

---

## Step 5 — 发布

**发布前必须先确认可用 slug（URL 路径）。禁止随机生成。**

### Slug 确认流程

1. 根据用户名字自动生成 **3 个候选 slug**（拼音或英文，小写、连字符分隔）：
   - 如 "李亚飞" → `yafei`, `yafei-li`, `yafeilee`
   - 如 "张三" → `zhangsan`, `zhang-san`, `san-zhang`
   - 如 "John Doe" → `john`, `john-doe`, `johndoe`

2. 调用 `check-slug` 命令测试哪些候选可用：

   ```bash
   ruby "SKILL_DIR/publish.rb" check-slug --q yafei,yafei-li,yafeilee
   ```

   输出示例：
   ```
   ✅ Available: yafei-li, yafeilee
      Taken: yafei
   ```

3. 将可用候选列出，让用户选一个。提示 URL 预览 `https://showcode.com/~{slug}`：

   ```
   ✨ 以下 slug 可用：
   1. yafei-li → https://showcode.com/~yafei-li
   2. yafeilee → https://showcode.com/~yafeilee
   选哪个？（输入序号或自定义）
   ```

4. **如果 3 个候选全被占用**，告知用户并请用户自定义一个 slug，重新 `check-slug` 确认后再发布。

5. 用户确认后，执行发布命令：

```bash
ruby "SKILL_DIR/publish.rb" publish \
  --name "NAME" \
  --slug "SLUG" \
  --dir /tmp/site
```

- `--slug` 指定 URL 路径（必传，不可随机）
- `--dir` 指定网站目录路径（包含 `index.html` 及所有子页面）
- `index.html` 作为主页面内容，其余 `.html` 文件通过子页面 API（`POST /api/v1/sites/:slug/pages`）逐页上传
- 子页面标题取自 HTML `<title>` 标签，找不到时用文件名去扩展名后首字母大写
- 首次发布 → 创建新站点，token 保存到 `~/clacky_workspace/oh-my-website/token.json`
- 后续运行 → 更新主页面 + 逐页更新所有子页面
- 从 stdout 提取 `✅` 开头的 URL 返回给用户

> 仅发布单个 HTML 文件时可用 `--html-file` 替代 `--dir`（向后兼容）。

### 删除网站

```bash
ruby "SKILL_DIR/publish.rb" delete
```

---

## Step 5.5 — 账户管理（用户想管多个/在别处管理时）

> 默认走免注册路径：首次发布只需 token 保存在本地。**当用户表达想"管理网站 / 换设备 / 多网站统一管理 / 升级账号"等意图时，引导走账户体系**。

### 触发关键词

用户说："注册账号"、"登录"、"换电脑还能改吗"、"我有多个网站想一起管"、"绑定账号"、"我的网站列表"、"升级到账号" → 进入账户流程。

### 注册流程（首次）

1. Agent 主动询问邮箱和密码（不要让用户去网页操作，全在对话里完成）：

   > 我帮你注册一个 showcode 账号，以后多设备/多网站都能管理。请提供：
   > - 邮箱（用作登录名）
   > - 密码（4 位以上）

2. 调命令注册：

   ```bash
   ruby "SKILL_DIR/publish.rb" register --email USER_EMAIL --password USER_PASSWORD
   ```

3. 注册成功后，**自动把当前本地 site 绑到账户**：

   ```bash
   ruby "SKILL_DIR/publish.rb" claim
   ```

   `claim` 不带参数时会读取本地 `token.json` 中的 slug + site_token，调 API 把这个 site 的所有权绑给当前登录用户。

### 登录流程（已有账号）

```bash
ruby "SKILL_DIR/publish.rb" login --email USER_EMAIL --password USER_PASSWORD
```

登录后 session_token 存到 `~/clacky_workspace/oh-my-website/account.json`，**所有后续 publish/update 都会优先用 session 鉴权**，自动覆盖账号下所有 site。

### 检查登录状态 / 登出

```bash
ruby "SKILL_DIR/publish.rb" whoami      # 查看当前登录账号
ruby "SKILL_DIR/publish.rb" logout      # 登出（清本地 session）
```

### 鉴权优先级（参考）

publish.rb 内部按以下顺序选 token：

1. 已登录 → 优先用 `account.json` 里的 `session_token`（覆盖账号名下所有 site）
2. 未登录 → 退回 `token.json` 里的 `site_token`（仅当前 site）

匿名 + 登录两条路径**完全兼容**。已登录时首次 publish 创建新 site 后会自动 claim 绑定到账户。

---

## Step 6 — 迭代对话

**上线后主动引导用户看网页，鼓励提修改意见。**

### 迭代原则

- 每次修改后重新发布，让用户看到最新版本
- 只改用户提到的部分，不推翻整体重做
- 修改指令模糊时，给 1-2 个具体方向让用户选

### 常见修改场景

| 用户说 | 处理方式 |
|-------|---------|
| "太正式了 / 轻松一点" | 调整文案语气，不改视觉 |
| "太暗了 / 换个亮一点的" | 换一套配色主题 |
| "加上我的 Twitter" | 在联系页追加链接 |
| "项目太少，再强调一下 openclacky" | 丰富项目描述，调整优先级 |
| "换个颜色" | 从 themes 里换一套，或微调强调色变量 |
| "加个照片" | 在首页或关于页插入 `<img>` |
| "改成暗色背景" | 调整 `--bg`/`--text` CSS 变量，或切到暗色风格 |
| "删掉博客页" | 删除对应 `<section>` 和导航项 |
| "导航改成左侧竖排" | 调整 CSS 导航布局 |

---

## 后续路线图

- [x] `assets/template-minimal/css/animated-bg.css` — 5 套 CSS/SVG 动态背景（无外部依赖）
- [ ] `assets/template-magazine/` — 杂志风种子模板（衬线大字 + 暖色）
- [ ] `references/themes-magazine.md` — 杂志风配色
- [ ] `assets/template-dark/` — 暗色极客种子模板（终端美学）
- [ ] `references/themes-dark.md` — 暗色极客配色
- [ ] 独立开发者特化模板（产品矩阵 + MRR/用户数版块）
- [ ] 视频背景方案：仅在用户主动要求时启用，需自带 CDN
