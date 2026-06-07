#!/usr/bin/env ruby
# publish.rb — Publish or fetch a personal website on showcode.com
#
# Usage:
#   ruby publish.rb publish --name "NAME" --dir /path/to/site
#   ruby publish.rb publish --name "NAME" --html-file FILE
#   ruby publish.rb fetch   [--slug SLUG] [--out DIR]   # 下载 zip 解压到目录（用于编辑现有 site）
#   ruby publish.rb delete  [--slug SLUG]
#   ruby publish.rb check-slug --q s1,s2,s3
#
#   ruby publish.rb register --email E --password P [--name N]
#   ruby publish.rb login    --email E --password P
#   ruby publish.rb logout
#   ruby publish.rb whoami
#   ruby publish.rb claim    [--slug SLUG]
#
# 凭证：
#   ~/clacky_workspace/oh-my-website/token.json    # 当前 site 的 site_token
#   ~/clacky_workspace/oh-my-website/account.json  # 登录后的 session_token
#
# Environment:
#   SHOWCODE_API_HOST — platform base URL (default: https://showcode.com)
#
# 发布模型（zip-bundle）：
#   1. 把 --dir 整个目录打成 .zip（含子目录 css/js/images 等所有静态资源）
#   2. 上传到 POST /api/v1/sites/:slug/bundle (multipart)
#   3. 服务器解压并整盘覆盖 sites/<slug>/* 到对象存储
#   4. 单 zip 上限 20MB，单文件 5MB
#
# 注意：路径相对引用（href="about.html" / src="css/style.css"）会在 OpenResty
# 反代下自然工作；不再注入 <base href>，也不再 base64 内联媒体。

require "net/http"
require "uri"
require "json"
require "optparse"
require "fileutils"
require "tmpdir"
require "zip" # bundled with most Ruby installs via rubygems; if missing: `gem install rubyzip`

API_HOST     = ENV.fetch("SHOWCODE_API_HOST", "https://showcode.com")
BASE_DIR     = File.expand_path("~/clacky_workspace/oh-my-website")
TOKEN_FILE   = File.join(BASE_DIR, "token.json")
ACCOUNT_FILE = File.join(BASE_DIR, "account.json")

MAX_ZIP_SIZE  = 20 * 1024 * 1024  # 20MB
MAX_FILE_SIZE = 5  * 1024 * 1024  # 5MB

# ── HTTP ─────────────────────────────────────────────────────────────

def http_request(method, path, body: nil, token: nil)
  uri  = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.open_timeout = 8
  http.read_timeout = 60

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

# multipart upload (single 'file' field). 用 Net::HTTP::Post#set_form 处理边界/编码。
def http_upload_zip(path, zip_path, token:)
  uri  = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.open_timeout = 8
  http.read_timeout = 120

  req = Net::HTTP::Post.new(uri.request_uri)
  req["Authorization"] = "Bearer #{token}" if token
  File.open(zip_path, "rb") do |io|
    req.set_form([
      ["file", io, { filename: File.basename(zip_path), content_type: "application/zip" }]
    ], "multipart/form-data")
    resp = http.request(req)
    parsed = JSON.parse(resp.body) rescue { "raw" => resp.body }
    return [resp.code.to_i, parsed]
  end
end

def http_download(path, dest_path, token:)
  uri  = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.open_timeout = 8
  http.read_timeout = 120

  req = Net::HTTP::Get.new(uri.request_uri)
  req["Authorization"] = "Bearer #{token}" if token

  http.request(req) do |resp|
    if resp.code.to_i != 200
      body = resp.body || ""
      parsed = JSON.parse(body) rescue { "raw" => body }
      return [resp.code.to_i, parsed]
    end
    File.open(dest_path, "wb") do |f|
      resp.read_body { |chunk| f.write(chunk) }
    end
    return [200, { "ok" => true, "size" => File.size(dest_path) }]
  end
end

# ── JSON storage ─────────────────────────────────────────────────────

def load_json(path); File.exist?(path) ? (JSON.parse(File.read(path)) rescue {}) : {}; end
def save_json(path, data)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(data))
  File.chmod(0600, path)
end
def load_token_data;       load_json(TOKEN_FILE);             end
def save_token_data(d);    save_json(TOKEN_FILE, d);          end
def load_account;          load_json(ACCOUNT_FILE);           end
def save_account(d);       save_json(ACCOUNT_FILE, d);        end

def preferred_auth_token(site_token = nil)
  acct = load_account
  return acct["session_token"] if acct["session_token"]
  site_token
end

def logged_in?
  !load_account["session_token"].to_s.empty?
end

# ── Validation ───────────────────────────────────────────────────────

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
  warn "   修复方法：让 Agent 重新替换这些 key，或用 OMW_FORCE=1 跳过"
  exit 1 unless ENV["OMW_FORCE"] == "1"
  warn "⚠️  OMW_FORCE=1 已设置，跳过占位符校验。"
end

def validate_dir_size!(dir)
  total = 0
  problems = []
  Dir.glob(File.join(dir, "**/*"), File::FNM_DOTMATCH).each do |f|
    next unless File.file?(f)
    next if File.basename(f).start_with?(".")
    sz = File.size(f)
    total += sz
    if sz > MAX_FILE_SIZE
      problems << "#{f.sub(dir + "/", "")} (#{sz / 1024}KB)"
    end
  end
  if total > MAX_ZIP_SIZE
    warn "❌ 目录总大小 #{total / 1024 / 1024}MB 超过 20MB 上限"
    exit 1
  end
  unless problems.empty?
    warn "❌ 以下文件超过单文件 5MB 上限："
    problems.each { |p| warn "   #{p}" }
    exit 1
  end
end

# ── Zip helpers ──────────────────────────────────────────────────────

# 把目录打成 zip。跳过 `.` 开头隐藏文件、空目录、.DS_Store 之类。
def build_zip(dir, zip_path)
  Zip::File.open(zip_path, create: true) do |zip|
    Dir.glob(File.join(dir, "**/*"), File::FNM_DOTMATCH).each do |f|
      next unless File.file?(f)
      base = File.basename(f)
      next if base.start_with?(".")
      next if base.casecmp("Thumbs.db").zero?
      rel = f.sub(dir + "/", "")
      zip.add(rel, f)
    end
  end
end

# ── Account commands ────────────────────────────────────────────────

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
  http_request("DELETE", "/api/v1/logout", token: acct["session_token"]) if acct["session_token"]
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
    warn "❌ 本地没有发布过的 site"
    exit 1
  end
  status, body = http_request("POST", "/api/v1/sites/#{slug}/claim?token=#{site_token}",
                              token: acct["session_token"])
  case status
  when 200 then puts "✅ 已认领 site：~#{slug} → #{acct["email"]}"
  when 409 then puts "ℹ️  该 site 已经被认领过"
  else
    warn "❌ 认领失败 (#{status}): #{body["error"] || body.inspect}"
    exit 1
  end
end

def auto_claim_if_logged_in(slug, site_token)
  return unless logged_in?
  acct = load_account
  status, body = http_request("POST", "/api/v1/sites/#{slug}/claim?token=#{site_token}",
                              token: acct["session_token"])
  if status == 200
    puts "   🔗 已自动绑定到账户：#{acct["email"]}"
  elsif status != 409
    warn "   ⚠️  自动绑定失败 (#{status}): #{body["error"] || body.inspect}"
  end
end

# ── Publish ──────────────────────────────────────────────────────────

def publish_dir(name:, dir:, slug: nil)
  unless Dir.exist?(dir)
    warn "❌ Directory not found: #{dir}"
    exit 1
  end
  unless File.exist?(File.join(dir, "index.html"))
    warn "❌ index.html not found in #{dir}"
    exit 1
  end

  validate_no_unfilled_placeholders!(dir)
  validate_dir_size!(dir)

  # 1. 确保 site 存在（首发布则 create）
  td = load_token_data
  saved_slug = td["slug"]
  site_token = td["token"]
  auth       = preferred_auth_token(site_token)

  if saved_slug && auth
    # 已经发布过：用 saved_slug，更新元信息
    slug_in_use = saved_slug
    http_request("PUT", "/api/v1/sites/#{slug_in_use}", body: { name: name }, token: auth)
  else
    # 首次发布：创建 site
    post_body = { name: name }
    post_body[:slug] = slug if slug
    status, body = http_request("POST", "/api/v1/sites", body: post_body)
    unless status == 201
      warn "❌ 创建站点失败 (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end
    slug_in_use = body["slug"]
    site_token  = body["token"]
    save_token_data("slug" => slug_in_use, "token" => site_token, "version" => 1)
    auth = preferred_auth_token(site_token)
    puts "✅ 站点已创建：#{body["url"]}  slug=#{slug_in_use}"
    auto_claim_if_logged_in(slug_in_use, site_token)
  end

  # 2. 打 zip
  Dir.mktmpdir("omw-bundle-") do |tmp|
    zip_path = File.join(tmp, "bundle.zip")
    build_zip(dir, zip_path)
    zip_size = File.size(zip_path)
    if zip_size > MAX_ZIP_SIZE
      warn "❌ Bundle zip #{zip_size / 1024 / 1024}MB 超过 20MB 上限"
      exit 1
    end
    puts "📦 Bundle: #{zip_size / 1024}KB → 上传中…"

    status, body = http_upload_zip("/api/v1/sites/#{slug_in_use}/bundle", zip_path, token: auth)
    if status == 200
      td = load_token_data
      td["slug"]    = slug_in_use
      td["version"] = body["version"] if body["version"]
      save_token_data(td)
      puts "✅ Published: #{body["url"]}"
      puts "   Files uploaded: #{body["uploaded"]}"
      puts "   Version: #{body["version"]}"
    else
      warn "❌ Bundle 上传失败 (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end
  end
end

def publish_single(name:, html_file:, slug: nil)
  unless File.exist?(html_file)
    warn "❌ HTML file not found: #{html_file}"
    exit 1
  end
  Dir.mktmpdir("omw-single-") do |tmp|
    FileUtils.cp(html_file, File.join(tmp, "index.html"))
    publish_dir(name: name, dir: tmp, slug: slug)
  end
end

# ── Fetch (download zip and extract) ────────────────────────────────

def cmd_fetch(slug: nil, out_dir: nil)
  td = load_token_data
  slug ||= td["slug"]
  site_token = td["token"]
  auth = preferred_auth_token(site_token)
  unless slug && auth
    warn "❌ 没有可用的 slug 或 token"
    exit 1
  end

  out_dir ||= File.join(BASE_DIR, "edit-#{slug}")
  FileUtils.mkdir_p(out_dir)

  Dir.mktmpdir("omw-fetch-") do |tmp|
    zip_path = File.join(tmp, "site.zip")
    status, body = http_download("/api/v1/sites/#{slug}/bundle", zip_path, token: auth)
    if status != 200
      warn "❌ 下载失败 (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end

    Zip::File.open(zip_path) do |zip|
      zip.each do |entry|
        next if entry.directory?
        # zip-slip 防护
        rel = entry.name
        if rel.start_with?("/") || rel.split("/").any? { |p| p == ".." }
          warn "⚠️  跳过不安全路径：#{rel}"
          next
        end
        dest = File.join(out_dir, rel)
        FileUtils.mkdir_p(File.dirname(dest))
        File.delete(dest) if File.exist?(dest)
        # 用 IO 写入更稳（rubyzip 2.x/3.x extract 签名不同）
        File.binwrite(dest, entry.get_input_stream.read)
      end
    end

    puts "✅ 已下载并解压：#{out_dir}"
    puts "   slug = #{slug}"
    puts "   现在可以直接编辑该目录，然后："
    puts "   ruby publish.rb publish --name \"...\" --dir #{out_dir}"
  end
end

# ── Check Slug ───────────────────────────────────────────────────────

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
      puts "❌ All slugs taken."
    else
      puts "✅ Available: #{available.join(", ")}"
    end
    puts "   Taken: #{taken.join(", ")}" unless taken.empty?
    exit available.empty? ? 1 : 0
  else
    warn "❌ Check failed (#{status}): #{body["error"] || body.inspect}"
    exit 1
  end
end

# ── Delete ───────────────────────────────────────────────────────────

def cmd_delete(slug: nil)
  td = load_token_data
  slug ||= td["slug"]
  unless slug
    warn "❌ 没有可用的 slug"
    exit 1
  end
  warn "⚠️  Delete API 尚未实现，请通过 dashboard 删除。slug=#{slug}"
  exit 0
end

# ── CLI ──────────────────────────────────────────────────────────────

command = ARGV.shift

case command
when "publish"
  options = {}
  OptionParser.new do |opts|
    opts.on("--name NAME")      { |v| options[:name]      = v }
    opts.on("--slug SLUG")      { |v| options[:slug]      = v }
    opts.on("--html-file FILE") { |v| options[:html_file] = v }
    opts.on("--dir DIR")        { |v| options[:dir]       = v }
  end.parse!
  if options[:dir]
    options[:name] ||= File.basename(File.expand_path(options[:dir]))
    publish_dir(name: options[:name], dir: File.expand_path(options[:dir]), slug: options[:slug])
  elsif options[:html_file]
    options[:name] ||= File.basename(options[:html_file], ".*")
    publish_single(name: options[:name], html_file: File.expand_path(options[:html_file]), slug: options[:slug])
  else
    warn "Usage: ruby publish.rb publish [--name NAME] [--slug SLUG] [--html-file FILE | --dir DIR]"
    exit 1
  end

when "fetch"
  options = {}
  OptionParser.new do |opts|
    opts.on("--slug SLUG") { |v| options[:slug]    = v }
    opts.on("--out DIR")   { |v| options[:out_dir] = File.expand_path(v) }
  end.parse!
  cmd_fetch(slug: options[:slug], out_dir: options[:out_dir])

when "delete"
  options = {}
  OptionParser.new { |o| o.on("--slug SLUG") { |v| options[:slug] = v } }.parse!
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

when "logout"; cmd_logout
when "whoami"; cmd_whoami
when "claim"
  options = {}
  OptionParser.new { |o| o.on("--slug SLUG") { |v| options[:slug] = v } }.parse!
  cmd_claim(slug: options[:slug])

else
  warn "Usage: ruby publish.rb COMMAND [options]"
  warn "  publish     --name NAME [--html-file FILE | --dir DIR] [--slug SLUG]"
  warn "  fetch       [--slug SLUG] [--out DIR]"
  warn "  delete      [--slug SLUG]"
  warn "  check-slug  --q slug1,slug2,slug3"
  warn ""
  warn "  register    --email E --password P [--name N]"
  warn "  login       --email E --password P"
  warn "  logout"
  warn "  whoami"
  warn "  claim       [--slug SLUG]"
  exit 1
end
