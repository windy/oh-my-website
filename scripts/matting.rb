#!/usr/bin/env ruby
# 调用 showcode.com 抠图 API，下载透明背景 PNG
# Usage: ruby dev/matting.rb [--resize W] <input_image> [output_path]
#   --resize W      抠图后 resize 到 W 像素宽（同 sips -Z），可选
#   input_image:    JPEG/PNG/WebP 图片路径
#   output_path:    输出 PNG 路径（默认同目录下 _nobg.png）

require "json"
require "net/http"
require "uri"
require "fileutils"
require "optparse"

API_HOST = ENV.fetch("SHOWCODE_API_HOST", "https://showcode.com")
BASE_DIR = File.expand_path("~/.oh-my-site")
TOKEN_FILE   = File.join(BASE_DIR, "token.json")
ACCOUNT_FILE = File.join(BASE_DIR, "account.json")
MAX_POLLS = 10
POLL_INTERVAL = 2

def log(msg)
  $stderr.puts "[matting] #{msg}"
end

def load_json(path)
  return {} unless File.exist?(path)
  JSON.parse(File.read(path)) rescue {}
end

# 复用 publish.rb 的认证：优先 session_token（登录后），否则 site_token（已发布站点）
def token
  session_token = load_json(ACCOUNT_FILE)["session_token"]
  return session_token if session_token.to_s.length > 0

  site_token = load_json(TOKEN_FILE)["token"]
  return site_token if site_token.to_s.length > 0

  log "❌ 未找到认证 token：请先用 publish.rb 发布过站点（生成 token.json），或登录账号（生成 account.json）"
  exit 1
end

def http_json(method, path, token:, body: nil)
  uri = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 8
  http.read_timeout = 60

  req = case method
        when :get    then Net::HTTP::Get.new(uri)
        when :post   then Net::HTTP::Post.new(uri)
        end
  req["Authorization"] = "Bearer #{token}"
  req["Content-Type"] = "application/json"
  req.body = body.to_json if body

  resp = http.request(req)
  parsed = JSON.parse(resp.body) rescue {}
  [resp.code.to_i, parsed]
end

def detect_content_type(path)
  case File.extname(path).downcase
  when ".png"  then "image/png"
  when ".webp" then "image/webp"
  else "image/jpeg"
  end
end

def http_upload(path, file_path, token:)
  uri = URI.parse("#{API_HOST}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 8
  http.read_timeout = 60

  req = Net::HTTP::Post.new(uri)
  req["Authorization"] = "Bearer #{token}"
  content_type = detect_content_type(file_path)
  req.set_form([
    ["file", File.open(file_path, "rb"), { filename: File.basename(file_path),
                                           content_type: content_type }]
  ], "multipart/form-data")

  resp = http.request(req)
  parsed = JSON.parse(resp.body) rescue {}
  [resp.code.to_i, parsed]
end

def http_download(url, dest_path, token:)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.open_timeout = 8
  http.read_timeout = 30

  req = Net::HTTP::Get.new(uri)
  req["Authorization"] = "Bearer #{token}"

  http.request(req) do |resp|
    raise "download failed: #{resp.code}" unless resp.code.to_i == 200
    File.open(dest_path, "wb") { |f| resp.read_body { |chunk| f.write(chunk) } }
  end
end

# ── main ──────────────────────────────────────────────────────────────

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby dev/matting.rb [--resize W] <input_image> [output_path]"
  opts.on("--resize W", Integer, "抠图后 sips -Z 到 W 像素宽") { |w| options[:resize] = w }
end.parse!

input = ARGV.shift
output = ARGV.shift

unless input && File.exist?(input)
  log "Usage: ruby dev/matting.rb [--resize W] <input_image> [output_path]"
  exit 1
end

output ||= File.join(File.dirname(input), "#{File.basename(input, File.extname(input))}_nobg.png")

if File.size(input) > 10 * 1024 * 1024
  log "❌ 图片超过 10MB，请先压缩"
  exit 1
end

tk = token

# Step 1: 提交抠图任务
log "提交抠图任务: #{input}"
code, job = http_upload("/api/v1/matting", input, token: tk)
unless code == 202
  log "❌ 提交失败 (#{code}): #{job["error"] || job.inspect}"
  exit 1
end
job_id = job["job_id"]
log "任务 ID: #{job_id}"

# Step 2: 轮询等待
tmp_output = output + ".tmp"
MAX_POLLS.times do |i|
  sleep POLL_INTERVAL
  code, status = http_json(:get, "/api/v1/matting/#{job_id}", token: tk)

  case status["status"]
  when "completed"
    raw_url = status["result_url"]
    # API 返回的 result_url 可能已是完整 URL（含 https://），也可能只是 path
    result_url = raw_url.start_with?("http") ? raw_url : "#{API_HOST}#{raw_url}"
    log "完成！下载: #{result_url}"
    begin
      http_download(result_url, tmp_output, token: tk)
    rescue => e
      log "Ruby HTTP 下载失败 (#{e.class})，回退到 curl..."
      system("curl", "-s", "-L", "-H", "Authorization: Bearer #{tk}", "-o", tmp_output, result_url, exception: true)
    end

    if options[:resize]
      log "Resize 到 #{options[:resize]}px..."
      system("sips", "-Z", options[:resize].to_s, tmp_output, "--out", output, exception: true)
      FileUtils.rm_f(tmp_output)
    else
      FileUtils.mv(tmp_output, output)
    end

    log "✅ 保存到: #{output}"
    puts output
    exit 0
  when "failed"
    log "❌ 抠图失败: #{status["error"]}"
    exit 1
  else
    log "等待中... (#{i + 1}/#{MAX_POLLS})"
  end
end

log "❌ 超时（#{MAX_POLLS * POLL_INTERVAL}s）"
exit 1
