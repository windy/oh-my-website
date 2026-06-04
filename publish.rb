#!/usr/bin/env ruby
# publish.rb — Publish or delete a personal website on showcode.com
#
# Usage:
#   ruby publish.rb publish --name "NAME" --dir /path/to/site   (multi-page)
#   ruby publish.rb publish --name "NAME" --html-file FILE      (single page)
#   ruby publish.rb delete  [--slug SLUG]
#
# On first publish, prints the page URL and saves the token to
# ~/clacky_workspace/personal_website/token.json (used for future updates/deletes).
#
# Environment:
#   SHOWCODE_API_HOST — platform base URL (default: https://showcode.com)
#   use http://localhost:5000 for local dev

require "net/http"
require "uri"
require "json"
require "optparse"
require "fileutils"

API_HOST   = ENV.fetch("SHOWCODE_API_HOST", "https://showcode.com")
TOKEN_FILE = File.expand_path("~/clacky_workspace/personal_website/token.json")
MAX_SIZE   = 1_048_576 # 1MB

def http_request(method, path, body: nil, token: nil)
  uri  = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl      = uri.scheme == "https"
  http.open_timeout = 8
  http.read_timeout = 15

  req_class = { "POST" => Net::HTTP::Post, "PUT" => Net::HTTP::Put,
                "DELETE" => Net::HTTP::Delete }[method]
  req = req_class.new(uri.path)
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

# ── Single-file publish ──────────────────────────────────────────────

def publish_single(name:, html_file:)
  unless File.exist?(html_file)
    warn "❌ HTML file not found: #{html_file}"
    exit 1
  end

  content = File.read(html_file, encoding: "utf-8")
  validate_size!(content, html_file)

  token_data = load_token_data
  slug  = token_data["slug"]
  token = token_data["token"]

  if slug && token
    status, body = http_request("PUT", "/api/v1/sites/#{slug}",
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
    status, body = http_request("POST", "/api/v1/sites",
                                body: { name: name, content: content })
    if status == 201
      save_token_data("slug" => body["slug"], "token" => body["token"], "version" => 1)
      puts "✅ Website published: #{body["url"]}"
      puts "   Slug: #{body["slug"]}"
      puts "   Token saved to: #{TOKEN_FILE}"
    else
      warn "❌ Publish failed (#{status}): #{body["error"] || body.inspect}"
      exit 1
    end
  end
end

# ── Multi-page (directory) publish ────────────────────────────────────

def publish_dir(name:, dir:)
  unless Dir.exist?(dir)
    warn "❌ Directory not found: #{dir}"
    exit 1
  end

  index_file = File.join(dir, "index.html")
  unless File.exist?(index_file)
    warn "❌ index.html not found in #{dir}"
    exit 1
  end

  index_content = File.read(index_file, encoding: "utf-8")
  validate_size!(index_content, "index.html")

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

  token_data = load_token_data
  slug  = token_data["slug"]
  token = token_data["token"]

  if slug && token
    # ── Update existing site ──
    status, body = http_request("PUT", "/api/v1/sites/#{slug}",
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

    sub_pages.each do |path, title, content|
      status, body = http_request("POST", "/api/v1/sites/#{slug}/pages",
                                  body: { path: path, title: title, content: content },
                                  token: token)
      if status == 200
        puts "   📄 #{path} → #{body["url"]}"
      else
        warn "   ⚠️  #{path} failed (#{status}): #{body["error"] || body.inspect}"
      end
    end
  else
    # ── First publish ──
    status, body = http_request("POST", "/api/v1/sites",
                                body: { name: name, content: index_content })
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

    sub_pages.each do |path, title, content|
      status, body = http_request("POST", "/api/v1/sites/#{slug}/pages",
                                  body: { path: path, title: title, content: content },
                                  token: token)
      if status == 200
        puts "   📄 #{path} → #{body["url"]}"
      else
        warn "   ⚠️  #{path} failed (#{status}): #{body["error"] || body.inspect}"
      end
    end
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
    opts.on("--html-file FILE")     { |v| options[:html_file] = v }
    opts.on("--dir DIR")            { |v| options[:dir]       = v }
  end.parse!

  unless options[:name]
    warn "Usage: ruby publish.rb publish --name NAME [--html-file FILE | --dir DIR]"
    exit 1
  end

  if options[:dir]
    publish_dir(name: options[:name], dir: File.expand_path(options[:dir]))
  elsif options[:html_file]
    publish_single(name: options[:name], html_file: File.expand_path(options[:html_file]))
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

else
  warn "Usage: ruby publish.rb publish|delete [options]"
  warn "  publish --name NAME [--html-file FILE | --dir DIR]"
  warn "  delete  [--slug SLUG]"
  exit 1
end
