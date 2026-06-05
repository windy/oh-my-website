# Magazine 主题配色变体

杂志风模板（`assets/template-magazine/`）配套的 3 套配色。
**用法**：替换 `css/style.css` 中 `:root` 块的颜色变量。

---

## 1. 暖米白 + 红（默认 · 杂志封面感）

最经典的杂志审美：暖底色 + 一抹红做强调。Pentagram、纽约客都是这个套路。

```css
:root {
  --bg: #faf7f2;
  --bg-paper: #ffffff;
  --text: #1a1a1a;
  --text-secondary: #6b6b6b;
  --text-muted: #a0a0a0;
  --border: #e8e3da;
  --border-strong: #1a1a1a;
  --accent: #d63031;
  --accent-hover: #b02525;
  --tag-bg: #f0ebdf;
  --tag-text: #555;
}
```

**适合**：品牌设计师、平面设计师、艺术总监、独立创作人。

---

## 2. 冷灰 + 钴蓝（艺术馆感）

冷调克制，更高冷的画廊审美。适合走严肃路线的设计师。

```css
:root {
  --bg: #f5f5f7;
  --bg-paper: #ffffff;
  --text: #0a0a0c;
  --text-secondary: #595961;
  --text-muted: #9a9aa3;
  --border: #dededf;
  --border-strong: #0a0a0c;
  --accent: #2740c8;
  --accent-hover: #1d31a0;
  --tag-bg: #ececef;
  --tag-text: #4a4a52;
}
```

**适合**：UX 设计师、产品设计师、建筑/工业设计师、严肃创作向。

---

## 3. 奶油 + 墨绿（复古文艺）

更柔和、复古的色温。适合插画师、手作、文创品牌、童书设计师。

```css
:root {
  --bg: #f4ede0;
  --bg-paper: #fdf8ec;
  --text: #2d2820;
  --text-secondary: #6b5e4a;
  --text-muted: #a89a82;
  --border: #e0d5be;
  --border-strong: #2d2820;
  --accent: #2d5a3d;
  --accent-hover: #1f4a2d;
  --tag-bg: #ebe2cd;
  --tag-text: #5a4a32;
}
```

**适合**：插画师、童书/绘本作者、手工/陶艺、自然/环保品牌、复古风内容创作者。

---

## 切换建议

- **匹配身份不只是颜色**：奶油+墨绿配复古插画师效果最好；冷灰+蓝配产品/UX 设计师；暖米白+红是最通用的。
- **可微调**：用户说"这个红太亮" → 把 `--accent` 改深一点（比如 `#a8252a`）。
- **暗色模式**：暂未提供。如有需要可在 `:root` 后追加 `@media (prefers-color-scheme: dark) { :root { ... } }`，但杂志风通常更适合白底。

## 字体角色（已在 style.css 写死，一般不改）

```
--font-display: var(--serif)    标题用衬线
--font-body:    var(--sans)     正文无衬线
--font-accent:  var(--mono)     meta/序号等宽
```

如果用户想要全衬线（更书卷气）：
```css
--font-body: var(--serif);
```
但记得在长段落上设 `line-height: 1.85`。
