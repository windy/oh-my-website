---
name: oh-my-website
description: '生成个性化多页个人网站（独立 HTML 文件 + 共享 CSS/JS），N 种身份自动匹配页面结构，多套视觉风格动态发现（扫描 assets/template-*/meta.json）。也支持模板开发预览模式（给设计师/贡献者改主题用，仅用户明确说"开发模板/改主题"时触发）。触发词：个人网站、个人主页、个人站、personal website、帮我做个网站、做个人站、生成我的主页、我的网站；以及：开发模板、做新模板、加个主题、做个新主题、改模板、改主题、template dev、新增模板、贡献模板、模板预览、预览模板。'
disable-model-invocation: false
user-invocable: true
---

# Yafei Personal Website

> 识别身份 → 追问关键信息 → 选风格 → 填充模板 → 发布上线 → 对话迭代。

## ⚡️ 入口分流（必读，触发时第一步执行）

技能触发后，先判断用户的真实意图：

| 用户说什么 | 走哪条路 |
|----------|---------|
| 开发模板 / 做新模板 / 改模板 / 改主题 / 加个主题 / 做个新主题 / 预览模板 / 模板开发 / 我想贡献模板 | **流程 B：模板开发预览模式** → 跳到下方「模板开发模式」节，**不要**走开场白 |
| 其他一切（帮我做个网站 / 做个人主页 / 生成我的网站 / 做个人站 / 个人网站 / 甚至只说"网站"） | **流程 A：生成用户网站** → 走「开场白 + Step 0~6」 |

**除非用户明确说"开发/修改/预览模板"，否则一律走流程 A。** 不要问"你想生成网站还是开发模板"——绝大多数用户就是来建站的。

---

## 模板开发模式

> 仅在用户明确表达"开发/修改/预览模板"时进入。如果用户只是想要自己的网站，**不要**走这条路，直接走开场白。

### 进入此模式时第一件事：启动预览服务器

```bash
ruby SKILL_DIR/dev/server.rb
```

启动后告诉用户（**原话级别贴近这个**）：

> 已经开了模板开发模式，预览服务器跑在 http://localhost:4567/。
>
> 用 URL 参数切换（无工具栏，纯链接）：
> - `?persona=designer` → 切换身份预览
> - `?template=minimal` → 切换模板
> - `?template=minimal&persona=writer` → 同时切换
>
> 想改样式直接编辑 `assets/template-XXX/` 下的 HTML/CSS，刷新就能看到。
> **改满意了告诉我「保存提交」**，我会帮你建主题分支并 commit/push，避免丢数据。

### 用户说"做个新模板叫 XXX" / "新增一个 YYY 主题"

```bash
cd SKILL_DIR
git checkout -b theme/<XXX>                      # 起一个主题分支，避免污染 main
cp -r assets/template-minimal assets/template-<XXX>   # 用 minimal 起底（也可用 magazine）
ruby dev/server.rb template-<XXX>
```

提示用户："我已经基于 template-minimal 复制了一份叫 template-`<XXX>`，浏览器里切到这个新模板就能看。改 `css/style.css` 的 `:root` 块改主题色最快。"

### 用户说"保存 / 提交 / 我改完了 / 满意了 / commit"

按以下步骤执行（**全部用 SKILL_DIR 的 git，不要在用户工作目录跑**）：

1. 检查当前分支：`git -C SKILL_DIR branch --show-current`
2. 如果在 `main` 上 → 先建主题分支 `git -C SKILL_DIR checkout -b theme/<合理名字>`
   - 名字从用户改的 template 目录推断，比如改了 `template-dark-geek` → `theme/dark-geek`
3. `git -C SKILL_DIR add -A && git -C SKILL_DIR status` 确认范围合理（不要把 dev/ 临时文件带进去）
4. `git -C SKILL_DIR commit -m "feat(template-XXX): <一句话描述>"`
5. `git -C SKILL_DIR push -u origin <branch>`
6. 反馈用户：分支名 + commit hash + 远端 URL

### 占位符语法（贡献者写模板要遵守）

| 写法 | 含义 |
|------|------|
| `{{KEY}}` | 必填占位，Agent 替换为用户数据；预览时由 fixture 提供 |
| `{{KEY\|默认值}}` | 带保底默认值，fixture/Agent 都没提供时仍可渲染 |

KEY 命名约定：全大写下划线分词，如 `NAME`、`WORK_1_TITLE`、`PROJECT_CARDS`。

新增模板时如果用了新 KEY，**记得**在 `dev/fixtures/_defaults.json` 给个通用默认值，否则预览会显示黄色 `[KEY]` 提示框。

### 模板开发模式的注意事项

- 全程在 `SKILL_DIR/assets/template-XXX/` 工作，不要碰 `$SITE_DIR`（如 `/tmp/site-*`，那是用户网站生成阶段的目录）
- 不要走「开场白 + Step 0~6」那套流程，那是给最终用户的
- 不要 `publish.rb`，模板开发不发布
- 用户说"够了 / 退出 / 关掉" → Ctrl+C 杀 server，最后再问一遍要不要 commit

---

## 开场白（流程 A — 生成用户网站时使用）

当用户触发本 skill 且意图是生成自己的网站时，先用以下话术介绍自己（**原话级别贴近**）：

> 我可以帮你生成一个漂亮美观的个人网站，自动匹配你的身份和风格，**完全免费**，**自动部署上线**，整个过程只需要 **10 分钟**左右。之后你可以随时找我迭代修改。
>
> 你只需要回答几个简单问题，剩下的我来搞定。

话术要点：
- 必须涵盖：漂亮美观、10 分钟、免费部署、可不断迭代
- 说完**立刻进入 Step 0 检查已有网站**，不要再问"要不要开始"之类的废话

---

## Step 0 — 检查已有网站（决定新增还是编辑）

**必须先检查，不要跳过。**

1. 检查 `~/.oh-my-site/token.json` 是否存在且包含 `slug`：

   ```bash
   ls ~/.oh-my-site/token.json 2>/dev/null
   cat ~/.oh-my-site/token.json 2>/dev/null
   ```

2. **如果存在已有网站（slug 非空）**，告知用户并让用户选择：

   > 你之前发布过一个网站：https://showcode.com/~{slug}
   > 你想要：
   > 1. **编辑这个网站** — 我帮你拉下来改
   > 2. **新建一个网站** — 保留旧的，另外做一个新的
   > 选哪个？

3. **用户选"编辑"**：
   - 用 `publish.rb fetch` 拉取 CDN 上当前网站内容到临时目录：
     ```bash
     SITE_DIR="/tmp/site-$(date +%Y%m%d%H%M%S)"
     mkdir -p "$SITE_DIR"
     ruby "SKILL_DIR/scripts/publish.rb" fetch --slug "{slug}" --out "$SITE_DIR"
     ```
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
- **按身份定结构**：写代码和做学术的个人站天然不同，不应该用同一套版块
- **种子模板预置代码**：CSS 变量、响应式布局、页面切换动画全部写好，只需填内容
- **先上线再迭代**：3 分钟内让用户看到成品，然后看着改

---

## 占位符与开发预览

> 模板里所有用户可变内容都用 `{{KEY}}` 占位符。Agent 在 Step 4 用用户真实数据替换；贡献者改模板请走顶部「模板开发模式」节，用 `dev/server.rb` 配 fixture 数据预览。

占位符语法见顶部「模板开发模式 → 占位符语法」节，不重复。

---

## Step 0.5 — 智能跳过（用户已经给的信息别再问）

> **关键：Step 0 完成后，先检查用户触发时附带的消息里已经包含了哪些信息。已经给过的，跳过对应问题。**

| 用户已经给了 | 跳过 | 处理方式 |
|------------|------|---------|
| 名字 | Q1 | 直接用，不重复问 |
| 职业/身份描述（如"新媒体运营""前端工程师"） | Q2 | Agent 自行映射到 7 选 1 的类型，**一句话确认**（"你是新媒体运营，归到 C 写东西/做内容类，对吗？"），不等用户回复直接继续 |
| 亮点/成就/项目经历 | Q3 | Agent 从内容推断 Q3 答案，不追问。信息不够再补一句 |
| 社交/平台链接 | Q5 | 直接用，不重复问 |

**核心原则：用户触发时说了什么就用了什么，不问第二遍。只问真正缺的信息。**

---

## Step 1 — 问名字 + 身份（Q1 + Q2）

> **设计原则：全程选择题，30 秒完成。用户只需打一行名字，其余全选。**
>
> **注意：Step 0.5 检测到用户已经给了名字/身份 → 跳过对应问题，不要重复问。**

### Q1. 你的名字？

唯一需要打字的问题。中/英文均可。

### Q2. 你更接近哪种？（7 选 1）

| 选项 | 类型 | 页面结构（按导航顺序） | 覆盖人群 |
|------|------|----------------------|---------|
| A | **写代码 / 做产品** | 首页 → 关于 → 项目 → 博客 → 联系 | 程序员、工程师、产品经理 |
| B | **做设计 / 搞创意** | 首页 → 关于 → 作品集 → 联系 | 设计师、摄影师、策展人、艺术管理 |
| C | **写东西 / 做内容** | 首页 → 关于 → 文章 → 联系 | 记者、编辑、新媒体运营、翻译、出版、编剧 |
| D | **教书 / 做学术** | 首页 → 关于 → 发表 → 教学 → 联系 | 教师、研究员、高校行政、培训师 |
| E | **做专业服务** | 首页 → 关于 → 专业能力 → 联系 | 律师、法务、HR、咨询、社工、心理咨询 |
| F | **创业 / 自己做事** | 首页 → 关于 → 产品 → 联系 | 创始人、自由职业、品牌公关、销售 |
| G | **在校学生** | 首页 → 关于 → 项目 → 简历 → 联系 | 应届、校招、求职、实习 |

### 各页面内容说明

| 页面 | 内容 |
|------|------|
| **首页** | 名字（大字）+ 一句话身份标签 + 简短自我介绍（2-3 句）+ CTA 按钮（指向 Q3 选的核心页面） |
| **关于** | 个人简介段落（AI 根据收集的信息撰写，3-5 句）+ 核心能力标签 + 经历时间线（工作/教育，如有） |
| **项目** | 项目卡片网格（2-3 列响应式），每卡片含：项目名、一句话描述、技术标签（A）/ 类型标签（G）、链接按钮 |
| **博客** | 文章列表，每行：标题 + 日期 + 摘要。无内容则跳过此页 |
| **作品集** | 图片网格或链接卡片，视觉类作品。每个作品含占位图 + 标题 + 链接 |
| **文章** | 文章链接列表，含标题 + 出处 + 一句话摘要。适配 C 类用户（记者/编辑/译者） |
| **发表** | 论文/出版物列表，含标题 + 期刊/出版社 + 年份 + 链接。适配 D 类用户（学术） |
| **教学** | 课程/培训列表，含课程名 + 学校/平台 + 简介。适配 D 类用户 |
| **专业能力** | 案例/资质/服务说明，含能力标签 + 经历要点。适配 E 类用户（律师/咨询/HR） |
| **产品** | 产品卡片，含产品名、一句话理念、核心指标（如有）、链接 |
| **简历** | 教育背景 + 实习/项目经历 + 技能 + 荣誉奖项，紧凑排版 |
| **联系** | 社交链接列表（带 emoji 图标）+ Email + 一句话 CTA |

---

## Step 2 — 追问亮点 + 链接（Q3 + Q5）

> **注意：Step 0.5 检测到用户已经给了亮点/链接 → 跳过对应问题，只问缺的。**

> Q3 是关键——用"选"代替"写"，定位用户最想展示的核心成果。
> Agent 根据 Q2 的答案**动态展示对应选项**，用户只需 4 选 1。

### Q3. 你最想让访客看到什么？（4 选 1，按 Q2 动态变）

**Q2 选了 A（写代码/做产品）：**

> A. 我做的项目 / 产品
> B. 我的技术文章 / 博客
> C. 我的开源贡献
> D. 先搭个框架

**Q2 选了 B（做设计/搞创意）：**

> A. 我的设计作品
> B. 我策划的展览 / 活动
> C. 我的设计理念 / 文章
> D. 先搭个框架

**Q2 选了 C（写东西/做内容）：**

> A. 我的代表文章 / 报道
> B. 我运营的账号 / 栏目
> C. 我的翻译 / 出版作品
> D. 先搭个框架

**Q2 选了 D（教书/做学术）：**

> A. 我的论文 / 研究成果
> B. 我教的课 / 培训项目
> C. 我的学术观点 / 专栏
> D. 先搭个框架

**Q2 选了 E（做专业服务）：**

> A. 我的专业案例 / 能力
> B. 我的行业观点 / 文章
> C. 我的职业经历 / 资质
> D. 先搭个框架

**Q2 选了 F（创业/自己做事）：**

> A. 我的产品
> B. 我的行业观点 / 文章
> C. 我的团队 / 故事
> D. 先搭个框架

**Q2 选了 G（在校学生）：**

> A. 我的项目 / 实习经历
> B. 我的专业 / 研究方向
> C. 我的校园活动 / 社团
> D. 先搭个框架

**Q3 解析**：Agent 根据选择和选项描述自动推断用户的核心产出物类型。例如 C-A（文章/报道）→ Agent 追一句"有几个代表作品链接？"；D-B（课程/培训）→ 追一句"在哪个学校/平台？课程名称？"。**最多追问 1 个回合**，信息够就跳过。

### Q5. 有想放的社交/平台链接吗？（一句话，可跳过）

> 比如 GitHub、公众号、微博、B站、Twitter、LinkedIn、小红书、豆瓣，没有就跳过。

### AI 自动补全

| 用户没提供 | AI 怎么做 |
|-----------|----------|
| 自我介绍文案 | 根据 Q2 身份 + Q3 亮点方向，撰写自然友好的简介 |
| 能力标签 | 从 Q2 类型 + Q3 亮点方向推断，不臆造不相关的技能 |
| 项目/作品描述 | Q3 揭示了用户想展示什么——如果给了名称或链接，推断一句话描述；没给就跳过 |
| 头像 | 不主动要，不占位 |
| 配色 | 从匹配的视觉风格中自动选一套 |

---

## Step 3 — 选择视觉风格

### 动态发现模板

**不要硬编码模板名。** 每次触发时动态扫描 `assets/template-*/meta.json`：

```bash
cat SKILL_DIR/assets/template-*/meta.json | ruby -rjson -e '
  ARGF.each_line do |line|
    next unless line.strip.length > 0
    m = JSON.parse(line)
    puts "#{m["id"]} | #{m["name"]} | #{m["description"]} | 适合: #{m["suitable_for"].join(", ")} | 标签: #{m["style_tags"].join(", ")}"
  end
'
```

**把扫描到的所有模板完整列出给用户选择**（不要只列示例，不要遗漏任何模板）。用户可以直接选，或者说"你帮我定"让 Agent 按身份匹配。

### 匹配规则

**Agent 操作**：
1. 扫描所有模板（上面那条命令）
2. 将扫描结果**完整列出**给用户，每个模板展示：名称、描述、适合身份、风格标签
3. 用户直接选一个，或者说"你帮我定"
4. **用户说"你帮我定"时**：Agent 根据 Q2 身份从扫描结果中选 `suitable_for` 包含用户身份的最匹配模板

**Agent 自动匹配优先级**（仅当用户说"你帮我定"时使用）：

| 用户身份类型 | 优先风格方向 |
|------------|-------------|
| 设计/内容/学术 (B/C/D) | 设计感排版、暖色系 |
| 代码/专业服务/创业/学生 (A/E/F/G) | 极简克制、现代专业 |

- 没有完全匹配的模板 → 选 `suitable_for` 列表里包含用户身份的第一个，或最接近的
- 没有对应种子模板 → 用最接近的模板 + 调整 CSS 变量（如暗色方向：`--bg: #0d1117; --text: #c9d1d9; --accent: #3fb950`）

---

## Step 4 — 生成网站

### 选择种子模板

**动态发现模板，不要硬编码。** 从 Step 3 扫描到的 `meta.json` 列表中选匹配用户身份的模板。

提取所选模板的 `pages` 字段得知可用页面列表，提取 `persona_classes` 字段得知支持的 body class。

**步骤**：

0. **必须先读模板 README.md**：
   ```bash
   cat SKILL_DIR/assets/template-<ID>/README.md
   ```
   里面描述了该模板的图片处理要求（哪些位置要抠图、哪些不需要）、注意事项和特殊约束。填充内容前必须读完。

1. 复制所选模板到独立临时目录：
   ```bash
   SITE_DIR="/tmp/site-$(date +%Y%m%d%H%M%S)"
   cp -r SKILL_DIR/assets/template-<ID> "$SITE_DIR"
   ```
2. 如果偏好的模板内置页面不够，可以从页面更全的模板中补拷需要的 HTML 文件
3. 后续按 Step 4 流程：删不需要的页面 → 清理导航 → 填充内容

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

## Step 4.4 — 字体规约（按身份套字体角色）

> **核心原则：零外部字体依赖**。Google Fonts / Adobe Fonts / 字体厂商 CDN 在国内全部不通，禁止使用。所有字体必须走系统字体栈。
>
> **怎么把系统字体玩出格调？** 通过「字体角色」+ 「身份变体」实现跨身份的差异化。

### 字体源（4 套已预置在 `style.css` 的 `:root`）

| CSS 变量 | 字体类型 | 跨平台落点 |
|---------|---------|-----------|
| `--sans` | 现代无衬线 | macOS: 苹方 · Windows: 雅黑/Segoe · iOS: 苹方 · Android: 思源/Noto |
| `--serif` | 衬线（书籍感） | macOS: 宋体 SC · Windows: Times · 移动端 fallback 思源宋体 |
| `--mono` | 等宽（代码/数据） | macOS: SF Mono · 跨平台 fallback JetBrains Mono / Menlo / Consolas |
| `--display` | 圆体显示字（标题大字） | macOS/iOS: 苹方圆体 · 其他系统 fallback 苹方/雅黑 |

### 字体角色（语义化绑定）

```css
--font-display  → 大标题 / hero 名字
--font-body     → 正文 / 段落
--font-accent   → 强调元素：MRR/版本号/引言/meta/标签
```

- HTML `<h1>/<h2>/<h3>` 已绑 `--font-display`
- `<body>` 已绑 `--font-body`
- 任何元素加 `class="accent-text"` 即套上 `--font-accent`

**Agent 切身份只需做一件事**：在 `<body>` 上加一个 `persona-XXX` class（见下表），style.css 已预置 5 套变体，自动改 3 个角色变量的绑定。

### 身份 → 字体变体对照

| Q2 类型 | body class | display | body | accent | 视觉效果 |
|---------|-----------|---------|------|--------|---------|
| A 写代码/做产品 | `persona-coder` | sans | sans | mono | 简洁清爽，版本号/技术栈用等宽 |
| B 做设计/搞创意 | `persona-designer` | display（圆体） | sans | serif | 标题亲切、引言用衬线增加格调 |
| C 写东西/做内容 | `persona-writer` | serif | serif | sans | 接近书籍阅读，meta 信息用无衬线区隔 |
| D 教书/做学术 | `persona-writer` | serif | serif | sans | 同学术写作习惯，发表列表用衬线显正式 |
| E 做专业服务 | `persona-student` | sans | sans | sans | 紧凑专业，简历感，可信赖 |
| F 创业/自己做事 | `persona-founder` | display（圆体） | sans | mono | 标题亲切、数据指标"一眼看出指标感" |
| G 在校学生 | `persona-student` | sans | sans | sans | 紧凑专业，简历感 |

### Agent 操作步骤

1. 复制模板后，在每个 HTML 文件的 `<body>` 标签上加身份 class：
   ```html
   <body class="persona-writer">
   ```
2. 给应该被强调的内联元素加 `class="accent-text"`：
   ```html
   <p>已运行 <span class="accent-text">847</span> 天 · MRR <span class="accent-text">$12.4K</span></p>
   <p class="meta accent-text">2024-06-05 · 12 min read</p>
   ```
3. **不要** 直接写 `font-family: ...`，所有字体决策走变量。

### 用户主动想换字体怎么办

| 用户说 | 处理 |
|-------|------|
| "标题太硬，柔一点" | 把 `--font-display` 绑到 `var(--display)`（圆体） |
| "想要书籍感" | `<body>` 改 `persona-writer` |
| "数字想要更突出" | 给数字外面套 `<span class="accent-text">`，并确认当前身份的 accent 是 mono |
| "想要更现代" | 默认就是现代无衬线，已经做到位；非要再调可加 `letter-spacing: -0.02em` 让标题更紧 |

### 不允许的操作

- ❌ `<link href="https://fonts.googleapis.com/...">` — 国内打不开
- ❌ `<link href="https://cdn.jsdelivr.net/.../font.css">` — 国内不稳
- ❌ 在 HTML 里写死 `font-family: "PingFang SC"` — 应该走变量

---

## Step 4.5 — 媒体处理规约（图片 / 视频 / 动态背景）

### 图片：放在 `images/` 下，HTML 里引相对路径

#### 流程

1. 站点目录约定（template 已预置）：
   ```
   site/
     index.html
     about.html
     css/style.css
     js/script.js
     images/         ← 用户图片放这里
       avatar.jpg
       project-1.jpg
   ```
2. 拿到用户图片后：
   - 压缩（见下方命令）
   - 复制到 `images/` 下，文件名用语义化的英文 + 小写
   - HTML 里用 **相对路径** 引用：`<img src="images/avatar.jpg" alt="...">`
3. **不要**用 `data:` URL，不要 base64 内联。

#### 单文件 / 总大小限制

| 项 | 限制 |
|----|------|
| 单个文件 | ≤ 5MB |
| 整个 zip 总大小 | ≤ 20MB |
| 图片建议尺寸 | 头像 ≤ 400×400；横图 ≤ 1600px 长边 |
| 图片建议体积 | 单图 ≤ 300KB（首屏可见图最好 ≤ 100KB） |

> **压缩黄金法则：宁大勿糊。** 用户说"糊"是最高优先级投诉——远比"加载慢"严重。
> Hero 区大图 / 用户照片：优先保留原始分辨率，仅当超过 5MB 限制时才压缩。
> 头像：400px 足够。普通配图：1200px 长边。**不要自作主张压小 hero 图。**

超限 `publish.rb` 会直接报错。

### AI 抠图（背景移除）

> **人像照片 / 自拍自动去背景**，基于腾讯云数据万象 AI 人像分割。
> 当用户提供了带背景的人像照片（头像、自拍、Hero 图），**主动询问是否去背景**。

#### 使用场景

| 用户给的图片 | 建议处理 |
|------------|---------|
| 自拍 / 人像照片（有背景） | **问一句"要不要去掉背景？效果更干净"** |
| 已有透明背景的 PNG | 跳过 |
| 纯景物 / 截图 / Logo | 跳过（抠图无意义） |

#### 用户同意后执行

抠图脚本调用 showcode.com API，**复用 publish.rb 的认证**——发布过站点（生成 `~/.oh-my-site/token.json`）或登录账号（`account.json`）后即可直接使用，无需额外配置。

```bash
# Hero 大图抠图 — 保留原始分辨率
ruby "SKILL_DIR/scripts/matting.rb" PHOTO.jpg images/hero.png

# 头像抠图 — 缩小到 400px
ruby "SKILL_DIR/scripts/matting.rb" --resize 400 AVATAR_ORIG.jpg images/avatar.png
```

成功则输出到指定路径（PNG 透明背景），失败返回非 0 退出码。

HTML 里用抠图后的图片：`<img src="images/avatar.png" alt="...">`

#### 注意事项

- 输入图片 ≤ 10MB；抠图结果保留透明背景（PNG）
- 抠图结果默认 **原始分辨率**（不压缩），PNG 体积可能较大（300-500KB），这是正常的
- 如果抠图失败（exit code ≠ 0），**静默回退用原图**，不中断流程
- 用户说"不用去背景 / 保留原图" → 直接跳过

#### 外链域名禁用清单

**禁止**让 `<img src>` 指向以下任一域名（国内访问不稳）：

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

下载完，并检查控制到一定的尺寸。

curl 失败（403/404/超时）→ 告诉用户拿不到图，请换一个或直接给本地文件路径。

**永远不要**把外链 URL 直接粘到 HTML 里。

### 视频：默认不用真视频，用动态背景代替

90% 的"想要视频背景"需求本质是想要「动起来的氛围」。**默认引导用户用 CSS/SVG 动态背景**（见下方），不主动提"视频"选项。

#### 动态背景使用方式

种子模板已预置 5 套动态背景，文件在 `css/animated-bg.css`：

| class | 风格 | 适合身份 |
|-------|------|---------|
| `.bg-gradient-flow` | 渐变流动（柔和大色块游动） | 极简白 / B（设计）/ C（内容）/ F（创业） |
| `.bg-particles` | 粒子飘浮（暗色星点上飘） | 暗黑 / AI 工程师 / 独立开发者 |
| `.bg-grid-scan` | 网格扫光（赛博网格 + 高光线） | A（代码）/ 黑客风 / AI |
| `.bg-geo-float` | 几何漂浮（孟菲斯色块） | B（设计）/ 杂志风 / 年轻品牌 |
| `.bg-noise-stars` | 噪点星空（沉静夜色） | C（内容）/ D（学术） |

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

**核心原则：模板文字颜色决定能用的动态背景**。每个 `.bg-*` 类在 `animated-bg.css` 中标注了 `@bg-mode: light` 或 `@bg-mode: dark`。

**Step 1 — 检查当前选中模板的文字颜色**：读模板 `css/style.css` 的 `:root` 块，看 `--text` 或 `--text-primary` 的值。

**Step 2 — 按模式匹配**：
- 深色文字（`--text` 为 #111~#444 范围、深棕等）→ **只能用 `@bg-mode: light` 的背景**
- 浅色文字（`--text` 为 #ccc~#fff 范围）→ **只能用 `@bg-mode: dark` 的背景**

> ⚠️ **禁止给深色文字模板使用 `@bg-mode: dark` 的背景**（`.bg-noise-stars`、`.bg-particles`、`.bg-grid-scan`）。黑字叠黑底完全不可见。

用户主动说"我要换个粒子背景 / 加点动效 / 太花了去掉" → 先检查当前模板的文字颜色 vs 目标背景的 mode 兼容性，再换 class 或删掉那个 `<div>`。

#### 真要用视频怎么办（罕见场景）

视频文件大，**不要塞进 zip**（容易超 20MB 上限）。让用户自己上传到国内 CDN（阿里云 OSS / 腾讯云 COS / 七牛云），把直链给 Agent。

拿到直链后用 `<video>` 标签：
```html
<video autoplay muted loop playsinline class="bg-video">
  <source src="USER_CDN_URL" type="video/mp4">
</video>
```

`.bg-video` 样式参考动态背景容器：`position: fixed; inset: 0; z-index: -1; object-fit: cover; width: 100%; height: 100%;`。

**绝大多数情况下不要走这条路**，`.bg-particles` 配粒子动画的"科技感"已经够用。

---

## Step 4.6 — 平台内容抓取（B站/小红书/抖音）

> 当用户在 Q5 或后续提供了 B站空间链接、小红书主页、抖音主页时，Agent 应抓取其公开作品内容，填入成果展示/作品集模块。
> 
> **重要：B站/小红书/抖音页面均为 SPA 客户端渲染，普通 HTTP 请求拿不到数据，必须使用浏览器工具。**

### 流程

1. **检测平台链接**：解析用户提供的 URL，识别平台类型：
   ```bash
   ruby SKILL_DIR/scripts/fetch_platform_content.rb --detect "URL"
   ```
   输出 `{"platform":"bilibili","uid":"546195"}` 或 `xiaohongshu` / `douyin`。

2. **浏览器抓取**（三平台通用流程）：
   
   **B站** — 打开 `https://space.bilibili.com/{uid}/video`：
   - 等待页面加载完成（`.video-items` 或 `.small-item` 出现）
   - 在 console 执行以下 JS 收集数据：
   ```js
   JSON.stringify({
     platform: 'bilibili',
     items: Array.from(document.querySelectorAll('.small-item')).slice(0, 6).map(el => ({
       title: el.querySelector('.title')?.textContent?.trim() || '',
       cover_url: (el.querySelector('img')?.src || '').replace(/@\d+w_\d+h(_\d+e)?/, ''),
       url: 'https:' + (el.querySelector('a')?.getAttribute('href') || ''),
       description: el.querySelector('.des')?.textContent?.trim() || '',
       tags: ['B站']
     }))
   })
   ```
   
   **小红书** — 打开 `https://www.xiaohongshu.com/user/profile/{uid}`：
   - 等待笔记卡片加载
   - 在 console 执行 JS 收集封面图和标题
   ```js
   JSON.stringify({
     platform: 'xiaohongshu',
     items: Array.from(document.querySelectorAll('.note-item')).slice(0, 6).map(el => ({
       title: el.querySelector('.title')?.textContent?.trim() || '',
       cover_url: el.querySelector('img')?.src || '',
       url: el.querySelector('a')?.href || '',
       description: '',
       tags: ['小红书']
     }))
   })
   ```
   
   **抖音** — 打开 `https://www.douyin.com/user/{sec_uid}`：
   - 等待视频列表加载
   - 在 console 执行 JS 收集数据
   ```js
   JSON.stringify({
     platform: 'douyin',
     items: Array.from(document.querySelectorAll('[data-e2e="user-post-item"]')).slice(0, 6).map(el => {
       const img = el.querySelector('img');
       return {
         title: img?.alt || '',
         cover_url: img?.src || '',
         url: el.querySelector('a')?.href || '',
         description: '',
         tags: ['抖音']
       };
     })
   })
   ```

3. **保存抓取结果**：把 console 输出的 JSON 保存为临时文件：
   ```bash
   echo 'JSON_DATA' > /tmp/platform-scraped.json
   ```

4. **下载封面图 + 生成卡片数据**：
   ```bash
   ruby SKILL_DIR/scripts/fetch_platform_content.rb \
     --from-json /tmp/platform-scraped.json \
     --out-dir "$SITE_DIR/images"
   ```
   脚本会：
   - 下载所有封面图到 `$SITE_DIR/images/`（命名：`bilibili-cover-001.jpg` 等）
   - 输出完整的 JSON（含本地图片路径），Agent 用此数据生成 HTML 卡片

5. **生成 WORKS_CARDS HTML**：Agent 根据输出的 JSON 拼装 `.work-card` HTML，替换模板中的 `{{WORKS_CARDS}}`。
   
   卡片序号从 01 开始，平台标签用 `PlatformDetector.platform_badge()` 映射（Bilibili / RedBook / Douyin）。
   
   示例卡片 HTML：
   ```html
   <div class="work-card">
       <div class="work-image">
           <img src="images/bilibili-cover-001.jpg" alt="视频封面">
       </div>
       <div class="work-content">
           <div class="work-badge">
               <span class="badge-num">01</span>
               <span class="badge-text">Bilibili</span>
           </div>
           <h3 class="work-title">视频标题</h3>
           <p class="work-desc">视频简介摘要</p>
           <div class="work-tags">
               <span>标签1</span><span>标签2</span><span>标签3</span>
           </div>
       </div>
   </div>
   ```

### 多平台整合

如果用户同时提供了多个平台链接，按平台分开抓取，合并 item 列表后统一编号（01~N），跨平台穿插排列。

### 异常处理

| 情况 | 处理 |
|------|------|
| 浏览器未配置 | 告知用户需先 `browser-setup`，或让用户手动提供作品信息 |
| 页面加载超时/无内容 | 告知用户该平台抓取失败，跳过该平台，用其他平台数据 |
| 封面图下载失败 | 该卡片使用 `work-sample-N.jpg` 占位，不阻塞流程 |
| 用户拒绝浏览器抓取 | 回退到 Q3 追问模式，让用户手动描述作品 |

### 无平台链接时：Agent 自动生成作品卡片

> **当用户没有提供任何平台链接时，Agent 必须根据 Q2 身份类型，随机生成 4 张有差异感的成果展示卡片。**
> 禁止使用模板默认的硬编码占位文案（"现象级品牌公关稿"等），每次生成应看起来不一样。

**生成规则**：

1. **卡片数量**：固定 4 张，填满 2×2 网格
2. **封面图**：使用模板预置的 `work-sample-1.jpg` ~ `work-sample-4.jpg`
3. **编号**：01 ~ 04
4. **分类标签**（`badge-text`）：从以下按 Q2 身份选 4 个不同的：

| Q2 身份 | 可选标签 |
|---------|---------|
| C 写东西/做内容 | Branding / Content / Growth / Social / Media / Editorial / Creative / Strategy |
| A 写代码/做产品 | Product / Engineering / Open Source / Architecture / DevOps / UI / API / Data |
| B 做设计/搞创意 | Visual / UX/UI / Motion / Brand / Illustration / 3D / Print / Exhibition |
| D 教书/做学术 | Research / Teaching / Publication / Lecture / Fieldwork / Theory / Review / Grant |
| E 做专业服务 | Case / Advisory / Compliance / Training / Audit / Legal / HR / Strategy |
| F 创业/自己做事 | Product / Growth / Fundraising / Launch / Pivot / Scale / Team / Revenue |
| G 在校学生 | Project / Internship / Coursework / Competition / Research / Club / Hackathon / Thesis |

5. **标题**：10-20 字中文，看起来像真实项目名/文章标题，每次随机生成不重复。示例方向：
   - C 类：`从0到1搭建品牌内容矩阵`、`单月10W+爆文拆解复盘`、`全域流量漏斗搭建实录`
   - A 类：`高并发微服务架构实践`、`开源 CLI 工具 1K Star 之路`
   - B 类：`新消费品牌 VI 升级全案`、`动态视觉识别系统设计`
   
6. **描述**：30-60 字中文，自然段落，描述项目背景/方法/成果

7. **标签**：每张卡片 3 个标签，从对应身份标签池中随机选，不重复

8. **多样性约束**：4 张卡片的标题、描述、标签必须各不相同，覆盖该身份的不同侧面

**Agent 操作步骤**：

1. 确认用户 Q2 身份类型
2. 随机生成 4 组（标题 + 描述 + 标签），确保多样性
3. 拼装 `.work-card` HTML，替换 `{{WORKS_CARDS}}`：
   ```html
   <div class="work-card">
       <div class="work-image">
           <img src="work-sample-1.jpg" alt="封面">
       </div>
       <div class="work-content">
           <div class="work-badge">
               <span class="badge-num">01</span>
               <span class="badge-text">Branding</span>
           </div>
           <h3 class="work-title">生成的项目标题</h3>
           <p class="work-desc">随机生成的描述文案</p>
           <div class="work-tags">
               <span>标签1</span><span>标签2</span><span>标签3</span>
           </div>
       </div>
   </div>
   ```

### 模板兼容

- `template-apple` 的成果展示模块使用 `{{WORKS_CARDS}}` 变量，Agent 替换整个 `.works-grid` 内容
- 模板默认值（`{{WORKS_CARDS\|...}}`）仅作为**最后保底**，Agent 应始终主动生成或抓取内容
- 其他模板如有作品集/项目模块，Agent 按同样逻辑填充对应区域

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
   ruby "SKILL_DIR/scripts/publish.rb" check-slug --q yafei,yafei-li,yafeilee
   ```

   输出示例：
   ```
   ✅ Available: yafei-li, yafeilee
      Taken: yafei
   ```

3. 将可用候选列出，让用户选一个。提示 URL 预览 `https://showcode.com/~{slug}`：

   ```
   以下访问链接可用，你更喜欢哪一个：
   1. yafei → https://showcode.com/~yafei
   2. yafeilee → https://showcode.com/~yafeilee
   选哪个？（输入序号或自定义）
   ```

4. **如果 3 个候选全被占用**，告知用户并请用户自定义一个 slug，重新 `check-slug` 确认后再发布。

5. 用户确认后，执行发布命令：

```bash
ruby "SKILL_DIR/scripts/publish.rb" publish \
  --name "NAME" \
  --slug "SLUG" \
  --dir "$SITE_DIR"
```

- `--slug` 指定 URL 路径（必传，不可随机）
- `--dir` 指定网站目录路径（包含 `index.html` 及所有子页面、css/、js/、images/）
- 整个目录会被打成 zip 上传（**总大小 ≤ 20MB，单文件 ≤ 5MB**），服务器解压后整盘覆盖到 CDN，旧文件会被清掉
- 子页面通过相对路径访问（`href="about.html"`），CSS/JS 用相对路径（`href="css/style.css"`）
- 首次发布 → 创建新站点，token 保存到 `~/.oh-my-site/token.json`
- 后续运行 → 重新打 zip 整盘覆盖
- 从 stdout 提取 `✅` 开头的 URL 返回给用户

> 仅发布单个 HTML 文件时可用 `--html-file` 替代 `--dir`（内部会自动包成单文件 zip）。

### 编辑现有网站（拉回来改）

如果用户在另一台机器上想继续改，或本地 `~/.oh-my-site/` 下没有源文件了：

```bash
ruby "SKILL_DIR/scripts/publish.rb" fetch --slug "SLUG" --out /path/to/edit
```

会把 CDN 上的整个 site zip 下载下来解压到 `--out` 目录。改完之后正常 `publish --dir` 即可。

### 删除网站

```bash
ruby "SKILL_DIR/scripts/publish.rb" delete
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
   ruby "SKILL_DIR/scripts/publish.rb" register --email USER_EMAIL --password USER_PASSWORD
   ```

3. 注册成功后，**自动把当前本地 site 绑到账户**：

   ```bash
   ruby "SKILL_DIR/scripts/publish.rb" claim
   ```

   `claim` 不带参数时会读取本地 `token.json` 中的 slug + site_token，调 API 把这个 site 的所有权绑给当前登录用户。

### 登录流程（已有账号）

```bash
ruby "SKILL_DIR/scripts/publish.rb" login --email USER_EMAIL --password USER_PASSWORD
```

登录后 session_token 存到 `~/.oh-my-site/account.json`，**所有后续 publish/update 都会优先用 session 鉴权**，自动覆盖账号下所有 site。

### 检查登录状态 / 登出

```bash
ruby "SKILL_DIR/scripts/publish.rb" whoami      # 查看当前登录账号
ruby "SKILL_DIR/scripts/publish.rb" logout      # 登出（清本地 session）
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
| "有缓存/还是旧的/没变" | 给图片 src 加 `?v=N` 参数破缓存（N 递增），然后重新发布 |

---

## 后续路线图

- [x] `assets/template-minimal/` — 极简白种子模板（黑白灰+强调色）
- [x] `assets/template-magazine/` — 杂志风种子模板（衬线大字+暖色+大序号+粗分割线）
- [x] `assets/template-warm-studio/` — 暖意工作室种子模板（暖米色+深咖啡+左文右图hero）
- [x] `assets/template-apple/` — Apple 极简风种子模板（大图Hero+毛玻璃数据栏+拼音水印）
- [x] `assets/template-*/meta.json` — 模板自描述文件，skill 动态发现不再硬编码
- [x] `css/animated-bg.css` — 5 套 CSS/SVG 动态背景（无外部依赖）
- [x] `references/themes-minimal.md` — 极简白配色
- [x] `references/themes-magazine.md` — 杂志风配色
- [ ] `assets/template-dark/` — 暗色极客种子模板（终端美学，深色背景+霓虹强调色）
- [ ] `references/themes-dark.md` — 暗色极客配色
- [ ] 独立开发者特化模板（产品矩阵+MRR/用户数版块）
- [ ] 视频背景方案：仅在用户主动要求时启用，需自带 CDN
