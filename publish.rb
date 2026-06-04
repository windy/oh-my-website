#!/usr/bin/env ruby
# publish.rb — Publish or delete a personal website on showcode.com
#
# Usage:
#   ruby publish.rb publish --name "NAME" --html-file /path/to/card.html
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

API_HOST  = ENV.fetch("SHOWCODE_API_HOST", "https://showcode.com")
TOKEN_FILE = File.expand_path("~/clacky_workspace/personal_website/token.json")

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

def cmd_publish(name:, html_file:)
  unless File.exist?(html_file)
    warn "❌ HTML file not found: #{html_file}"
    exit 1
  end

  html_content = File.read(html_file, encoding: "utf-8")
  if html_content.bytesize > 1_048_576
    warn "❌ HTML file exceeds 1MB (#{html_content.bytesize / 1024}KB)"
    exit 1
  end

  token_data = load_token_data

  if token_data["slug"] && token_data["token"]
    # Update existing site
    slug  = token_data["slug"]
    token = token_data["token"]
    status, body = http_request("PUT", "/api/v1/sites/#{slug}",
                                body: { name: name, content: html_content },
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
    # First publish
    status, body = http_request("POST", "/api/v1/sites",
                                body: { name: name, content: html_content })

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

command = ARGV.shift

case command
when "publish"
  options = {}
  OptionParser.new do |opts|
    opts.on("--name NAME")          { |v| options[:name]      = v }
    opts.on("--html-file FILE")     { |v| options[:html_file] = v }
  end.parse!

  unless options[:name] && options[:html_file]
    warn "Usage: ruby publish.rb publish --name NAME --html-file FILE"
    exit 1
  end

  cmd_publish(name: options[:name], html_file: File.expand_path(options[:html_file]))

when "delete"
  options = {}
  OptionParser.new do |opts|
    opts.on("--slug SLUG") { |v| options[:slug] = v }
  end.parse!

  cmd_delete(slug: options[:slug])

else
  warn "Usage: ruby publish.rb publish|delete [options]"
  warn "  publish --name NAME --html-file FILE"
  warn "  delete  [--slug SLUG]"
  exit 1
end
