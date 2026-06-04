#!/usr/bin/env ruby
# publish.rb — Publish or delete a personal website on showcode.com
#
# Usage:
#   ruby publish.rb publish --name "NAME" --dir /path/to/site   (multi-page)
#   ruby publish.rb publish --name "NAME" --html-file FILE      (single page)
#   ruby publish.rb delete  [--slug SLUG]
#   ruby publish.rb reset                                       (clear local token)
#
# On first publish, prints the page URL and saves the token to
# ~/clacky_workspace/oh-my-website/token.json (used for future updates/deletes).
#
# Environment:
#   SHOWCODE_API_HOST — platform base URL (default: https://showcode.com)
#                       For local dev: http://localhost:3000 (or whatever port)
#                       The publish output URLs always say "https://showcode.com/~slug"
#                       — when running locally, mentally rewrite to your local host.
#
# Behavior on stale/invalid token:
#   If a saved token returns 401/403/500 on update, publish.rb auto-clears the
#   local token.json and falls back to creating a new site. This keeps things
#   working when a local dev DB has been reset.

require "net/http"
require "uri"
require "json"
require "optparse"
require "fileutils"

API_HOST   = ENV.fetch("SHOWCODE_API_HOST", "https://showcode.com")
TOKEN_FILE = File.expand_path("~/clacky_workspace/oh-my-website/token.json")
MAX_SIZE   = 1_048_576 # 1MB

def http_request(method, path, body: nil, token: nil)
  uri  = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.open_timeout = 8
  http.read_timeout = 15

  req_class = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post,
                "PUT" => Net::HTTP::Put, "DELETE" => Net::HTTP::Delete }[method]
  req = req_class.new(method == "GET" ? uri.request_uri : uri.path)
  req["Content-Type"]  = "application/json"
  req["Authorization"] = "Bearer #{token}" if token
  req.body = body.to_json if body

  response = http.request(req)
  parsed   = JSON.parse(response.body) rescue { "raw" => response.body }
  [response.code.to_i, parsed]
end

def load_token_data
  return {} unless File.exist?(TOKEN_FILE)
  JSON.parse(File.read(TOKEN_FILE)) rescue {}
end

def save_token_data(data)
  FileUtils.mkdir_p(File.dirname(TOKEN_FILE))
  File.write(TOKEN_FILE, JSON.pretty_generate(data))
  File.chmod(0600, TOKEN_FILE)
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

# Inject <base href="/~slug/"> so relative URLs (css/style.css, js/script.js)
# resolve correctly from any sub-page like /~slug/about
def inject_base_tag(html, slug)
  return html unless slug
  html.sub(/<head>/i, "<head>\n  <base href=\"/~#{slug}/\">")
end

# Collect non-HTML asset files (CSS, JS, fonts, etc.) from the site directory.
# Returns array of [relative_path, content_string] pairs.
def collect_assets(dir)
  assets = []
  # Walk the entire directory tree, skip HTML files
  Dir.glob(File.join(dir, "**/*"), File::FNM_DOTMATCH).each do |f|
    next unless File.file?(f)
    next if f.end_with?(".html")
    next if File.basename(f).start_with?(".")  # skip hidden files

    rel_path = f.sub(dir + "/", "")
    content  = File.read(f, encoding: "utf-8")
    validate_size!(content, rel_path)
    assets << [rel_path, content]
  end
  assets
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
  saved_slug  = token_data["slug"]
  token = token_data["token"]

  if saved_slug && token
    content = inject_base_tag(content, saved_slug)
    status, body = http_request("PUT", "/api/v1/sites/#{saved_slug}",
                                body: { name: name, content: content },
                                token: token)
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
    status, body = http_request("POST", "/api/v1/sites",
                                body: post_body)
    if status == 201
      slug  = body["slug"]
      token = body["token"]
      save_token_data("slug" => slug, "token" => token, "version" => 1)

      # Now inject base tag and update
      content = inject_base_tag(content, slug)
      http_request("PUT", "/api/v1/sites/#{slug}",
                   body: { name: name, content: content }, token: token)

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

  index_raw = File.read(index_file, encoding: "utf-8")
  validate_size!(index_raw, "index.html")

  # Collect sub-pages (all .html files except index.html)
  sub_pages = Dir.glob(File.join(dir, "*.html"))
    .reject { |f| File.basename(f) == "index.html" }
    .map do |f|
      raw = File.read(f, encoding: "utf-8")
      validate_size!(raw, File.basename(f))
      basename = File.basename(f, ".html")  # e.g. "about"
      title = extract_title(raw) || basename.capitalize
      [basename, title, raw]  # path without .html (Rails strips format extension)
    end

  # Collect assets (css/, js/, fonts/, images/, etc.)
  assets = collect_assets(dir)

  token_data = load_token_data
  saved_slug  = token_data["slug"]
  token = token_data["token"]

  if saved_slug && token
    # ── Update existing site ──
    index_content = inject_base_tag(index_raw, saved_slug)
    status, body = http_request("PUT", "/api/v1/sites/#{saved_slug}",
                                body: { name: name, content: index_content },
                                token: token)
    if status == 200
      token_data["version"] = body["version"]
      save_token_data(token_data)
      puts "✅ Main page updated: #{body["url"]}"
    else
      warn "❌ Update failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end

    upload_pages_and_assets(saved_slug, token, sub_pages, assets)
  else
    # ── First publish: upload without base tag, get slug, then inject and update ──
    post_body = { name: name, content: index_raw }
    post_body[:slug] = slug if slug
    status, body = http_request("POST", "/api/v1/sites",
                                body: post_body)
    unless status == 201
      warn "❌ Publish failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end

    slug  = body["slug"]
    token = body["token"]
    save_token_data("slug" => slug, "token" => token, "version" => 1)
    puts "✅ Website published: #{body["url"]}"
    puts "   Slug: #{slug}"
    puts "   Token saved to: #{TOKEN_FILE}"

    # Inject <base> and update main page
    index_content = inject_base_tag(index_raw, slug)
    http_request("PUT", "/api/v1/sites/#{slug}",
                 body: { name: name, content: index_content }, token: token)

    upload_pages_and_assets(slug, token, sub_pages, assets)
  end
end

def upload_pages_and_assets(slug, token, sub_pages, assets)
  # Upload sub-pages (HTML files)
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

  # Upload asset files (CSS, JS, etc.)
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
    warn "Usage: ruby publish.rb publish --name NAME --dir /path/to/site"
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

else
  warn "Usage: ruby publish.rb publish|delete|check-slug [options]"
  warn "  publish     --name NAME [--html-file FILE | --dir DIR]"
  warn "  delete      [--slug SLUG]"
  warn "  check-slug  --q slug1,slug2,slug3"
  exit 1
end
