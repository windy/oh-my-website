#!/usr/bin/env ruby
# frozen_string_literal: true

# fetch_platform_content.rb — 从 B站/小红书/抖音 抓取内容，下载封面图，输出 JSON
#
# 用法：
#   # 从 URL 直接抓取（B站 API 大概率被反爬）
#   ruby fetch_platform_content.rb --url "https://space.bilibili.com/546195" --out-dir /tmp/site/images
#
#   # 从浏览器抓取后的 JSON 数据导入（推荐）
#   ruby fetch_platform_content.rb --from-json /tmp/scraped.json --out-dir /tmp/site/images
#
#   # 检测 URL 类型
#   ruby fetch_platform_content.rb --detect "https://www.xiaohongshu.com/user/profile/xxx"
#
# 输出（stdout）：JSON，每行一个作品
# {
#   "platform": "bilibili",
#   "items": [
#     {
#       "title": "视频标题",
#       "description": "视频简介",
#       "cover_url": "https://...",
#       "cover_local": "images/bilibili-cover-1.jpg",
#       "url": "https://www.bilibili.com/video/BVxxx",
#       "stats": { "play": "12.3万", "like": "1.2万" },
#       "tags": ["知识", "科普"]
#     }
#   ]
# }

require 'net/http'
require 'uri'
require 'json'
require 'fileutils'
require 'open-uri'

# ============================================================
# 平台检测
# ============================================================

module PlatformDetector
  PATTERNS = {
    'bilibili' => %r{bilibili\.com/(?:video/|(\d+))},
    'xiaohongshu' => %r{xiaohongshu\.com/(?:user/profile|explore)/([a-f0-9]+)},
    'douyin' => %r{douyin\.com/user/([A-Za-z0-9_-]+)}
  }.freeze

  def self.detect(url)
    PATTERNS.each do |platform, regex|
      match = url.match(regex)
      return { platform: platform, uid: match[1] } if match
    end
    nil
  end

  def self.platform_label(platform)
    {
      'bilibili' => 'B站',
      'xiaohongshu' => '小红书',
      'douyin' => '抖音'
    }[platform] || platform
  end

  def self.platform_badge(platform)
    {
      'bilibili' => 'Bilibili',
      'xiaohongshu' => 'RedBook',
      'douyin' => 'Douyin'
    }[platform] || platform
  end
end

# ============================================================
# 图片下载器
# ============================================================

module ImageDownloader
  MAX_IMAGE_SIZE = 5 * 1024 * 1024 # 5MB

  def self.download(url, dest_dir, prefix)
    FileUtils.mkdir_p(dest_dir)

    # 从 URL 推断扩展名
    ext = File.extname(URI.parse(url).path)
    ext = '.jpg' if ext.empty? || ext.length > 5
    ext = '.jpg' if ext == '.webp' # 统一转 jpg 引用

    # 文件名：prefix-001.jpg
    existing = Dir.glob(File.join(dest_dir, "#{prefix}-*"))
    idx = existing.size + 1
    filename = format("#{prefix}-%03d#{ext}", idx)
    dest_path = File.join(dest_dir, filename)

    begin
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.open_timeout = 10
      http.read_timeout = 15

      req = Net::HTTP::Get.new(uri)
      req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36'
      req['Referer'] = 'https://www.bilibili.com/'

      http.request(req) do |response|
        if response.code.to_i == 200
          File.open(dest_path, 'wb') do |f|
            response.read_body do |chunk|
              f.write(chunk)
              # 检查大小限制
              if f.size > MAX_IMAGE_SIZE
                File.delete(dest_path) rescue nil
                return nil
              end
            end
          end
          return filename
        end
      end
    rescue => e
      warn "[WARN] Failed to download #{url}: #{e.message}"
      return nil
    end
    nil
  end
end

# ============================================================
# B站抓取器
# ============================================================

module BilibiliFetcher
  BASE_API = 'https://api.bilibili.com'.freeze

  # 尝试通过 API 获取用户视频
  def self.fetch_space_videos(uid, max_items: 6)
    uri = URI("#{BASE_API}/x/space/wbi/arc/search?mid=#{uid}&ps=#{max_items}&pn=1")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 10
    http.read_timeout = 15

    req = Net::HTTP::Get.new(uri)
    req['User-Agent'] = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36'
    req['Referer'] = "https://space.bilibili.com/#{uid}/video"

    response = http.request(req)
    return nil unless response.code.to_i == 200

    data = JSON.parse(response.body)
    return nil unless data['code'] == 0

    videos = data.dig('data', 'list', 'vlist') || []
    videos.first(max_items).map do |v|
      {
        'title' => v['title'],
        'description' => v['description'] || '',
        'cover_url' => v['pic'],
        'url' => "https://www.bilibili.com/video/#{v['bvid']}",
        'stats' => {
          'play' => format_count(v['play']),
          'comment' => format_count(v['comment'])
        },
        'tags' => extract_tags(v['title'], v['description'])
      }
    end
  rescue => e
    warn "[WARN] Bilibili API failed: #{e.message}"
    nil
  end

  def self.format_count(num)
    return '0' if num.nil? || num == 0
    if num >= 10_000
      "#{(num / 10_000.0).round(1)}万"
    else
      num.to_s
    end
  end

  def self.extract_tags(title, desc)
    # 从标题和描述中提取关键词作为标签
    keywords = %w[知识 科普 教程 测评 生活 Vlog 干货 技术 设计 创意 搞笑 游戏 音乐 美食 穿搭 职场 学习 效率]
    text = "#{title} #{desc}"
    keywords.select { |kw| text.include?(kw) }.first(3)
  end
end

# ============================================================
# JSON 导入模式（从浏览器抓取的数据）
# ============================================================

module JsonImport
  # 从 JSON 文件读取已抓取数据，下载封面图
  def self.process(json_path, out_dir)
    data = JSON.parse(File.read(json_path))
    items = data['items'] || []

    items.each_with_index do |item, i|
      cover_url = item['cover_url'] || item['cover']
      next unless cover_url

      prefix = "#{data['platform'] || 'platform'}-cover"
      local = ImageDownloader.download(cover_url, out_dir, prefix)
      item['cover_local'] = local ? "images/#{local}" : nil
      item['cover_downloaded'] = !local.nil?
    end

    data
  end
end

# ============================================================
# Main
# ============================================================

require 'optparse'

options = {
  out_dir: 'images',
  max_items: 6
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: fetch_platform_content.rb [options]'

  opts.on('--url URL', 'Platform URL to fetch') { |v| options[:url] = v }
  opts.on('--from-json PATH', 'Import pre-scraped JSON data') { |v| options[:json_path] = v }
  opts.on('--detect URL', 'Detect platform from URL') { |v| options[:detect] = v }
  opts.on('--out-dir DIR', 'Output directory for images') { |v| options[:out_dir] = v }
  opts.on('--max-items N', Integer, 'Max items to fetch') { |v| options[:max_items] = v }
  opts.on('--help', 'Show help') { puts opts; exit }
end

parser.parse!

# --detect 模式：只检测平台类型
if options[:detect]
  result = PlatformDetector.detect(options[:detect])
  if result
    puts JSON.generate(result)
  else
    puts JSON.generate({ error: 'unknown_platform', url: options[:detect] })
  end
  exit
end

# --from-json 模式：从 JSON 导入并下载图片
if options[:json_path]
  unless File.exist?(options[:json_path])
    warn "Error: JSON file not found: #{options[:json_path]}"
    exit 1
  end
  result = JsonImport.process(options[:json_path], options[:out_dir])
  puts JSON.pretty_generate(result)
  exit
end

# --url 模式：尝试直接抓取
if options[:url]
  info = PlatformDetector.detect(options[:url])
  unless info
    warn "Error: Cannot detect platform from URL: #{options[:url]}"
    warn "Supported: bilibili.com, xiaohongshu.com, douyin.com"
    exit 1
  end

  case info[:platform]
  when 'bilibili'
    items = BilibiliFetcher.fetch_space_videos(info[:uid], max_items: options[:max_items])
    if items.nil? || items.empty?
      warn "⚠️  B站 API 抓取失败（反爬保护）。请使用浏览器抓取后通过 --from-json 导入。"
      warn "   浏览器打开 https://space.bilibili.com/#{info[:uid]}/video"
      warn "   在 console 中执行以下代码获取数据："
      warn ""
      warn "   copy(JSON.stringify({platform:'bilibili',items:Array.from(document.querySelectorAll('.video-items .small-item')).map(el=>({"
      warn "     title: el.querySelector('.title')?.textContent?.trim(),"
      warn "     cover_url: el.querySelector('img')?.src?.replace('@412w_232h',''),"
      warn "     url: 'https:' + el.querySelector('a')?.getAttribute('href'),"
      warn "     description: el.querySelector('.des')?.textContent?.trim() || ''"
      warn "   }))}))"
      warn ""
      exit 1
    end

    # 下载封面图
    items.each_with_index do |item, i|
      next unless item['cover_url']
      prefix = "bilibili-cover"
      local = ImageDownloader.download(item['cover_url'], options[:out_dir], prefix)
      item['cover_local'] = local ? "images/#{local}" : nil
    end

    result = { platform: 'bilibili', items: items }
    puts JSON.pretty_generate(result)
  else
    warn "⚠️  #{PlatformDetector.platform_label(info[:platform])} 不支持直接 HTTP 抓取。"
    warn "   请使用浏览器抓取后通过 --from-json 导入。"
    warn "   JSON 格式见脚本注释。"
    exit 1
  end
  exit
end

# 无参数：显示帮助
puts parser
exit 1
