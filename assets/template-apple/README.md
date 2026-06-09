# Apple 极简风 (Apple)

大图 Hero + 毛玻璃数据栏 + 极简米白底，Apple Keynote 式克制美学。拼音水印背书增加视觉层次。

## 适用身份
`coder` `professional` `founder` `writer` `designer`

## 页面（8 页）
index, about, projects, blog, portfolio, product, resume, contact

## 图片处理
- **Hero 人像图**：`index.html` 中 `.hero-image` 容器使用 `<img src="hero-sample.png">` 占位。用户提供人像照片时替换路径，如需抠图用 `scripts/matting.rb`
- **作品展示图**：`index.html` 中 `{{WORKS_CARDS}}` 区域每张卡片含 `.work-image`，默认用 `work-sample-N.jpg` 占位。用户提供平台链接时 Agent 抓取替换；无链接时 Agent 自动生成 4 张卡片
- 其他页面无图片位

## 注意事项
- Hero 区的大拼音水印 `{{NAME_PINYIN|ZHANG SAN}}` 需 Agent 填充用户名字的拼音
- Hero 底部毛玻璃数据栏（`.hero-stats`）默认展示 3 项数据标签，Agent 根据 Q3 方向调整
- `{{WORKS_CARDS}}` 变量控制整个 `.works-grid` 内容，Agent 必须替换掉默认占位
- `<body>` 需要设置 persona class，支持 `persona-coder/writer/designer/founder/student`
- 动态背景可选 `.bg-gradient-flow`（浅色底兼容），不需要可删
