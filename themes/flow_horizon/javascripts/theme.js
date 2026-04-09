(function() {
  "use strict";

  function applyThemeMarkers() {
    if (!document.body) {
      return;
    }

    document.body.classList.add("theme-flow-horizon");
    document.body.classList.toggle("theme-flow-plugin-page", !!document.querySelector(".flow-shell"));
  }

  document.addEventListener("DOMContentLoaded", applyThemeMarkers);
  document.addEventListener("turbo:load", applyThemeMarkers);
})();
