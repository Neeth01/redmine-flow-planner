(function() {
  "use strict";

  function applyThemeMarkers() {
    if (!document.body) {
      return;
    }

    document.body.classList.add("theme-flow-horizon");
    document.body.classList.toggle("theme-flow-plugin-page", !!document.querySelector(".flow-shell"));
  }

  function syncMyPageColumns() {
    if (!document.body || !document.body.classList.contains("controller-my") || !document.body.classList.contains("action-page")) {
      return;
    }

    document.querySelectorAll(".splitcontent").forEach(function(grid) {
      var columns = Array.prototype.slice.call(
        grid.querySelectorAll(":scope > .splitcontentleft, :scope > .splitcontentright")
      );

      var visibleColumns = 0;

      columns.forEach(function(column) {
        var receiver = column.querySelector(".block-receiver");
        var hasBoxes = !!(receiver && receiver.querySelector(".mypage-box"));
        column.classList.toggle("flow-empty-column", !hasBoxes);
        if (hasBoxes) {
          visibleColumns += 1;
        }
      });

      grid.classList.toggle("flow-single-column", visibleColumns <= 1);
    });
  }

  function syncWelcomeDashboardLayout() {
    if (!document.body || !document.body.classList.contains("controller-welcome") || !document.body.classList.contains("action-index")) {
      return;
    }

    var content = document.getElementById("content");
    var dashboard = document.querySelector(".flow-home-dashboard");
    if (!content || !dashboard) {
      return;
    }

    var host = dashboard.closest(".splitcontentleft, .splitcontentright");
    if (dashboard.parentElement !== content) {
      var introNodes = Array.prototype.slice.call(content.children).filter(function(node) {
        return node.tagName === "H2" || node.tagName === "P";
      });
      var anchor = introNodes.length ? introNodes[introNodes.length - 1] : null;
      content.insertBefore(dashboard, anchor ? anchor.nextSibling : content.firstChild);
    }

    if (host) {
      host.classList.add("flow-home-host");
    }

    document.querySelectorAll("#content .splitcontent").forEach(function(container) {
      container.classList.add("flow-home-full-layout");

      var visibleColumns = 0;

      Array.prototype.slice.call(container.children).forEach(function(column) {
        var hasVisibleContent = !!column.textContent.trim() || !!column.querySelector("img, table, .news, .mypage-box, .flow-home-dashboard");
        column.classList.toggle("flow-empty-column", !hasVisibleContent);
        if (hasVisibleContent) {
          visibleColumns += 1;
        }
      });

      container.classList.toggle("flow-empty-column", visibleColumns === 0);
    });
  }

  function applyThemeEnhancements() {
    applyThemeMarkers();
    syncMyPageColumns();
    syncWelcomeDashboardLayout();
  }

  document.addEventListener("DOMContentLoaded", applyThemeEnhancements);
  document.addEventListener("turbo:load", applyThemeEnhancements);
})();
