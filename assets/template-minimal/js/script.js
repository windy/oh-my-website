/* ============================================================
   共享脚本 · 汉堡菜单 + 导航当前页高亮
   ============================================================ */

(function() {
  var navLinks = document.querySelectorAll('.nav-links a');
  var navMenu  = document.querySelector('.nav-links');
  var toggle   = document.querySelector('.nav-toggle');

  // 汉堡菜单
  if (toggle) {
    toggle.addEventListener('click', function() {
      if (navMenu) navMenu.classList.toggle('open');
    });
  }

  // 根据当前 URL 高亮对应导航项
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

  // 点击导航链接后关闭移动端菜单
  if (navMenu) {
    navMenu.addEventListener('click', function(e) {
      if (e.target.tagName === 'A') {
        navMenu.classList.remove('open');
      }
    });
  }
})();
