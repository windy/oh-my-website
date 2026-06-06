#!/usr/bin/env ruby
# publish.rb — Publish or delete a personal website on showcode.com
#
# Usage:
#   ruby publish.rb publish --name "NAME" --dir /path/to/site
#   ruby publish.rb publish --name "NAME" --html-file FILE
#   ruby publish.rb delete  [--slug SLUG]
#   ruby publish.rb check-slug --q s1,s2,s3
#
#   ruby publish.rb register --email E --password P [--name N]
#   ruby publish.rb login    --email E --password P
#   ruby publish.rb logout
#   ruby publish.rb whoami
#   ruby publish.rb claim    [--slug SLUG]    # 把本地 site_token 绑到当前账号
#
# 凭证：
#   ~/clacky_workspace/oh-my-website/token.json    # 当前 site 的 site_token (匿名/兼容)
#   ~/clacky_workspace/oh-my-website/account.json  # 登录后的 session_token
#
# 鉴权优先级：account.session_token > token.json.token
#   - 有 session 时：所有 PUT/POST 都用 session_token，可操作账户名下所有 site
#   - 首次 publish 创建 site 后，若已登录会自动 claim 绑定到账号
#
# Environment:
#   SHOWCODE_API_HOST — platform base URL (default: https://showcode.com)

require "net/http"
require "uri"
require "json"
require "optparse"
require "fileutils"

API_HOST     = ENV.fetch("SHOWCODE_API_HOST", "https://showcode.com")
BASE_DIR     = File.expand_path("~/clacky_workspace/oh-my-website")
TOKEN_FILE   = File.join(BASE_DIR, "token.json")
ACCOUNT_FILE = File.join(BASE_DIR, "account.json")
MAX_SIZE     = 1_048_576 # 1MB

def http_request(method, path, body: nil, token: nil)
  uri  = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.open_timeout = 8
  http.read_timeout = 15

  req_class = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post,
                "PUT" => Net::HTTP::Put, "DELETE" => Net::HTTP::Delete }[method]
  req = req_class.new(uri.request_uri)
  req["Content-Type"]  = "application/json"
  req["Authorization"] = "Bearer #{token}" if token
  req.body = body.to_json if body

  response = http.request(req)
  parsed   = JSON.parse(response.body) rescue { "raw" => response.body }
  [response.code.to_i, parsed]
end

def load_json(path)
  return {} unless File.exist?(path)
  JSON.parse(File.read(path)) rescue {}
end

def save_json(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(data))
  File.chmod(0600, path)
end

def load_token_data    = load_json(TOKEN_FILE)
def save_token_data(d) = save_json(TOKEN_FILE, d)
def load_account       = load_json(ACCOUNT_FILE)
def save_account(d)    = save_json(ACCOUNT_FILE, d)

# 鉴权优先级：登录后的 session_token > 当前 site 的 site_token
def preferred_auth_token(site_token = nil)
  acct = load_account
  return acct["session_token"] if acct["session_token"]
  site_token
end

def logged_in?
  !load_account["session_token"].to_s.empty?
end

def extract_title(html)
  m = html.match(/<title>(.+?)<\/title>/i)
  m ? m[1].strip : nil
end

def validate_size!(content, label)
  return if content.bytesize <= MAX_SIZE
  warn "❌ #{label} exceeds 1MB (#{content.bytesize / 1024}KB)"
  exit 1
end

# 检测目录下所有 HTML 是否还有未填充的 {{KEY}} 占位符。
# 带默认值的 {{KEY|默认值}} 不算未填充（有保底，渲染后也能看）。
# 找到则中止发布并指出哪个文件哪一行（除非 ENV['OMW_FORCE']='1'）。
def validate_no_unfilled_placeholders!(dir)
  unfilled_re = /\{\{\s*[A-Z][A-Z0-9_]*\s*\}\}/
  problems = []
  Dir.glob(File.join(dir, "**/*.html")).each do |f|
    File.read(f, encoding: "utf-8").each_line.with_index(1) do |line, lineno|
      line.scan(unfilled_re) do |m|
        problems << { file: f.sub(dir + "/", ""), line: lineno, key: m }
      end
    end
  end
  return if problems.empty?

  warn "❌ 发现 #{problems.size} 处未填充的占位符，发布已中止："
  problems.first(20).each { |p| warn "   #{p[:file]}:#{p[:line]}  #{p[:key]}" }
  warn "   ..." if problems.size > 20
  warn ""
  warn "   修复方法（任选一种）："
  warn "   1. 让 Agent 重新替换这些 key，再发布"
  warn "   2. 在模板里给占位符加默认值：{{KEY|默认值}}"
  warn "   3. 强制跳过校验（不推荐）：OMW_FORCE=1 ruby publish.rb publish ..."
  exit 1 unless ENV["OMW_FORCE"] == "1"
  warn "⚠️  OMW_FORCE=1 已设置，跳过占位符校验，继续发布。"
end

# Inject <base href="/~slug/"> so relative URLs (css/style.css, js/script.js)
# resolve correctly from any sub-page like /~slug/about
def inject_base_tag(html, slug)
  return html unless slug
  html.sub(/<head>/i, "<head>\n  <base href=\"/~#{slug}/\">")
end

def collect_assets(dir)
  assets = []
  Dir.glob(File.join(dir, "**/*"), File::FNM_DOTMATCH).each do |f|
    next unless File.file?(f)
    next if f.end_with?(".html")
    next if File.basename(f).start_with?(".")
    rel_path = f.sub(dir + "/", "")
    content  = File.read(f, encoding: "utf-8")
    validate_size!(content, rel_path)
    assets << [rel_path, content]
  end
  assets
end

# ── 账户：注册 / 登录 / 登出 / whoami ────────────────────────────────

def cmd_register(email:, password:, name: nil)
  status, body = http_request("POST", "/api/v1/sign_up",
    body: { user: { name: name || email.split("@").first,
                    email: email, password: password,
                    password_confirmation: password } })
  if status == 201 && body["session_token"]
    save_account(
      "session_token" => body["session_token"].to_s,
      "email" => body.dig("user", "email"),
      "user_id" => body.dig("user", "id"),
      "name" => body.dig("user", "name")
    )
    puts "✅ 注册成功：#{body.dig("user", "email")}"
    puts "   session_token 已保存到 #{ACCOUNT_FILE}"
  else
    warn "❌ 注册失败 (#{status}): #{body["error"] || body.inspect}"
    exit 1
  end
end

def cmd_login(email:, password:)
  status, body = http_request("POST", "/api/v1/login",
    body: { email: email, password: password })
  if status == 200 && body["session_token"]
    save_account(
      "session_token" => body["session_token"].to_s,
      "email" => body.dig("user", "email"),
      "user_id" => body.dig("user", "id"),
      "name" => body.dig("user", "name")
    )
    puts "✅ 登录成功：#{body.dig("user", "email")}"
  else
    warn "❌ 登录失败 (#{status}): #{body["error"] || body.inspect}"
    exit 1
  end
end

def cmd_logout
  acct = load_account
  if acct["session_token"]
    http_request("DELETE", "/api/v1/logout", token: acct["session_token"])
  end
  File.delete(ACCOUNT_FILE) if File.exist?(ACCOUNT_FILE)
  puts "✅ 已登出"
end

def cmd_whoami
  acct = load_account
  if acct["session_token"]
    puts "已登录：#{acct["email"]} (id=#{acct["user_id"]})"
  else
    puts "未登录"
    exit 1
  end
end

# 把本地 site_token 对应的 site 绑定到当前账户
def cmd_claim(slug: nil)
  acct = load_account
  unless acct["session_token"]
    warn "❌ 未登录。请先 ruby publish.rb login --email ... --password ..."
    exit 1
  end

  td = load_token_data
  slug  ||= td["slug"]
  site_token = td["token"]

  unless slug && site_token
    warn "❌ 本地没有发布过的 site（#{TOKEN_FILE} 不存在或不完整）"
    exit 1
  end

  status, body = http_request("POST", "/api/v1/sites/#{slug}/claim?token=#{site_token}",
                              token: acct["session_token"])
  if status == 200
    puts "✅ 已认领 site：~#{slug} → #{acct["email"]}"
  elsif status == 409
    puts "ℹ️  该 site 已经被认领过"
  else
    warn "❌ 认领失败 (#{status}): #{body["error"] || body.inspect}"
    exit 1
  end
end

# ── Single-file publish ──────────────────────────────────────────────

def publish_single(name:, html_file:, slug: nil)
  unless File.exist?(html_file)
    warn "❌ HTML file not found: #{html_file}"
    exit 1
  end

  content = File.read(html_file, encoding: "utf-8")
  validate_size!(content, html_file)

  token_data = load_token_data
  saved_slug = token_data["slug"]
  site_token = token_data["token"]
  auth_token = preferred_auth_token(site_token)

  if saved_slug && auth_token
    content = inject_base_tag(content, saved_slug)
    status, body = http_request("PUT", "/api/v1/sites/#{saved_slug}",
                                body: { name: name, content: content },
                                token: auth_token)
    if status == 200
      token_data["version"] = body["version"]
      save_token_data(token_data)
      puts "✅ Website updated: #{body["url"]}"
      puts "   Version: #{body["version"]}"
    else
      warn "❌ Update failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end
  else
    post_body = { name: name, content: content }
    post_body[:slug] = slug if slug
    status, body = http_request("POST", "/api/v1/sites", body: post_body)
    if status == 201
      slug       = body["slug"]
      site_token = body["token"]
      save_token_data("slug" => slug, "token" => site_token, "version" => 1)

      content = inject_base_tag(content, slug)
      auth = preferred_auth_token(site_token)
      http_request("PUT", "/api/v1/sites/#{slug}",
                   body: { name: name, content: content }, token: auth)

      auto_claim_if_logged_in(slug, site_token)

      puts "✅ Website published: #{body["url"]}"
      puts "   Slug: #{slug}"
      puts "   Token saved to: #{TOKEN_FILE}"
    else
      warn "❌ Publish failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end
  end
end

# ── Multi-page (directory) publish ────────────────────────────────────

def publish_dir(name:, dir:, slug: nil)
  unless Dir.exist?(dir)
    warn "❌ Directory not found: #{dir}"
    exit 1
  end

  index_file = File.join(dir, "index.html")
  unless File.exist?(index_file)
    warn "❌ index.html not found in #{dir}"
    exit 1
  end

  # 校验：发布前不能有未替换的 {{KEY}} 占位符（带默认值的 {{KEY|val}} 视为已有保底，允许）
  validate_no_unfilled_placeholders!(dir)

  index_raw = File.read(index_file, encoding: "utf-8")
  validate_size!(index_raw, "index.html")

  sub_pages = Dir.glob(File.join(dir, "*.html"))
    .reject { |f| File.basename(f) == "index.html" }
    .map do |f|
      raw = File.read(f, encoding: "utf-8")
      validate_size!(raw, File.basename(f))
      basename = File.basename(f, ".html")
      title = extract_title(raw) || basename.capitalize
      [basename, title, raw]
    end

  assets = collect_assets(dir)

  token_data = load_token_data
  saved_slug = token_data["slug"]
  site_token = token_data["token"]
  auth_token = preferred_auth_token(site_token)

  if saved_slug && auth_token
    index_content = inject_base_tag(index_raw, saved_slug)
    status, body = http_request("PUT", "/api/v1/sites/#{saved_slug}",
                                body: { name: name, content: index_content },
                                token: auth_token)
    if status == 200
      token_data["version"] = body["version"]
      save_token_data(token_data)
      puts "✅ Main page updated: #{body["url"]}"
    else
      warn "❌ Update failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end

    upload_pages_and_assets(saved_slug, auth_token, sub_pages, assets)
  else
    post_body = { name: name, content: index_raw }
    post_body[:slug] = slug if slug
    status, body = http_request("POST", "/api/v1/sites", body: post_body)
    unless status == 201
      warn "❌ Publish failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end

    slug       = body["slug"]
    site_token = body["token"]
    save_token_data("slug" => slug, "token" => site_token, "version" => 1)
    puts "✅ Website published: #{body["url"]}"
    puts "   Slug: #{slug}"
    puts "   Token saved to: #{TOKEN_FILE}"

    auth = preferred_auth_token(site_token)
    index_content = inject_base_tag(index_raw, slug)
    http_request("PUT", "/api/v1/sites/#{slug}",
                 body: { name: name, content: index_content }, token: auth)

    auto_claim_if_logged_in(slug, site_token)

    upload_pages_and_assets(slug, auth, sub_pages, assets)
  end
end

# 已登录时，新建的 site 自动绑到账号
def auto_claim_if_logged_in(slug, site_token)
  return unless logged_in?
  acct = load_account
  status, body = http_request("POST", "/api/v1/sites/#{slug}/claim?token=#{site_token}",
                              token: acct["session_token"])
  if status == 200
    puts "   🔗 已自动绑定到账户：#{acct["email"]}"
  elsif status != 409  # 409=已认领过，忽略
    warn "   ⚠️  自动绑定失败 (#{status}): #{body["error"] || body.inspect}"
  end
end

def upload_pages_and_assets(slug, token, sub_pages, assets)
  sub_pages.each do |path, title, content|
    injected = inject_base_tag(content, slug)
    status, body = http_request("POST", "/api/v1/sites/#{slug}/pages",
                                body: { path: path, title: title, content: injected },
                                token: token)
    if status == 200
      puts "   📄 #{path} → #{body["url"]}"
    else
      warn "   ⚠️  #{path} failed (#{status}): #{body["error"] || body.inspect}"
    end
  end

  assets.each do |rel_path, content|
    status, body = http_request("POST", "/api/v1/sites/#{slug}/pages",
                                body: { path: rel_path, title: rel_path, content: content },
                                token: token)
    if status == 200
      puts "   🎨 #{rel_path} uploaded"
    else
      warn "   ⚠️  #{rel_path} failed (#{status}): #{body["error"] || body.inspect}"
    end
  end
end

# ── Check Slug ────────────────────────────────────────────────────────

def cmd_check_slug(query)
  slugs = query.to_s.split(",").map(&:strip).reject(&:empty?)
  if slugs.empty?
    warn "Usage: ruby publish.rb check-slug --q slug1,slug2,slug3"
    exit 1
  end

  status, body = http_request("GET", "/api/v1/sites/check_slug?q=#{slugs.join(",")}")
  if status == 200
    available = body["available"] || []
    taken     = body["taken"] || []

    if available.empty?
      puts "❌ All slugs taken. Try different candidates."
    else
      puts "✅ Available: #{available.join(", ")}"
    end
    unless taken.empty?
      puts "   Taken: #{taken.join(", ")}"
    end
    exit available.empty? ? 1 : 0
  else
    warn "❌ Check failed (#{status}): #{body["error"] || body.inspect}"
    exit 1
  end
end

# ── Delete ────────────────────────────────────────────────────────────

def cmd_delete(slug: nil)
  token_data = load_token_data
  token = token_data["token"]
  slug  = slug || token_data["slug"]

  unless token && slug
    warn "❌ No published website found (#{TOKEN_FILE} missing or incomplete)."
    warn "   Nothing to delete."
    exit 1
  end

  warn "⚠️  Delete not yet available via API. Remove manually or via dashboard."
  warn "   Slug: #{slug}"
  exit 0
end

# ── CLI ───────────────────────────────────────────────────────────────

command = ARGV.shift

case command
when "publish"
  options = {}
  OptionParser.new do |opts|
    opts.on("--name NAME")          { |v| options[:name]      = v }
    opts.on("--slug SLUG")          { |v| options[:slug]      = v }
    opts.on("--html-file FILE")     { |v| options[:html_file] = v }
    opts.on("--dir DIR")            { |v| options[:dir]       = v }
  end.parse!

  unless options[:name]
    warn "Usage: ruby publish.rb publish --name NAME [--html-file FILE | --dir DIR]"
    exit 1
  end

  if options[:dir]
    publish_dir(name: options[:name], dir: File.expand_path(options[:dir]), slug: options[:slug])
  elsif options[:html_file]
    publish_single(name: options[:name], html_file: File.expand_path(options[:html_file]), slug: options[:slug])
  else
    warn "❌ Must specify --html-file or --dir"
    exit 1
  end

when "delete"
  options = {}
  OptionParser.new do |opts|
    opts.on("--slug SLUG") { |v| options[:slug] = v }
  end.parse!
  cmd_delete(slug: options[:slug])

when "check-slug"
  options = {}
  OptionParser.new do |opts|
    opts.on("--q QUERY") { |v| options[:q] = v }
    opts.on("-q QUERY")  { |v| options[:q] = v }
  end.parse!
  cmd_check_slug(options[:q])

when "register"
  options = {}
  OptionParser.new do |opts|
    opts.on("--email E")    { |v| options[:email]    = v }
    opts.on("--password P") { |v| options[:password] = v }
    opts.on("--name N")     { |v| options[:name]     = v }
  end.parse!
  unless options[:email] && options[:password]
    warn "Usage: ruby publish.rb register --email EMAIL --password PASSWORD [--name NAME]"
    exit 1
  end
  cmd_register(email: options[:email], password: options[:password], name: options[:name])

when "login"
  options = {}
  OptionParser.new do |opts|
    opts.on("--email E")    { |v| options[:email]    = v }
    opts.on("--password P") { |v| options[:password] = v }
  end.parse!
  unless options[:email] && options[:password]
    warn "Usage: ruby publish.rb login --email EMAIL --password PASSWORD"
    exit 1
  end
  cmd_login(email: options[:email], password: options[:password])

when "logout"
  cmd_logout

when "whoami"
  cmd_whoami

when "claim"
  options = {}
  OptionParser.new do |opts|
    opts.on("--slug SLUG") { |v| options[:slug] = v }
  end.parse!
  cmd_claim(slug: options[:slug])

else
  warn "Usage: ruby publish.rb COMMAND [options]"
  warn "  publish     --name NAME [--html-file FILE | --dir DIR] [--slug SLUG]"
  warn "  delete      [--slug SLUG]"
  warn "  check-slug  --q slug1,slug2,slug3"
  warn ""
  warn "  register    --email E --password P [--name N]"
  warn "  login       --email E --password P"
  warn "  logout"
  warn "  whoami"
  warn "  claim       [--slug SLUG]    # 把本地 site 绑到当前账号"
  exit 1
end
