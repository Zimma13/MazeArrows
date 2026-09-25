/* KinApps — UI interactions: language pill, search, mobile drawer,
   product modal, contact form. All blocks guard for missing elements. */
(function () {
  "use strict";
  const t = (k) => (window.KinappI18n && window.KinappI18n.t(k)) || k;

  /* ── Language pill ── */
  const lang = document.querySelector(".lang");
  if (lang) {
    const btn = lang.querySelector(".lang-btn");
    const FLAGS = { en: "🇺🇸", ru: "🇷🇺" };
    const CODES = { en: "EN", ru: "RU" };
    function render(code) {
      const f = btn.querySelector(".flag"), c = btn.querySelector(".code");
      if (f) f.textContent = FLAGS[code]; if (c) c.textContent = CODES[code];
      lang.querySelectorAll(".lang-menu button").forEach((b) => b.classList.toggle("is-active", b.dataset.lang === code));
    }
    function setOpen(o) { lang.dataset.open = o ? "true" : "false"; btn.setAttribute("aria-expanded", o ? "true" : "false"); }
    btn.addEventListener("click", (e) => { e.stopPropagation(); setOpen(lang.dataset.open !== "true"); });
    lang.querySelectorAll(".lang-menu button").forEach((b) =>
      b.addEventListener("click", () => { if (window.KinappI18n) window.KinappI18n.setLang(b.dataset.lang); setOpen(false); }));
    document.addEventListener("click", (e) => { if (!lang.contains(e.target)) setOpen(false); });
    if (window.KinappI18n) window.KinappI18n.onChange(render);
  }

  /* ── Search ── */
  const search = document.querySelector(".search");
  if (search) {
    const toggle = search.querySelector(".icon-btn");
    const input = search.querySelector("input");
    const results = search.querySelector(".search-results");
    const INDEX = [
      { key: "nav.products", href: "/pages/products.html" },
      { key: "app.icleanse.name", href: "/icleanse/" },
      { key: "app.fnt.name", href: "/fnt/" },
      { key: "app.total.name", href: "/total/" },
      { key: "app.arrowmaze.name", href: "/arrowmaze/" },
      { key: "nav.about", href: "/pages/about.html" },
      { key: "footer.terms", href: "/pages/terms.html" },
      { key: "footer.privacy", href: "/pages/privacy.html" },
    ];
    function esc(s) { return s.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])); }
    function render(q) {
      const list = INDEX.map((i) => ({ label: t(i.key), href: i.href }));
      const ql = q.trim().toLowerCase();
      const f = ql ? list.filter((i) => i.label.toLowerCase().includes(ql)) : list;
      results.innerHTML = f.length
        ? f.map((i) => `<a href="${i.href}">${esc(i.label)}</a>`).join("")
        : `<div class="search-empty">${esc(t("search.empty"))}</div>`;
    }
    toggle.addEventListener("click", (e) => {
      e.stopPropagation();
      search.classList.toggle("is-open");
      if (search.classList.contains("is-open")) { render(input.value); input.focus(); }
    });
    input.addEventListener("input", () => render(input.value));
    document.addEventListener("click", (e) => { if (!search.contains(e.target)) search.classList.remove("is-open"); });
  }

  /* ── Mobile drawer ── */
  const drawer = document.querySelector(".drawer");
  const backdrop = document.querySelector(".drawer-backdrop");
  function setDrawer(o) {
    if (drawer) drawer.classList.toggle("is-open", o);
    if (backdrop) backdrop.classList.toggle("is-open", o);
    document.body.style.overflow = o ? "hidden" : "";
  }
  const openBtn = document.querySelector(".menu-toggle.js-drawer");
  if (openBtn) openBtn.addEventListener("click", () => setDrawer(true));
  const closeBtn = document.querySelector(".drawer-close");
  if (closeBtn) closeBtn.addEventListener("click", () => setDrawer(false));
  if (backdrop) backdrop.addEventListener("click", () => setDrawer(false));
  if (drawer) drawer.querySelectorAll("a").forEach((a) => a.addEventListener("click", () => setDrawer(false)));

  /* ── Product modal ── */
  const APPS = {
    icleanse: { landing: "/icleanse/", store: null, thumb: "thumb-icleanse" },
    total: { landing: "/total/", store: null, thumb: "thumb-total" },
  };
  const modal = document.querySelector(".modal-backdrop");
  if (modal) {
    const box = modal.querySelector(".modal");
    function open(app, thumbHTML) {
      const meta = APPS[app];
      if (!meta) return;
      box.querySelector(".m-thumb").className = "m-thumb " + meta.thumb;
      box.querySelector(".m-thumb").innerHTML = thumbHTML;
      box.querySelector("h3").textContent = t("app." + app + ".name");
      box.querySelector(".m-cat").textContent = t("app." + app + ".cat");
      box.querySelector("p").textContent = t("app." + app + ".desc");
      let actions = `<a class="btn-primary" href="${meta.landing}">${t("modal.more")} &rarr;</a>`;
      if (meta.store) actions += `<a class="btn-ghost" href="${meta.store}" target="_blank" rel="noopener">${t("modal.appstore")}</a>`;
      box.querySelector(".m-actions").innerHTML = actions;
      modal.classList.add("is-open");
      document.body.style.overflow = "hidden";
    }
    function close() { modal.classList.remove("is-open"); document.body.style.overflow = ""; }
    document.querySelectorAll(".product-card[data-app]").forEach((card) =>
      card.addEventListener("click", () => open(card.dataset.app, card.querySelector(".product-thumb").innerHTML)));
    modal.addEventListener("click", (e) => { if (e.target === modal) close(); });
    modal.querySelector(".modal-close").addEventListener("click", close);
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") close(); });
  }

  /* ── Contact form (client-side only; no backend wired) ── */
  const form = document.querySelector(".contact-card");
  if (form) {
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const ok = form.querySelector(".form-success");
      if (ok) ok.style.display = "block";
      form.reset();
      setTimeout(() => { if (ok) ok.style.display = "none"; }, 4000);
    });
  }
})();
