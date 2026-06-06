# 贡献新模板 / 改进现有模板

> 这份文档写给**模板贡献者**（设计师、前端、写过 HTML/CSS 的人都能上手）。
> 最终用户不需要看这个。

---

## 30 秒上手

```bash
git clone <repo>
cd oh-my-website
ruby dev/server.rb
# 浏览器打开 http://localhost:4567/
```

服务器启动后会在页面顶部注入一条工具条：
- **模板**：在所有 `assets/template-*` 之间切换
- **身份**：在 7 套示例数据（coder / designer / writer / academic / pro / founder / student）之间切换
- **设备**：桌面 / 平板 / 手机宽度预览

直接编辑 `assets/template-XXX/` 下的 HTML/CSS，刷新浏览器就能看到改动。

改完满意了，**直接告诉 Agent「保存提交」**，它会帮你建主题分支并 commit/push，避免丢数据。

---

## 占位符语法

模板文件里**不写真名真照片**，全部用占位符。预览服务器会用 fixture 数据填充。

| 写法 | 含义 | 示例 |
|------|------|------|
| `{{KEY}}` | 简单占位，由 fixture 提供值 | `<h1>{{NAME}}</h1>` |
| `{{KEY\|默认值}}` | 带默认值，fixture 没定义时用默认 | `<title>{{NAME\|演示}}</title>` |
| `{{HTML_BLOCK}}` | 整段 HTML 由 fixture 提供 | `<div>{{PORTFOLIO_ITEMS}}</div>` |

**KEY 命名约定**：全大写，下划线分词，类似 `NAME` / `WORK_1_TITLE` / `PROJECT_CARDS`。

**渲染优先级**：`fixture[KEY]` > `_defaults.json[KEY]` > 模板里的默认值 > 显示 `[KEY]` 黄色提示框

---

## 目录结构

```
oh-my-website/
├── assets/
│   ├── template-minimal/    ← 极简白模板（程序员、专业服务、创业、学生）
│   └── template-magazine/   ← 杂志风模板（设计师、写作者、学者）
├── dev/
│   ├── server.rb            ← 预览服务器（你用得最多）
│   ├── fixtures/
│   │   ├── _defaults.json   ← 兜底数据（最完整一份，所有 KEY 都有）
│   │   └── persona-*.json   ← 7 套身份数据，只写"和默认值不同"的字段
│   └── stock/
│       ├── works/*.svg      ← 作品图占位（程序化生成的渐变 SVG）
│       └── avatars/*.svg    ← 头像占位
├── publish.rb               ← 发布到 showcode 的脚本（贡献者一般不动）
├── SKILL.md                 ← 给 AI 看的运行手册（贡献者一般不动）
└── CONTRIBUTING.md          ← 你正在看的这份
```

---

## 工作流

### 改现有模板

1. `ruby dev/server.rb` 启动预览
2. 浏览器工具条切到要改的模板
3. 编辑 `assets/template-XXX/css/style.css` 或 HTML
4. 刷新查看，满意 → 告诉 Agent「保存提交」

### 新增一套模板（比如 `template-dark-geek`）

1. `cp -r assets/template-minimal assets/template-dark-geek` 起一个底
2. **建主题分支**：让 Agent 帮你 `git checkout -b theme/dark-geek`，避免污染 main
3. 改 `css/style.css` 的 `:root` 变量调主题色
4. 调整版式 / 加新页面
5. 全程 `ruby dev/server.rb template-dark-geek` 预览
6. 满意了告诉 Agent「保存提交」
7. PR 时附上 1-2 张截图（可在工具条里截图）

---

## 写新占位符 KEY 的规约

如果你在新模板里加了一个 fixture 还没有的 key（比如 `{{HERO_VIDEO_URL}}`）：

1. **先检查** `dev/fixtures/_defaults.json` 是否有现成的可用 key（如 `BIO`、`TAGLINE`），能复用就复用
2. **加默认值**：`{{HERO_VIDEO_URL|/dev/stock/demo.mp4}}`，这样即使 fixture 没写也能预览
3. **更新** `_defaults.json` 给这个 key 一个所有 persona 通用的默认值
4. **可选**：在 7 个 `persona-*.json` 里覆写差异化的值

> 永远不要让 `{{KEY}}` 不带默认值且 fixture 缺失——发布时 publish.rb 会校验失败拒绝上线。

---

## 硬约束（违反 = PR 被拒）

照搬自 `SKILL.md`「Step 4 硬约束」，列在这里方便速查：

- ❌ 不引用任何 CDN、Google Fonts、外部图片直链
- ❌ 不用 `<link href="https://fonts.googleapis.com/...">`
- ❌ 字体只用 CSS 变量 `--sans` / `--serif` / `--mono` / `--display`，不写死 `font-family`
- ✅ 所有外部链接 `target="_blank" rel="noopener"`
- ✅ 内部导航用 `<a href="page.html">`，当前页加 `class="active"`
- ✅ 移动端优先，必带 `<meta name="viewport">`
- ✅ 每个页面 `<title>` 形如 `{{NAME}} - 页面名`
- ✅ 共享 `css/style.css` + `js/script.js`，零外部依赖
- ✅ 图片由用户在生成阶段内联 base64，模板里只放占位符

---

## 常见问题

**Q: 工具条挡住了我的页面顶部，怎么办？**
A: 服务器自动给 `<body>` 加了 `padding-top: 42px`，理论上不挡。如果你的模板把 padding 写死了，可以临时把工具条隐藏：在 url 后加 `?hide_toolbar=1`（待实现）。

**Q: 我改了 CSS 但浏览器没刷新？**
A: Ctrl/Cmd+Shift+R 强制刷新；或 DevTools 里勾「Disable cache」。

**Q: fixture 数据怎么和 publish.rb 衔接？**
A: 不衔接。fixture **只在本地预览用**。生产环境是 Agent 在独立的临时目录 `$SITE_DIR`（如 `/tmp/site-20260606120000`）阶段把 `{{KEY}}` 替换成用户真实数据，publish.rb 只上传替换后的 HTML。

**Q: 我能加真人头像照片吗？**
A: 可以，但放 `dev/stock/avatars/` 下，且单张控制在 50KB 以内（用 `sips -Z 400`）。仓库不接受单张超过 100KB 的素材。

---

## 给 Agent 的一句话

如果用户在跑 `dev/server.rb` 时说"我改完了 / 满意了 / 保存一下"，按以下步骤执行：

1. 检查当前 git 分支，如果在 `main` 上：
   ```bash
   git checkout -b theme/<合理名字>
   ```
2. `git add -A && git status` 看一下范围合不合理
3. `git commit -m "feat(template-XXX): <一句话描述>"`
4. `git push -u origin <branch>`
5. 给用户回执：分支名、commit hash、远端 URL（如果是 GitHub）

如果用户说"我要建新模板叫 XXX"：先建分支 `theme/XXX`，再 `cp -r assets/template-minimal assets/template-XXX` 起底。
