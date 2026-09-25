/* KinApps — runtime i18n (EN/RU). Pre-renders nothing server-side;
   the page ships with English defaults and swaps text on load / switch. */
(function () {
  const KEY = "kinapp.lang";
  const DEFAULT_LANG = "en";
  const SUPPORTED = ["en", "ru"];
  const ATTRS = ["placeholder", "content", "title", "aria-label", "alt"];
  let current = DEFAULT_LANG;
  let dict = {};
  const listeners = [];

  function detectLang() {
    const stored = localStorage.getItem(KEY);
    if (stored && SUPPORTED.includes(stored)) return stored;
    const nav = (navigator.languages && navigator.languages[0]) || navigator.language || "";
    const code = nav.toLowerCase().split("-")[0];
    return SUPPORTED.includes(code) ? code : DEFAULT_LANG;
  }

  async function loadDict(lang) {
    const res = await fetch(`/assets/i18n/${lang}.json`, { cache: "no-cache" });
    return res.json();
  }

  function apply(d) {
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const v = d[el.getAttribute("data-i18n")];
      if (v != null) el.textContent = v;
    });
    document.querySelectorAll("[data-i18n-html]").forEach((el) => {
      const v = d[el.getAttribute("data-i18n-html")];
      if (v != null) el.innerHTML = v;
    });
    ATTRS.forEach((a) => {
      document.querySelectorAll(`[data-i18n-attr-${a}]`).forEach((el) => {
        const v = d[el.getAttribute(`data-i18n-attr-${a}`)];
        if (v != null) el.setAttribute(a, v);
      });
    });
  }

  async function setLang(lang) {
    if (!SUPPORTED.includes(lang)) lang = DEFAULT_LANG;
    current = lang;
    localStorage.setItem(KEY, lang);
    dict = await loadDict(lang);
    document.documentElement.setAttribute("lang", lang);
    apply(dict);
    listeners.forEach((fn) => fn(lang, dict));
  }

  window.KinappI18n = {
    setLang,
    detectLang,
    getLang: () => current,
    t: (k) => dict[k],
    onChange: (fn) => { listeners.push(fn); if (Object.keys(dict).length) fn(current, dict); },
    SUPPORTED,
  };

  document.addEventListener("DOMContentLoaded", () => setLang(detectLang()));
})();
