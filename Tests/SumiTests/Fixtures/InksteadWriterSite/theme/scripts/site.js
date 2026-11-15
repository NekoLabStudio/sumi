document.addEventListener("plume:navigate", function () {
  document.querySelectorAll("[data-plume-on-click]").forEach(function (node) {
    node.dataset.plumeTracked = "true";
  });
  window.Plume.progress.done();
});
Plume.visit("/");
