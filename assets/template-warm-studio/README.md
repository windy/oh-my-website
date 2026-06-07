# 暖意工作室 (Warm Studio)

暖米色+深咖啡、大粗标题、左文右图 hero。柔和温暖，适合自由职业/设计/内容创作者。

## 适用身份
`designer` `writer` `founder`

## 页面（8 页）
index, about, projects, blog, portfolio, product, resume, contact

## 图片处理

### 首页英雄区 — 个人照片（适合抠图）
- 位置：`index.html` 的 `{{HERO_IMAGE}}` → `.hero-portrait`
- 如果用户提供了人物照片（尤其是带背景的生活照/半身照），建议抠图去背景
- 调用：`ruby SKILL_DIR/scripts/matting.rb <用户照片> <输出路径>`
- 抠图后替换 `{{HERO_IMAGE}}` 占位符

### 项目封面（通常不需要抠图）
- 6 个项目卡片，占位符 `{{PROJECT_N_IMAGE|stock/works/work-N.svg}}`
- 默认用 SVG 占位图，用户提供作品截图/照片时替换
- 如果是设计作品/截图，一般直接使用，不需要抠图

### 客户头像（不需要抠图）
- 3 个评价卡片的头像 `{{TESTIMONIAL_N_AVATAR|/__omw_stock/avatars-warm/avatar-N.svg}}`
- 默认用 SVG 几何头像，用户提供真实客户头像时替换
- 头像通常是方形裁剪，不需要抠图

### 服务区
- 纯文字卡片，无图片

## 注意事项
- `<body>` 需要设置 persona class：`persona-designer`、`persona-writer` 或 `persona-founder`
- 首页使用 `.home-page` 布局（左文右图 hero）
- 项目区 3×2 网格，如果没有 6 个项目，删掉多余的 `<a class="project-card">`
- 评价区默认 3 条，不够可删多余的 `article.testimonial-card`
