#!/usr/bin/env ruby
# frozen_string_literal: true

# oh-my-website — 模板开发预览服务器
#
# 用法：
#   ruby dev/server.rb                       # 列出可用模板，自动启动第一个
#   ruby dev/server.rb template-minimal      # 指定模板
#   ruby dev/server.rb --persona=writer      # 指定身份（默认 coder）
#   ruby dev/server.rb --port=4567
#
# 浏览器访问：
#   http://localhost:4567/                          → 默认模板 + 默认身份
#   http://localhost:4567/?persona=designer         → 切换身份
#   http://localhost:4567/?template=minimal&persona=writer  → 切换模板+身份
#   http://localhost:4567/about.html?persona=writer → 子页面也支持
#
# 占位符语法：
#   {{KEY}}            → 优先 fixture，未命中查 _defaults.json，再不命中显示 [KEY]
#   {{KEY|默认值}}      → 默认值就在模板里（fixture 优先级仍最高）

require 'webrick'
require 'json'
require 'erb'

ROOT = File.expand_path('..', __dir__)
ASSETS_DIR = File.join(ROOT, 'assets')
FIXTURES_DIR = File.join(__dir__, 'fixtures')
STOCK_DIR = File.join(__dir__, 'stock')

# ---------- CLI 参数 ----------
template = nil
persona = 'coder'
port = 4567

ARGV.each do |arg|
  case arg
  when /^--persona=(.+)/ then persona = Regexp.last_match(1)
  when /^--port=(\d+)/ then port = Regexp.last_match(1).to_i
  when /^--/ then warn "未知参数: #{arg}"
  else template = arg
  end
end

# ---------- 找模板 ----------
available_templates = Dir.children(ASSETS_DIR).select do |d|
  File.directory?(File.join(ASSETS_DIR, d)) && d.start_with?('template-')
end.sort

if template.nil?
  template = available_templates.first
end

unless available_templates.include?(template)
  warn "❌ 找不到模板 '#{template}'。可用：#{available_templates.join(', ')}"
  exit 1
end

TEMPLATE_DIR = File.join(ASSETS_DIR, template)

# ---------- 加载 fixture ----------
def load_fixture(persona)
  defaults_path = File.join(FIXTURES_DIR, '_defaults.json')
  persona_path = File.join(FIXTURES_DIR, "persona-#{persona}.json")

  defaults = File.exist?(defaults_path) ? JSON.parse(File.read(defaults_path)) : {}
  persona_data = File.exist?(persona_path) ? JSON.parse(File.read(persona_path)) : {}

  # persona 覆盖 defaults
  defaults.merge(persona_data)
end

def available_personas
  Dir.children(FIXTURES_DIR).map do |f|
    f =~ /^persona-(.+)\.json$/ ? Regexp.last_match(1) : nil
  end.compact.sort
rescue Errno::ENOENT
  []
end

# ---------- 占位符替换 ----------
PLACEHOLDER_RE = /\{\{\s*([A-Z][A-Z0-9_]*)\s*(?:\|([^}]*))?\}\}/.freeze

def render(html, fixture)
  html.gsub(PLACEHOLDER_RE) do
    key = Regexp.last_match(1)
    default_val = Regexp.last_match(2)
    if fixture.key?(key)
      fixture[key].to_s
    elsif default_val
      default_val
    else
      %(<span style="background:#ffe066;color:#333;padding:2px 6px;border-radius:3px;font-family:monospace;font-size:0.85em;border:1px dashed #b8860b;">[#{key}]</span>)
    end
  end
end

# ---------- 加载模板 meta（供首页索引用）----------
def load_template_meta(template_dir_name)
  meta_path = File.join(ASSETS_DIR, template_dir_name, 'meta.json')
  if File.exist?(meta_path)
    JSON.parse(File.read(meta_path))
  else
    { 'id' => template_dir_name.sub('template-', ''), 'name' => template_dir_name }
  end
end

# ---------- HTTP 服务 ----------
server = WEBrick::HTTPServer.new(Port: port, DocumentRoot: TEMPLATE_DIR, AccessLog: [], Logger: WEBrick::Log.new(File::NULL))

server.mount_proc '/__omw_stock' do |req, res|
  rel = req.path.sub('/__omw_stock', '')
  path = File.join(STOCK_DIR, rel)
  if File.file?(path)
    res.body = File.binread(path)
    res['Content-Type'] = case File.extname(path).downcase
                          when '.jpg', '.jpeg' then 'image/jpeg'
                          when '.png' then 'image/png'
                          when '.svg' then 'image/svg+xml'
                          when '.webp' then 'image/webp'
                          else 'application/octet-stream'
                          end
  else
    res.status = 404
    res.body = 'not found'
  end
end

server.mount_proc '/' do |req, res|
  q_template = req.query['template']
  q_persona = req.query['persona']

  current_template = q_template && available_templates.include?(q_template) ? q_template : template
  current_persona = q_persona || persona
  current_template_dir = File.join(ASSETS_DIR, current_template)

  # 首页索引：列出所有模板和身份
  if req.path == '/' && !File.exist?(File.join(current_template_dir, 'index.html'))
    metas = available_templates.map { |t| load_template_meta(t) }
    personas = available_personas
    res.body = <<~HTML
      <!DOCTYPE html>
      <html lang="zh-CN">
      <head><meta charset="UTF-8"><title>oh-my-website dev</title>
      <style>body{font:-apple-system,BlinkMacSystemFont,sans-serif;max-width:640px;margin:60px auto;padding:0 20px;background:#fafafa;color:#1a1a1a}
      h1{font-size:24px}h2{font-size:16px;color:#666;margin-top:40px}
      a{display:block;padding:8px 12px;border-radius:6px;margin:4px 0;text-decoration:none;color:#1a1a1a;background:#fff;border:1px solid #e0e0e0}
      a:hover{background:#f0f0f0}.tag{font-size:12px;color:#999;float:right;margin-top:3px}</style></head>
      <body>
      <h1>🎨 oh-my-website dev</h1>
      <p>模板开发预览 — 纯 URL 参数驱动，无工具栏</p>
      <h2>模板（点击用默认身份打开）</h2>
      #{metas.map { |m| %(<a href="/?template=template-#{m['id']}">#{m['name']} <span class="tag">#{m['description'][0..40]}…</span></a>) }.join}
      <h2>身份（用当前默认模板打开）</h2>
      #{personas.map { |p| %(<a href="/?persona=#{p}">#{p}</a>) }.join}
      </body></html>
    HTML
    res['Content-Type'] = 'text/html; charset=utf-8'
    next
  end

  rel_path = req.path == '/' ? '/index.html' : req.path
  file_path = File.join(current_template_dir, rel_path)

  unless File.exist?(file_path) && File.file?(file_path)
    res.status = 404
    res.body = "<h1>404</h1><p>#{rel_path} 不存在于 #{current_template}</p>"
    res['Content-Type'] = 'text/html; charset=utf-8'
    next
  end

  ext = File.extname(file_path).downcase
  if ext == '.html'
    raw = File.read(file_path)
    fixture = load_fixture(current_persona)
    rendered = render(raw, fixture)
    res.body = rendered
    res['Content-Type'] = 'text/html; charset=utf-8'
  else
    res.body = File.binread(file_path)
    res['Content-Type'] = case ext
                          when '.css' then 'text/css; charset=utf-8'
                          when '.js' then 'application/javascript; charset=utf-8'
                          when '.svg' then 'image/svg+xml'
                          when '.png' then 'image/png'
                          when '.jpg', '.jpeg' then 'image/jpeg'
                          when '.webp' then 'image/webp'
                          when '.woff', '.woff2' then 'font/woff2'
                          else 'application/octet-stream'
                          end
  end
end

# ---------- 启动提示 ----------
trap('INT') do
  puts "\n\n💾 关闭预览服务器。"
  puts "   如果你对修改满意，请告诉 Agent 「保存提交」 —— 我会帮你建主题分支并 commit/push。"
  puts "   如果还要继续改，下次重新跑 `ruby dev/server.rb` 即可。\n\n"
  server.shutdown
end

puts <<~BANNER

  ╭────────────────────────────────────────────────────────────╮
  │  🎨  oh-my-website — 模板开发预览                            │
  ╰────────────────────────────────────────────────────────────╯

    模板：  #{template}    （可用：#{available_templates.join(', ')}）
    身份：  #{persona}     （可用：#{available_personas.join(', ')}）
    端口：  http://localhost:#{port}/

    URL 参数切换（无工具栏，纯链接）：
      ?persona=designer        → 切换身份
      ?template=minimal        → 切换模板
      ?template=minimal&persona=writer  → 同时切换

    修改 assets/#{template}/ 下的 HTML/CSS 后，刷新浏览器即可看到。

    ✅  改完满意了，告诉 Agent：「保存提交」
        Agent 会帮你建主题分支并 commit/push，避免丢数据。

    Ctrl+C 退出。

BANNER

server.start
