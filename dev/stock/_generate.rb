#!/usr/bin/env ruby
# 生成几张 SVG 作品图占位，用于 dev 预览
# 比 picsum 真实——带项目标题、明确比例、克制配色

require 'fileutils'

OUT_DIR = File.expand_path('works', __dir__)
FileUtils.mkdir_p(OUT_DIR)

# 6 套配色，对应不同作品类型
PALETTES = [
  { bg1: '#667eea', bg2: '#764ba2', fg: '#fff', label: 'DevFlow', sub: '开发者工具' },
  { bg1: '#f6d365', bg2: '#fda085', fg: '#3d2c1e', label: '拾光咖啡', sub: '品牌系统 · 2025' },
  { bg1: '#84fab0', bg2: '#8fd3f4', fg: '#0b3d2e', label: 'Slate Reader', sub: '阅读应用' },
  { bg1: '#a18cd1', bg2: '#fbc2eb', fg: '#2d1b4e', label: '南风音乐节', sub: '主视觉 · 2024' },
  { bg1: '#1e3c72', bg2: '#2a5298', fg: '#fff', label: 'Pico CMS', sub: '开源 · 2.3K Star' },
  { bg1: '#232526', bg2: '#414345', fg: '#f1c40f', label: '无界书店', sub: 'VI · 2023' }
]

PALETTES.each_with_index do |p, i|
  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 400">
      <defs>
        <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#{p[:bg1]}"/>
          <stop offset="100%" stop-color="#{p[:bg2]}"/>
        </linearGradient>
      </defs>
      <rect width="600" height="400" fill="url(#g)"/>
      <text x="40" y="340" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="48" font-weight="700" fill="#{p[:fg]}">#{p[:label]}</text>
      <text x="40" y="372" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="18" font-weight="400" fill="#{p[:fg]}" opacity="0.7">#{p[:sub]}</text>
      <circle cx="540" cy="60" r="8" fill="#{p[:fg]}" opacity="0.5"/>
    </svg>
  SVG

  path = File.join(OUT_DIR, "work-#{format('%02d', i + 1)}.svg")
  File.write(path, svg)
  puts "wrote #{path}"
end

# 头像：6 张几何头像
AVATAR_DIR = File.expand_path('avatars', __dir__)
FileUtils.mkdir_p(AVATAR_DIR)

AVATAR_COLORS = [
  ['#FF6B6B', '#4ECDC4'],
  ['#A8E6CF', '#FFD3B6'],
  ['#FFE066', '#F25F5C'],
  ['#247BA0', '#70C1B3'],
  ['#B388EB', '#8093F1'],
  ['#3D348B', '#F18701']
]

AVATAR_COLORS.each_with_index do |(c1, c2), i|
  initial = ['张', '李', '王', '陈', '苏', '林'][i]
  svg = <<~SVG
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200">
      <defs>
        <linearGradient id="g#{i}" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#{c1}"/>
          <stop offset="100%" stop-color="#{c2}"/>
        </linearGradient>
      </defs>
      <rect width="200" height="200" fill="url(#g#{i})"/>
      <text x="100" y="135" font-family="-apple-system,BlinkMacSystemFont,sans-serif" font-size="100" font-weight="600" fill="#fff" text-anchor="middle" opacity="0.92">#{initial}</text>
    </svg>
  SVG

  path = File.join(AVATAR_DIR, "avatar-#{format('%02d', i + 1)}.svg")
  File.write(path, svg)
  puts "wrote #{path}"
end
