# 杂志风 (Magazine)

衬线大字标题、不对称排版、暖米白底色 + 一抹强调色。设计感强，适合展示作品。

## 适用身份
`designer` `writer` `academic`

## 页面（4 页）
index, about, portfolio, contact

## 图片处理
- **portfolio 作品图**：`portfolio.html` 中每件作品有 `.work-image` 容器，默认用 `<div class="placeholder">` 占位。用户提供图片时换成 `<img>` 标签，图片类型为设计作品展示图（海报、品牌物料等），一般不需要抠图
- **首页/关于**：无图片位
- 如果用户提供了个人照片想在首页展示，magazine 的 hero 区域可以加一张大图（放在 `<h1>` 上方），需要抠图时用 `scripts/matting.rb`

## 注意事项
- 首页有可选动态背景 `<div class="bg-geo-float">`，不需要可删
- `<body>` 需要设置 persona class：`persona-designer` 或 `persona-writer`
- 页面少（仅 4 页），如果用户身份需要的页面模板没有（如 projects/blog），从 minimal 或 warm-studio 补拷
