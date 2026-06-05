/* ============================================================
   共享脚本 · 汉堡菜单 + 导航高亮 + QR 分享 + 复制链接
   依赖: qrcode.min.js (qrcode-generator by kazuhikoarase)
   ============================================================ */

(function() {
  var navLinks = document.querySelectorAll('.nav-links a');
  var navMenu  = document.querySelector('.nav-links');
  var toggle   = document.querySelector('.nav-toggle');

  if (toggle) {
    toggle.addEventListener('click', function() {
      if (navMenu) navMenu.classList.toggle('open');
    });
  }

  var current = window.location.pathname.split('/').pop() || 'index.html';
  for (var i = 0; i < navLinks.length; i++) {
    var href = navLinks[i].getAttribute('href');
    if (href) {
      var page = href.split('/').pop();
      if (page === current || (current === '' && page === 'index.html')) {
        navLinks[i].classList.add('active');
      }
    }
  }

  if (navMenu) {
    navMenu.addEventListener('click', function(e) {
      if (e.target.tagName === 'A') {
        navMenu.classList.remove('open');
      }
    });
  }
})();

/* ============================================================
   QR Code SVG — uses qrcode-generator
   ============================================================ */
function generateQRCodeSVG(url, moduleSize) {
  var m = moduleSize || 8;
  var qr = qrcode(0, 'M');
  qr.addData(url);
  qr.make();
  var count = qr.getModuleCount();
  var quiet = 4;
  var qrPx = count * m;
  var totalPx = (count + quiet * 2) * m;
  var off = quiet * m;

  var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + totalPx + '" height="' + totalPx + '" viewBox="0 0 ' + totalPx + ' ' + totalPx + '">';
  svg += '<rect width="' + totalPx + '" height="' + totalPx + '" fill="#fff"/>';
  for (var r = 0; r < count; r++) {
    for (var c = 0; c < count; c++) {
      if (qr.isDark(r, c)) {
        svg += '<rect x="' + (off + c * m) + '" y="' + (off + r * m) + '" width="' + m + '" height="' + m + '" fill="#1a1a1a"/>';
      }
    }
  }
  svg += '</svg>';
  return svg;
}

/* ============================================================
   Share UI — QR popup + copy link
   ============================================================ */
(function() {
  var url = window.location.href;

  var overlay = document.createElement('div');
  overlay.className = 'qr-overlay';

  var popup = document.createElement('div');
  popup.className = 'qr-popup';
  popup.innerHTML =
    '<div class="qr-code-container"></div>' +
    '<p class="qr-hint">扫描二维码访问本页</p>' +
    '<code class="qr-url">' + escapeHTML(url) + '</code>' +
    '<button class="qr-close">关闭</button>';

  overlay.appendChild(popup);
  document.body.appendChild(overlay);

  var qrContainer = popup.querySelector('.qr-code-container');
  try {
    qrContainer.innerHTML = generateQRCodeSVG(url, 6);
  } catch(e) {
    qrContainer.innerHTML = '<p style="color:var(--text-tertiary);padding:20px">QR 生成失败</p>';
  }

  overlay.addEventListener('click', function(e) {
    if (e.target === overlay || e.target.classList.contains('qr-close')) {
      overlay.classList.remove('open');
    }
  });

  document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') overlay.classList.remove('open');
  });

  window.toggleQR = function() {
    overlay.classList.toggle('open');
  };

  window.copyLink = function(btn) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(function() {
        showCopied(btn);
      }).catch(function() {
        fallbackCopy(btn);
      });
    } else {
      fallbackCopy(btn);
    }
  };

  function fallbackCopy(btn) {
    var ta = document.createElement('textarea');
    ta.value = url;
    ta.style.position = 'fixed'; ta.style.opacity = '0';
    document.body.appendChild(ta);
    ta.select();
    try { document.execCommand('copy'); showCopied(btn); } catch(e) {}
    document.body.removeChild(ta);
  }

  function showCopied(btn) {
    btn.classList.add('copied');
    var orig = btn.innerHTML;
    btn.innerHTML = '<svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="20 6 9 17 4 12"/></svg> 已复制';
    setTimeout(function() {
      btn.classList.remove('copied');
      btn.innerHTML = orig;
    }, 1500);
  }

  function escapeHTML(str) {
    var div = document.createElement('div');
    div.appendChild(document.createTextNode(str));
    return div.innerHTML;
  }
})();

/* ============================================================
   滚动淡入 — 给元素加 .fade-in，进入视口时加 .visible
   仅在页面有 .fade-in 元素时生效，对 minimal 模板无影响
   ============================================================ */
(function() {
  var els = document.querySelectorAll('.fade-in');
  if (!els.length) return;

  if (!('IntersectionObserver' in window)) {
    // 老浏览器直接全部显示
    for (var i = 0; i < els.length; i++) els[i].classList.add('visible');
    return;
  }

  var io = new IntersectionObserver(function(entries) {
    entries.forEach(function(e) {
      if (e.isIntersecting) {
        e.target.classList.add('visible');
        io.unobserve(e.target);
      }
    });
  }, { threshold: 0.15, rootMargin: '0px 0px -8% 0px' });

  els.forEach(function(el) { io.observe(el); });
})();
