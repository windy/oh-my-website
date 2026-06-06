#!/usr/bin/env ruby
# frozen_string_literal: true

# oh-my-website — 模板开发预览服务器
#
# 用法：
#   ruby dev/server.rb                       # 列出可用模板，自动启动
#   ruby dev/server.rb template-minimal      # 指定模板
#   ruby dev/server.rb template-magazine --persona=writer
#   ruby dev/server.rb template-minimal --port=4567
#
# 浏览器访问 http://localhost:4567/
# 顶部工具栏可切换 persona / 设备宽度。
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
      # 显式提示这个 key 未定义，方便贡献者发现
      %(<span style="background:#ffe066;color:#333;padding:2px 6px;border-radius:3px;font-family:monospace;font-size:0.85em;border:1px dashed #b8860b;">[#{key}]</span>)
    end
  end
end

# ---------- 注入开发工具条 ----------
def inject_toolbar(html, current_template, current_persona, all_templates, all_personas)
  toolbar = <<~HTML
    <div id="__omw_toolbar" style="position:fixed;top:0;left:0;right:0;z-index:99999;background:#1a1a1a;color:#fff;font:13px/1.4 -apple-system,BlinkMacSystemFont,sans-serif;padding:8px 14px;display:flex;align-items:center;gap:14px;box-shadow:0 2px 8px rgba(0,0,0,.2);">
      <strong style="color:#7df9ff;">🛠 oh-my-website dev</strong>
      <label>模板：
        <select onchange="window.location.search='?template='+this.value+'&persona=#{current_persona}'" style="background:#333;color:#fff;border:1px solid #555;padding:2px 6px;border-radius:3px;">
          #{all_templates.map { |t| %(<option value="#{t}"#{t == current_template ? ' selected' : ''}>#{t}</option>) }.join}
        </select>
      </label>
      <label>身份：
        <select onchange="window.location.search='?template=#{current_template}&persona='+this.value" style="background:#333;color:#fff;border:1px solid #555;padding:2px 6px;border-radius:3px;">
          #{all_personas.map { |p| %(<option value="#{p}"#{p == current_persona ? ' selected' : ''}>#{p}</option>) }.join}
        </select>
      </label>
      <label>设备：
        <select onchange="document.body.style.maxWidth=this.value;document.body.style.margin=this.value==='100%'?'':'40px auto';document.body.style.boxShadow=this.value==='100%'?'':'0 0 24px rgba(0,0,0,.15)';" style="background:#333;color:#fff;border:1px solid #555;padding:2px 6px;border-radius:3px;">
          <option value="100%">桌面</option>
          <option value="768px">平板</option>
          <option value="375px">手机</option>
        </select>
      </label>
      <span style="margin-left:auto;color:#aaa;font-size:11px;">满意了告诉 Agent 「保存提交」</span>
    </div>
    <style>body{padding-top:42px !important;}</style>
  HTML
  if html =~ /<body[^>]*>/
    html.sub(/<body[^>]*>/) { |m| m + toolbar }
  else
    toolbar + html
  end
end

# ---------- HTTP 服务 ----------
server = WEBrick::HTTPServer.new(Port: port, DocumentRoot: TEMPLATE_DIR, AccessLog: [], Logger: WEBrick::Log.new(File::NULL))

server.mount_proc '/__omw_stock' do |req, res|
  # 提供 dev/stock 静态资源
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
  # query 参数可切换模板/persona（不重启）
  q_template = req.query['template']
  q_persona = req.query['persona']

  current_template = q_template && available_templates.include?(q_template) ? q_template : template
  current_persona = q_persona || persona
  current_template_dir = File.join(ASSETS_DIR, current_template)

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
    rendered = inject_toolbar(rendered, current_template, current_persona, available_templates, available_personas)
    res.body = rendered
    res['Content-Type'] = 'text/html; charset=utf-8'
  else
    # 其他静态资源直接读
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

    工具条已注入页面顶部，可在浏览器直接切换模板/身份/设备宽度。
    修改 assets/#{template}/ 下的 HTML/CSS 后，刷新浏览器即可看到。

    ✅  改完满意了，告诉 Agent：「保存提交」
        Agent 会帮你建主题分支并 commit/push，避免丢数据。

    Ctrl+C 退出。

BANNER

server.start
