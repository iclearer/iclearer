(function () {
  var de = document.documentElement;
  var rm = matchMedia("(prefers-reduced-motion:reduce)").matches;
  de.classList.add("js");
  function $(i) { return document.getElementById(i); }

  /* Glass bead icons, defined once and reused with <use href="#g-…"> */
  var D = '<linearGradient id="gr" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff" stop-opacity=".95"/><stop offset=".6" stop-color="#fff" stop-opacity=".15"/><stop offset="1" stop-color="#fff" stop-opacity=".5"/></linearGradient>';
  function rad(i, a, b, c) { return '<radialGradient id="' + i + '" cx=".4" cy=".35" r=".75"><stop offset="0" stop-color="' + a + '"/><stop offset=".55" stop-color="' + b + '"/><stop offset="1" stop-color="' + c + '"/></radialGradient>'; }
  var GL = {
    scan: ["#CFE8FA", "#5FA6DA", "#2D6DA4", '<circle cx="100" cy="98" r="34" fill="none"/><path d="M125 123L154 152"/>'],
    see: ["#E4F6FB", "#7FCBE6", "#2F95C4", '<circle cx="112" cy="74" r="12" fill="#fff" stroke="none"/><rect x="100" y="98" width="24" height="62" rx="12" fill="#fff" stroke="none"/>'],
    dev: ["#6B8197", "#34465A", "#1C2733", '<path d="M88 84L60 112L88 140"/><path d="M136 84L164 112L136 140"/><path d="M122 76L102 148"/>'],
    map: ["#E4F6FB", "#7FCBE6", "#2F95C4", '<circle cx="112" cy="112" r="46" fill="none"/><path d="M112 66v46l32 20" fill="none"/>'],
    lf: ["#FFE6B8", "#F4B550", "#C97A12", '<path d="M80 64h46l26 26v70H80z" fill="none"/><path d="M126 64v26h26" fill="none"/>'],
    ap: ["#D5DEF0", "#8AA0C4", "#556E99", '<rect x="70" y="70" width="34" height="34" rx="8" fill="none"/><rect x="120" y="70" width="34" height="34" rx="8" fill="none"/><rect x="70" y="120" width="34" height="34" rx="8" fill="none"/><rect x="120" y="120" width="34" height="34" rx="8" fill="none"/>'],
    st: ["#FFD2CB", "#F19A8E", "#D1544A", '<path d="M112 70v42" fill="none"/><path d="M80 90a46 46 0 1 0 64 0" fill="none"/>'],
    pv: ["#E1DBFF", "#9A8AE0", "#5D4FC2", '<path d="M112 62l44 18v32c0 28-18 48-44 60-26-12-44-32-44-60V80z" fill="none"/><path d="M92 112l14 14 28-28" fill="none"/>'],
    hs: ["#C9F4EF", "#5FD0C8", "#2A8F8F", '<circle cx="112" cy="112" r="48" fill="none"/><path d="M112 82v32l24 14" fill="none"/>'],
    safe: ["#C8F1DD", "#58C193", "#2A8F63", '<rect x="76" y="108" width="72" height="52" rx="13" fill="#fff" stroke="none"/><path d="M92 108V92a20 20 0 0 1 40 0V108" fill="none"/>']
  };
  Object.keys(GL).forEach(function (k) {
    var g = GL[k];
    D += rad("gg" + k, g[0], g[1], g[2]) + '<symbol id="g-' + k + '" viewBox="0 0 224 224"><circle cx="112" cy="112" r="108" fill="url(#gg' + k + ')"/><circle cx="112" cy="112" r="105" fill="none" stroke="url(#gr)" stroke-width="5"/><g transform="translate(0 5)" stroke="#06223a" stroke-opacity=".28" stroke-width="13" stroke-linecap="round" stroke-linejoin="round" fill="#06223a" fill-opacity=".28">' + g[3] + '</g><g stroke="#fff" stroke-width="13" stroke-linecap="round" stroke-linejoin="round" fill="#fff">' + g[3] + '</g><ellipse cx="74" cy="56" rx="38" ry="19" transform="rotate(-35 74 56)" fill="#fff" opacity=".6"/><ellipse cx="150" cy="168" rx="44" ry="17" transform="rotate(-40 150 168)" fill="#fff" opacity=".22"/></symbol>';
  });
  $("defs").innerHTML = D;

  /* App window mockups: add the sidebar, then scale each window to its box */
  var TABS = [
    ["Clean"],
    ["Overview", "#5fa6da"], ["Clean", "#5fb4e0", "13.5 GB"], ["Storage Map", "#58c193"], ["Large & Old Files", "#f0b24a"], ["Apps", "#8aa0c4"], ["Builders", "#5b6b7d", "33.2 GB"],
    ["Activity"],
    ["History", "#5fd0c8"]
  ];
  document.querySelectorAll(".win").forEach(function (w) {
    var on = w.getAttribute("data-tab"), h = '<div class="sb-tl"><i></i><i></i><i></i></div>';
    TABS.forEach(function (t) {
      h += t.length === 1
        ? "<small>" + t[0] + "</small>"
        : '<b' + (t[0] === on ? ' class="on"' : "") + '><s style="--c:' + t[1] + '"></s>' + t[0].replace("&", "&amp;") + (t[2] ? "<span>" + t[2] + "</span>" : "") + "</b>";
    });
    var sb = document.createElement("div");
    sb.className = "sb";
    sb.setAttribute("aria-hidden", "true");
    sb.innerHTML = h + '<div class="sb-pl"><strong>iClearer Yearly</strong>1 of 1 Mac used</div>';
    w.insertBefore(sb, w.firstChild);
  });
  var shots = document.querySelectorAll(".shot");
  function fit() {
    shots.forEach(function (s) { s.style.setProperty("--k", (s.clientWidth / (+s.getAttribute("data-w") || 640)).toFixed(4)); });
  }
  fit();
  addEventListener("resize", fit);
  if (window.ResizeObserver) { var ro = new ResizeObserver(fit); shots.forEach(function (s) { ro.observe(s); }); }

  /* Pricing selectors (ids are read by the buy flow in main.ts).
     Prefill from ?plan= & ?macs= so Unlock → browser opens the seat/plan you picked. */
  var P = { Yearly: [29.99, 44.99, 74.99], Monthly: [4.99, 7.99, 12.99], "One-time": [79.99, 119.99, 189.99] };
  var qs = new URLSearchParams(location.search);
  var planQ = (qs.get("plan") || "").toLowerCase();
  var per = planQ === "monthly" ? "Monthly" : planQ === "once" || planQ === "one-time" ? "One-time" : "Yearly";
  var macQ = Number(qs.get("macs") || 0);
  var mc = macQ >= 5 ? 2 : macQ >= 2 ? 1 : 0;
  function seg(id, list, cur, fn) {
    var e = $(id);
    e.innerHTML = "";
    list.forEach(function (x, i) {
      var b = document.createElement("button");
      b.type = "button";
      b.textContent = x;
      b.setAttribute("aria-pressed", cur == x || cur === i);
      b.onclick = function () {
        fn(x, i);
        // Clear sticky URL plan/macs so later clicks on the page use the buttons.
        if (history.replaceState) {
          var u = new URL(location.href);
          u.searchParams.delete("plan");
          u.searchParams.delete("macs");
          history.replaceState({}, "", u.pathname + u.search + u.hash);
        }
        rp();
      };
      e.appendChild(b);
    });
  }
  function rp() {
    seg("sp", ["Yearly", "Monthly", "One-time"], per, function (x) { per = x; });
    seg("sm", ["1 Mac", "2 Macs", "5 Macs"], mc, function (x, i) { mc = i; });
    var v = P[per][mc], p = $("pp"), n = $("pn");
    if (per == "Yearly") { p.innerHTML = "$" + (v / 12).toFixed(2) + "<small> / month</small>"; n.textContent = "Billed $" + v.toFixed(2) + " per year. Cancel anytime."; }
    else if (per == "Monthly") { p.innerHTML = "$" + v.toFixed(2) + "<small> / month</small>"; n.textContent = "Billed monthly. Cancel anytime."; }
    else { p.innerHTML = "$" + v.toFixed(2); n.textContent = "One-time purchase for version 1. Version 2 is a discounted upgrade."; }
    var seats = [1, 2, 5][mc] || 1;
    var l = ["Unlimited cleanup", "Item names, details and exact locations", "Full Storage Map, large files and Quick Look", "App uninstaller with leftovers", "Builders pack for developers and AI tools", "History with restore and a never-touch list", "Bug and safety fixes", "Use on " + seats + " Mac" + (seats === 1 ? "" : "s") + " (each Mac is linked to your key)"];
    if (per != "One-time") l.push("Priority support, scheduled scans and menu bar alerts (1.1)");
    $("pl").innerHTML = l.map(function (x) { return "<li>" + x + "</li>"; }).join("");
  }
  rp();

  /* Before / after disk bars */
  var CL = [["Apps", "#3B7CB0"], ["Developer", "#5b6b7d"], ["Photos", "#3FA877"], ["System", "#8d97a3"], ["Other", "#6b7785"], ["Free", "#2a3340"]];
  function bar(id, v) { $(id).innerHTML = v.map(function (x, i) { return '<i style="flex:' + x + ";background:" + CL[i][1] + '"></i>'; }).join(""); }
  bar("b1", [20, 24, 16, 10, 8, 22]);
  bar("b2", [20, 21, 16, 10, 6, 27]);
  $("l1").innerHTML = CL.map(function (c) { return '<span><b style="background:' + c[1] + '"></b>' + c[0] + "</span>"; }).join("");

  /* Scan progress loop, started when its window scrolls into view */
  var scT;
  function scan() {
    clearInterval(scT);
    var k = 0;
    scT = setInterval(function () {
      k += 2;
      var p = Math.min(100, k);
      $("pbi").style.width = p + "%";
      $("sc").textContent = p < 100 ? Math.round(p * 142.08).toLocaleString("en-US") + " items checked" : "Scan complete";
      if (k >= 140) k = -40;
    }, 60);
  }
  if (rm) { $("pbi").style.width = "100%"; $("sc").textContent = "Scan complete"; }

  /* Reveal on scroll */
  var rs = document.querySelectorAll(".r");
  if ("IntersectionObserver" in window) {
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (!e.isIntersecting) return;
        e.target.classList.add("in");
        if (!rm && e.target.querySelector("#pbi")) scan();
        io.unobserve(e.target);
      });
    }, { threshold: 0.15 });
    rs.forEach(function (e) { io.observe(e); });
  } else {
    rs.forEach(function (e) { e.classList.add("in"); });
  }

  /* Reviews: arrows only appear when the cards overflow */
  var rl = $("rv-list"), pv = $("rv-prev"), nx = $("rv-next"), rvWired = false;
  function rvState() {
    if (!rl || !pv || !nx) return;
    var ov = rl.scrollWidth > rl.clientWidth + 4;
    pv.hidden = !ov || rl.scrollLeft < 8;
    nx.hidden = !ov || rl.scrollLeft > rl.scrollWidth - rl.clientWidth - 8;
  }
  function rvGo(d) {
    var c = rl.querySelector("li"), step = c ? c.offsetWidth + 24 : 280;
    rl.scrollBy({ left: d * step, behavior: rm ? "auto" : "smooth" });
  }
  window.iclearerReviewsNav = function () {
    if (!rl || !pv || !nx) return;
    if (!rvWired) {
      pv.onclick = function () { rvGo(-1); };
      nx.onclick = function () { rvGo(1); };
      rl.addEventListener("scroll", rvState, { passive: true });
      addEventListener("resize", rvState);
      rvWired = true;
    }
    rvState();
  };
  window.iclearerReviewsNav();

  /* Mobile menu */
  var mb = $("hd-menu"), dr = $("hd-drop");
  function menu(open) { dr.hidden = !open; mb.setAttribute("aria-expanded", open); }
  mb.onclick = function (e) { e.stopPropagation(); menu(dr.hidden); };
  dr.addEventListener("click", function (e) { if (e.target.closest("a")) menu(false); });
  document.addEventListener("click", function (e) { if (!dr.hidden && !dr.contains(e.target)) menu(false); });
  document.addEventListener("keydown", function (e) { if (e.key == "Escape" && !dr.hidden) { menu(false); mb.focus(); } });
  matchMedia("(min-width:901px)").addEventListener("change", function () { menu(false); });
})();
