export default {
  title: "Julia cheat sheet",
  // ordered from basic to advanced
  pages: [
    {
      name: "The language",
      open: true,
      pages: [
        {name: "Basics", path: "/basics"},
        {name: "Functions", path: "/functions"},
        {name: "Collections", path: "/collections"},
        {name: "Strings and files", path: "/strings"},
        {name: "Types", path: "/types"},
        {name: "Packages and environments", path: "/packages"}
      ]
    },
    {
      name: "Data and statistics",
      open: true,
      pages: [
        {name: "Linear algebra", path: "/linear-algebra"},
        {name: "Statistics", path: "/statistics"},
        {name: "Data handling", path: "/data"},
        {name: "Plotting", path: "/plotting"}
      ]
    },
    {
      name: "Inference",
      open: true,
      pages: [
        {name: "Optimization", path: "/optimization"},
        {name: "Automatic differentiation", path: "/autodiff"},
        {name: "Bayesian inference", path: "/bayes"}
      ]
    },
    {
      name: "Advanced",
      open: true,
      pages: [
        {name: "Performance", path: "/performance"},
        {name: "Parallel computing", path: "/parallel"},
        {name: "Metaprogramming", path: "/metaprogramming"}
      ]
    }
  ],
  header: `
<button id="theme-toggle" type="button" aria-label="Toggle light and dark mode" title="Toggle light/dark mode">
  <svg id="theme-toggle-sun" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
    <circle cx="8" cy="8" r="3.2" fill="currentColor"/>
    <g stroke="currentColor" stroke-width="1.3" stroke-linecap="round">
      <line x1="8" y1="0.8" x2="8" y2="2.4"/>
      <line x1="8" y1="13.6" x2="8" y2="15.2"/>
      <line x1="0.8" y1="8" x2="2.4" y2="8"/>
      <line x1="13.6" y1="8" x2="15.2" y2="8"/>
      <line x1="2.6" y1="2.6" x2="3.7" y2="3.7"/>
      <line x1="12.3" y1="12.3" x2="13.4" y2="13.4"/>
      <line x1="2.6" y1="13.4" x2="3.7" y2="12.3"/>
      <line x1="12.3" y1="3.7" x2="13.4" y2="2.6"/>
    </g>
  </svg>
  <svg id="theme-toggle-moon" width="16" height="16" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
    <path d="M13.5 9.5A6 6 0 1 1 6.5 2.5a5 5 0 0 0 7 7Z" fill="currentColor"/>
  </svg>
</button>
<script>
(function () {
  var root = document.documentElement;
  var stored = localStorage.getItem("mv-theme");
  if (stored === "light" || stored === "dark") root.setAttribute("data-theme", stored);
  document.addEventListener("click", function (event) {
    if (!event.target.closest("#theme-toggle")) return;
    var current = root.getAttribute("data-theme") ||
      (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light");
    var next = current === "dark" ? "light" : "dark";
    root.setAttribute("data-theme", next);
    localStorage.setItem("mv-theme", next);
  });
})();
</script>`,
  footer: `A Julia cheat sheet by <a href="https://mattiasvillani.com">Mattias Villani</a>`,
  sidebar: true,
  pager: false,
  root: "src",
  style: "styles.css"
};
