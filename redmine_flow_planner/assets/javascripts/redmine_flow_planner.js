(function() {
  "use strict";

  var DAY_IN_MS = 24 * 60 * 60 * 1000;

  function onReady(callback) {
    document.addEventListener("DOMContentLoaded", callback);
    document.addEventListener("turbo:load", callback);
  }

  function parseISODate(value) {
    if (!value) {
      return null;
    }

    var parts = value.split("-").map(Number);
    return new Date(parts[0], parts[1] - 1, parts[2]);
  }

  function formatISODate(date) {
    var year = String(date.getFullYear());
    var month = String(date.getMonth() + 1).padStart(2, "0");
    var day = String(date.getDate()).padStart(2, "0");
    return year + "-" + month + "-" + day;
  }

  function addDays(date, amount) {
    var copy = new Date(date.getTime());
    copy.setDate(copy.getDate() + amount);
    return copy;
  }

  function utcValue(date) {
    return Date.UTC(date.getFullYear(), date.getMonth(), date.getDate());
  }

  function diffDays(left, right) {
    return Math.round((utcValue(left) - utcValue(right)) / DAY_IN_MS);
  }

  function humanDate(date) {
    return new Intl.DateTimeFormat(document.documentElement.lang || undefined).format(date);
  }

  function humanRange(startDate, dueDate) {
    if (utcValue(startDate) === utcValue(dueDate)) {
      return humanDate(startDate);
    }

    return humanDate(startDate) + " -> " + humanDate(dueDate);
  }

  function humanHours(value) {
    var amount = Number(value || 0);

    if (!amount || amount < 0) {
      return "0h";
    }

    if (Math.round(amount) === amount) {
      return String(amount) + "h";
    }

    return String(Math.round(amount * 10) / 10) + "h";
  }

  function normalizeText(value) {
    return String(value || "").toLowerCase().trim();
  }

  function parsePayload(value) {
    if (!value) {
      return {};
    }

    try {
      return JSON.parse(value);
    } catch (error) {
      return {};
    }
  }

  function csrfToken() {
    var token = document.querySelector("meta[name='csrf-token']");
    return token ? token.getAttribute("content") : null;
  }

  function storage() {
    try {
      return window.localStorage;
    } catch (error) {
      return null;
    }
  }

  function readStoredState(key) {
    var store = storage();

    if (!store) {
      return null;
    }

    try {
      return JSON.parse(store.getItem(key) || "null");
    } catch (error) {
      return null;
    }
  }

  function writeStoredState(key, value) {
    var store = storage();

    if (!store) {
      return;
    }

    try {
      if (value) {
        store.setItem(key, JSON.stringify(value));
      } else {
        store.removeItem(key);
      }
    } catch (error) {
      // Ignore storage quota and privacy errors.
    }
  }

  function requestJSON(url, payload, method) {
    var headers = {
      "Accept": "application/json",
      "Content-Type": "application/json"
    };
    var token = csrfToken();

    if (token) {
      headers["X-CSRF-Token"] = token;
    }

    return fetch(url, {
      method: method || "PATCH",
      credentials: "same-origin",
      headers: headers,
      body: JSON.stringify(payload)
    }).then(function(response) {
      return response.text().then(function(text) {
        var data = {};

        if (text) {
          try {
            data = JSON.parse(text);
          } catch (error) {
            data = {};
          }
        }

        if (!response.ok) {
          var message = data.errors && data.errors.length ? data.errors.join(", ") : null;
          throw new Error(message || "Request failed");
        }

        return data;
      });
    });
  }

  function showMessage(shell, kind, text) {
    if (!shell) {
      return;
    }

    var message = shell.querySelector("[data-flow-message]");
    if (!message) {
      return;
    }

    message.hidden = false;
    message.textContent = text;
    message.classList.remove("is-error", "is-success");
    message.classList.add(kind === "error" ? "is-error" : "is-success");

    clearTimeout(message._timeout);
    message._timeout = setTimeout(function() {
      message.hidden = true;
    }, 4000);
  }

  function buildIssuePayload(form) {
    var payload = { issue: {} };

    new FormData(form).forEach(function(value, key) {
      var match = key.match(/^issue\[(.+)\]$/);
      if (match) {
        payload.issue[match[1]] = value;
      }
    });

    return payload;
  }

  function escapeHTML(value) {
    return String(value || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");
  }

  function extractIssueId(value) {
    var match = String(value || "").match(/#?(\d+)/);
    return match ? String(match[1]) : "";
  }

  function applyColorMode() {
    // Color grouping was removed to keep the views lighter and faster.
  }

  function resolveFullscreenTarget(button) {
    var shell = button.closest(".flow-shell");
    var selector = button.getAttribute("data-flow-fullscreen-target");
    if (!shell || !selector) {
      return null;
    }

    return shell.querySelector(selector);
  }

  function toggleFullscreen(target) {
    if (!target || !document.fullscreenEnabled) {
      return;
    }

    if (document.fullscreenElement === target) {
      document.exitFullscreen();
    } else {
      try {
        target.requestFullscreen();
      } catch (error) {
        // ignore unsupported fullscreen requests
      }
    }
  }

  function initFlowShells() {
    document.querySelectorAll(".flow-shell").forEach(function(shell) {
      if (shell.dataset.flowShellBound === "true") {
        return;
      }

      shell.dataset.flowShellBound = "true";

      shell.querySelectorAll("[data-flow-fullscreen-toggle='true']").forEach(function(button) {
        button.addEventListener("click", function() {
          var target = resolveFullscreenTarget(button);
          if (target) {
            target.classList.add("flow-fullscreenable");
            toggleFullscreen(target);
          }
        });
      });
    });
  }

  function fallbackError(shell, error) {
    if (error && error.message && error.message !== "Request failed") {
      return error.message;
    }

    return shell.dataset.flowFailureMessage || shell.dataset.flowErrorMessage || "Request failed";
  }

  function boardFilterState(shell) {
    return {
      search: normalizeText(shell.querySelector("[data-flow-filter-search='true']") && shell.querySelector("[data-flow-filter-search='true']").value),
      trackerId: String(shell.querySelector("[data-flow-filter-tracker='true']") && shell.querySelector("[data-flow-filter-tracker='true']").value || ""),
      assigneeId: String(shell.querySelector("[data-flow-filter-assignee='true']") && shell.querySelector("[data-flow-filter-assignee='true']").value || ""),
      groupBy: String(shell.querySelector("[data-flow-board-grouping='true']") && shell.querySelector("[data-flow-board-grouping='true']").value || ""),
      overdueOnly: !!(shell.querySelector("[data-flow-filter-overdue='true']") && shell.querySelector("[data-flow-filter-overdue='true']").checked),
      unassignedOnly: !!(shell.querySelector("[data-flow-filter-unassigned='true']") && shell.querySelector("[data-flow-filter-unassigned='true']").checked),
      closedOnly: !!(shell.querySelector("[data-flow-filter-closed='true']") && shell.querySelector("[data-flow-filter-closed='true']").checked),
      hideEmpty: !!(shell.querySelector("[data-flow-hide-empty='true']") && shell.querySelector("[data-flow-hide-empty='true']").checked)
    };
  }

  function boardFilterStorageKey(shell) {
    return "redmine_flow_planner:board_filters:" + ((shell && shell.dataset.flowStorageKey) || window.location.pathname);
  }

  function restoreBoardFilters(shell) {
    var state = readStoredState(boardFilterStorageKey(shell));

    if (!state) {
      return;
    }

    var search = shell.querySelector("[data-flow-filter-search='true']");
    var tracker = shell.querySelector("[data-flow-filter-tracker='true']");
    var assignee = shell.querySelector("[data-flow-filter-assignee='true']");
    var grouping = shell.querySelector("[data-flow-board-grouping='true']");
    var overdue = shell.querySelector("[data-flow-filter-overdue='true']");
    var unassigned = shell.querySelector("[data-flow-filter-unassigned='true']");
    var closed = shell.querySelector("[data-flow-filter-closed='true']");
    var hideEmpty = shell.querySelector("[data-flow-hide-empty='true']");

    if (search) {
      search.value = state.search || "";
    }
    if (tracker) {
      tracker.value = state.trackerId || "";
    }
    if (assignee) {
      assignee.value = state.assigneeId || "";
    }
    if (grouping) {
      grouping.value = state.groupBy || "";
    }
    if (overdue) {
      overdue.checked = !!state.overdueOnly;
    }
    if (unassigned) {
      unassigned.checked = !!state.unassignedOnly;
    }
    if (closed) {
      closed.checked = !!state.closedOnly;
    }
    if (hideEmpty) {
      hideEmpty.checked = !!state.hideEmpty;
    }
  }

  function persistBoardFilters(shell) {
    writeStoredState(boardFilterStorageKey(shell), boardFilterState(shell));
  }

  function matchesBoardFilters(card, state) {
    if (state.search && card.dataset.searchText.indexOf(state.search) === -1) {
      return false;
    }

    if (state.trackerId && String(card.dataset.trackerId || "") !== state.trackerId) {
      return false;
    }

    if (state.assigneeId && String(card.dataset.assigneeId || "") !== state.assigneeId) {
      return false;
    }

    if (state.overdueOnly && card.dataset.isOverdue !== "true") {
      return false;
    }

    if (state.unassignedOnly && card.dataset.isUnassigned !== "true") {
      return false;
    }

    if (state.closedOnly && card.dataset.isClosed !== "true") {
      return false;
    }

    return true;
  }

  function updateBoardColumns(board, state) {
    board.querySelectorAll("[data-agile-column='true']").forEach(function(column) {
      var counter = column.querySelector("[data-agile-count='true']");
      var visibleCards = Array.prototype.filter.call(
        column.querySelectorAll("[data-agile-card='true']"),
        function(card) { return !card.classList.contains("is-filtered-out"); }
      );
      var visibleCount = visibleCards.length;
      var limit = Number(column.dataset.agileWipLimit || 0);

      if (counter) {
        counter.textContent = String(visibleCount);
      }

      column.classList.toggle("is-locally-hidden", state.hideEmpty && visibleCount === 0);
      column.classList.remove("is-wip-ok", "is-wip-warning", "is-wip-alert");

      if (limit > 0) {
        if (visibleCount > limit) {
          column.classList.add("is-wip-alert");
        } else if (visibleCount === limit) {
          column.classList.add("is-wip-warning");
        } else {
          column.classList.add("is-wip-ok");
        }
      }
    });
  }

  function boardGroupingValue(card, state, shell) {
    var noneLabel = (shell && shell.dataset.flowBoardEmptyGroup) || "None";

    if (state.groupBy === "assignee") {
      return card.dataset.assigneeName || noneLabel;
    }
    if (state.groupBy === "tracker") {
      return card.dataset.trackerName || noneLabel;
    }
    if (state.groupBy === "priority") {
      return card.dataset.priorityName || noneLabel;
    }
    if (state.groupBy === "version") {
      return card.dataset.versionName || noneLabel;
    }

    return "";
  }

  function renderBoardGrouping(board, state) {
    board.querySelectorAll("[data-agile-list='true']").forEach(function(list) {
      var cards = Array.prototype.slice.call(list.querySelectorAll("[data-agile-card='true']"));
      var visibleCards;
      var hiddenCards;
      var groups;
      var labels;
      var fragment;

      cards.forEach(function(card) {
        list.appendChild(card);
      });

      Array.prototype.slice.call(list.querySelectorAll("[data-flow-card-group='true']")).forEach(function(group) {
        group.remove();
      });

      if (!state.groupBy) {
        return;
      }

      visibleCards = cards.filter(function(card) {
        return !card.classList.contains("is-filtered-out");
      });
      hiddenCards = cards.filter(function(card) {
        return card.classList.contains("is-filtered-out");
      });
      groups = {};
      labels = [];
      fragment = document.createDocumentFragment();

      visibleCards.forEach(function(card) {
        var label = boardGroupingValue(card, state, board.closest(".flow-shell"));
        if (!groups[label]) {
          groups[label] = [];
          labels.push(label);
        }
        groups[label].push(card);
      });

      labels.sort(function(left, right) {
        return left.localeCompare(right);
      }).forEach(function(label) {
        var section = document.createElement("section");
        var title = document.createElement("div");
        var count = document.createElement("span");

        section.className = "flow-card-group";
        section.setAttribute("data-flow-card-group", "true");
        title.className = "flow-card-group-title";
        title.innerHTML = "<span>" + escapeHTML(label) + "</span>";
        count.className = "flow-card-group-count";
        count.textContent = String(groups[label].length);
        title.appendChild(count);
        section.appendChild(title);

        groups[label].forEach(function(card) {
          section.appendChild(card);
        });

        fragment.appendChild(section);
      });

      hiddenCards.forEach(function(card) {
        fragment.appendChild(card);
      });

      list.appendChild(fragment);
    });
  }

  function applyBoardFilters(board) {
    var shell = board.closest(".flow-shell");
    var state = boardFilterState(shell);

    board.querySelectorAll("[data-agile-card='true']").forEach(function(card) {
      card.classList.toggle("is-filtered-out", !matchesBoardFilters(card, state));
    });

    renderBoardGrouping(board, state);
    updateBoardColumns(board, state);
  }

  function updateAgileCardLink(card, issue) {
    var titleNode = card.querySelector("[data-agile-inline-subject='true']");
    var href = card.dataset.issueUrl || "#";
    if (!titleNode || !issue.subject) {
      return;
    }

    titleNode.innerHTML = "<a href=\"" + escapeHTML(href) + "\" title=\"" + escapeHTML(issue.subject) + "\">" +
      escapeHTML(issue.subject) + "</a>";
  }

  function updateCardFromPayload(card, issue) {
    if (!card || !issue) {
      return;
    }

    var shell = card.closest(".flow-shell");
    var statusNode = card.querySelector(".js-agile-status");
    var assigneeNode = card.querySelector(".js-agile-assignee");
    var doneNode = card.querySelector(".js-agile-done");
    var dueNode = card.querySelector(".js-agile-due");
    var progressFill = card.querySelector(".flow-card-progress-fill");
    var estimatedNode = card.querySelector(".js-agile-estimated");
    var spentNode = card.querySelector(".js-agile-spent");

    if (statusNode && issue.status_name) {
      statusNode.textContent = issue.status_name;
    }

    if (assigneeNode && issue.assigned_to_name !== undefined) {
      assigneeNode.textContent = issue.assigned_to_name || (shell && shell.dataset.flowUnassignedLabel) || "";
    }

    if (doneNode && issue.done_ratio !== undefined) {
      doneNode.textContent = String(issue.done_ratio) + "%";
      card.dataset.doneRatio = String(issue.done_ratio);
    }
    if (progressFill && issue.done_ratio !== undefined) {
      progressFill.style.width = String(Math.max(0, Math.min(100, Number(issue.done_ratio || 0)))) + "%";
    }

    if (dueNode && issue.due_label !== undefined) {
      dueNode.textContent = issue.due_label || "";
    }

    if (issue.subject !== undefined) {
      card.dataset.subject = issue.subject || "";
      updateAgileCardLink(card, issue);
    }

    if (issue.status_id !== undefined) {
      card.dataset.statusId = issue.status_id || "";
      card.dataset.statusName = issue.status_name || "";
      card.dataset.toneStatus = issue.status_name || "";
    }

    if (issue.tracker_id !== undefined) {
      card.dataset.trackerId = issue.tracker_id || "";
      card.dataset.trackerName = issue.tracker_name || "";
      card.dataset.toneTracker = issue.tracker_name || "";
    }

    if (issue.priority_id !== undefined) {
      card.dataset.priorityId = issue.priority_id || "";
      card.dataset.priorityName = issue.priority_name || "";
      card.dataset.tonePriority = issue.priority_name || "";
    }

    if (issue.assigned_to_id !== undefined) {
      card.dataset.assigneeId = issue.assigned_to_id || "";
      card.dataset.assigneeName = issue.assigned_to_name || "";
      card.dataset.toneAssignee = issue.assigned_to_name || "";
      card.dataset.isUnassigned = issue.assigned_to_id ? "false" : "true";
    }

    if (issue.fixed_version_id !== undefined) {
      card.dataset.versionId = issue.fixed_version_id || "";
      card.dataset.versionName = issue.fixed_version_name || "";
      card.dataset.toneVersion = issue.fixed_version_name || "";
    }

    if (issue.due_date !== undefined) {
      card.dataset.dueDate = issue.due_date || "";
    }

    if (issue.overdue !== undefined) {
      card.dataset.isOverdue = issue.overdue ? "true" : "false";
      card.classList.toggle("is-overdue", !!issue.overdue);
    }

    if (issue.closed !== undefined) {
      card.dataset.isClosed = issue.closed ? "true" : "false";
      card.classList.toggle("is-closed", !!issue.closed);
    }

    if (issue.estimated_hours !== undefined) {
      card.dataset.estimatedHours = String(issue.estimated_hours || 0);
      if (estimatedNode) {
        estimatedNode.textContent = humanHours(issue.estimated_hours || 0);
      }
    }

    if (issue.spent_hours !== undefined) {
      card.dataset.spentHours = String(issue.spent_hours || 0);
      if (spentNode) {
        spentNode.textContent = humanHours(issue.spent_hours || 0);
      }
    }

    card.dataset.searchText = normalizeText(card.textContent);
  }

  function beginAgileInlineEdit(card, shell, board, fieldName) {
    var node;
    var input;
    var originalHTML;

    if (card.dataset.draggable !== "true" || card.dataset.saving === "true") {
      return;
    }

    if (card.querySelector(".flow-inline-editor")) {
      return;
    }

    if (fieldName === "subject") {
      node = card.querySelector("[data-agile-inline-subject='true']");
    } else if (fieldName === "due_date") {
      node = card.querySelector("[data-agile-inline-due='true']");
    } else {
      node = card.querySelector("[data-agile-inline-done='true']");
    }

    if (!node) {
      return;
    }

    originalHTML = node.innerHTML;
    input = document.createElement("input");
    input.className = "flow-inline-editor";

    if (fieldName === "subject") {
      input.type = "text";
      input.value = card.dataset.subject || "";
    } else if (fieldName === "due_date") {
      input.type = "date";
      input.value = card.dataset.dueDate || "";
    } else {
      input.type = "number";
      input.min = "0";
      input.max = "100";
      input.step = "1";
      input.value = String(card.dataset.doneRatio || card.querySelector(".js-agile-done").textContent || "").replace(/[^0-9]/g, "");
    }

    function cleanup(restore) {
      if (restore) {
        node.innerHTML = originalHTML;
      } else if (input.parentNode) {
        input.parentNode.removeChild(input);
      }
    }

    function doSave() {
      var payload = { issue: {} };
      var value = input.value;

      if (fieldName === "subject") {
        value = value.trim();
        if (!value) {
          cleanup(true);
          return;
        }
      }

      if (fieldName === "done_ratio") {
        value = Math.max(0, Math.min(100, Number(value || 0)));
      }

      payload.issue[fieldName] = value;
      card.dataset.saving = "true";

      requestJSON(card.dataset.updateUrl, payload).then(function(data) {
        updateCardFromPayload(card, data.issue);
        applyBoardFilters(board);
        applyColorMode(shell);
        showMessage(shell, "success", data.message || shell.dataset.flowSavedMessage || "Saved");
      }).catch(function(error) {
        cleanup(true);
        showMessage(shell, "error", fallbackError(shell, error));
      }).finally(function() {
        delete card.dataset.saving;
      });
    }

    input.addEventListener("keydown", function(event) {
      if (event.key === "Enter") {
        event.preventDefault();
        doSave();
      } else if (event.key === "Escape") {
        cleanup(true);
      }
    });

    input.addEventListener("blur", function() {
      setTimeout(function() {
        if (document.activeElement !== input) {
          doSave();
        }
      }, 100);
    });

    node.innerHTML = "";
    node.appendChild(input);
    input.focus();
    input.select();
  }

  function bindAgileCard(board, shell, card) {
    if (!card || card.dataset.agileBound === "true") {
      return;
    }

    card.dataset.agileBound = "true";

    if (card.dataset.draggable === "true") {
      card.addEventListener("dragstart", function(event) {
        board._draggingCard = card;
        card.classList.add("is-dragging");

        if (event.dataTransfer) {
          event.dataTransfer.effectAllowed = "move";
          event.dataTransfer.setData("text/plain", card.dataset.issueId || "");
        }
      });

      card.addEventListener("dragend", function() {
        card.classList.remove("is-dragging");
        board.querySelectorAll(".is-drop-target").forEach(function(node) {
          node.classList.remove("is-drop-target");
        });
        board._draggingCard = null;
      });

      var subject = card.querySelector("[data-agile-inline-subject='true']");
      var due = card.querySelector("[data-agile-inline-due='true']");
      var done = card.querySelector("[data-agile-inline-done='true']");

      if (subject) {
        subject.addEventListener("dblclick", function(event) {
          event.preventDefault();
          beginAgileInlineEdit(card, shell, board, "subject");
        });
      }
      if (due) {
        due.addEventListener("dblclick", function(event) {
          event.preventDefault();
          beginAgileInlineEdit(card, shell, board, "due_date");
        });
      }
      if (done) {
        done.addEventListener("dblclick", function(event) {
          event.preventDefault();
          beginAgileInlineEdit(card, shell, board, "done_ratio");
        });
      }
    }
  }

  function initQuickActions(shell, board) {
    if (shell.dataset.quickActionsBound === "true") {
      return;
    }
    shell.dataset.quickActionsBound = "true";

    shell.addEventListener("click", function(event) {
      var button = event.target.closest("[data-flow-quick-update='true']");
      if (!button) {
        return;
      }

      var card = button.closest("[data-agile-card='true']");
      var payload = parsePayload(button.getAttribute("data-update-payload"));
      var url = button.getAttribute("data-update-url");

      if (!card || !url || button.disabled) {
        return;
      }

      button.disabled = true;
      card.dataset.saving = "true";

      requestJSON(url, payload).then(function(data) {
        updateCardFromPayload(card, data.issue);
        applyBoardFilters(board);
        applyColorMode(shell);
        showMessage(shell, "success", data.message || shell.dataset.flowSavedMessage || "Saved");
      }).catch(function(error) {
        showMessage(shell, "error", fallbackError(shell, error));
      }).finally(function() {
        delete card.dataset.saving;
        button.disabled = false;
      });
    });
  }

  function initAgileBoards() {
    document.querySelectorAll("[data-agile-board='true']").forEach(function(board) {
      if (board.dataset.bound === "true") {
        return;
      }
      board.dataset.bound = "true";

      var shell = board.closest(".flow-shell");

      restoreBoardFilters(shell);

      board.querySelectorAll("[data-agile-card='true']").forEach(function(card) {
        bindAgileCard(board, shell, card);
      });

      board.querySelectorAll("[data-agile-column='true']").forEach(function(column) {
        column.addEventListener("dragover", function(event) {
          if (!board._draggingCard || board._draggingCard.dataset.saving === "true") {
            return;
          }

          event.preventDefault();
          column.classList.add("is-drop-target");
        });

        column.addEventListener("dragleave", function() {
          column.classList.remove("is-drop-target");
        });

        column.addEventListener("drop", function(event) {
          if (!board._draggingCard || board._draggingCard.dataset.saving === "true") {
            return;
          }

          event.preventDefault();
          column.classList.remove("is-drop-target");

          var targetStatusId = column.dataset.statusId;
          var sourceColumn = board._draggingCard.closest("[data-agile-column='true']");
          var card = board._draggingCard;

          if (!targetStatusId || !card.dataset.updateUrl || sourceColumn === column) {
            return;
          }

          card.dataset.saving = "true";

          requestJSON(card.dataset.updateUrl, {
            issue: { status_id: targetStatusId }
          }).then(function(data) {
            var targetList = column.querySelector("[data-agile-list='true']");

            if (targetList) {
              targetList.appendChild(card);
            }

            updateCardFromPayload(card, data.issue);
            applyBoardFilters(board);
            applyColorMode(shell);
            showMessage(shell, "success", data.message || shell.dataset.flowSavedMessage || "Saved");
          }).catch(function(error) {
            applyBoardFilters(board);
            showMessage(shell, "error", fallbackError(shell, error));
          }).finally(function() {
            delete card.dataset.saving;
          });
        });

        var toggle = column.querySelector("[data-agile-add-toggle='true']");
        var panel = column.querySelector("[data-agile-create-panel='true']");
        var form = column.querySelector("[data-agile-create-form='true']");
        var cancel = column.querySelector("[data-agile-add-cancel='true']");

        if (toggle && panel) {
          toggle.addEventListener("click", function() {
            panel.hidden = !panel.hidden;
            if (!panel.hidden) {
              var subjectInput = panel.querySelector("[data-agile-create-subject='true']");
              if (subjectInput) {
                subjectInput.focus();
              }
            }
          });
        }

        if (cancel && panel && form) {
          cancel.addEventListener("click", function() {
            form.reset();
            panel.hidden = true;
          });
        }

        if (form) {
          form.addEventListener("submit", function(event) {
            event.preventDefault();

            requestJSON(form.action, buildIssuePayload(form), "POST").then(function(data) {
              var targetList = column.querySelector("[data-agile-list='true']");
              var wrapper = document.createElement("div");
              wrapper.innerHTML = String(data.html || "").trim();
              var card = wrapper.firstElementChild;

              if (targetList && card) {
                targetList.prepend(card);
                bindAgileCard(board, shell, card);
                form.reset();
                panel.hidden = true;
                applyBoardFilters(board);
                applyColorMode(shell);
              }

              showMessage(shell, "success", data.message || shell.dataset.flowSavedMessage || "Saved");
            }).catch(function(error) {
              showMessage(shell, "error", fallbackError(shell, error));
            });
          });
        }
      });

      shell.querySelectorAll("[data-flow-board-filters='true'] input, [data-flow-board-filters='true'] select").forEach(function(input) {
        input.addEventListener("input", function() {
          persistBoardFilters(shell);
          applyBoardFilters(board);
        });
        input.addEventListener("change", function() {
          persistBoardFilters(shell);
          applyBoardFilters(board);
        });
      });

      var resetButton = shell.querySelector("[data-flow-board-filters='true'] [data-flow-reset-filters='true']");
      if (resetButton) {
        resetButton.addEventListener("click", function() {
          shell.querySelectorAll("[data-flow-board-filters='true'] input[type='search']").forEach(function(input) {
            input.value = "";
          });
          shell.querySelectorAll("[data-flow-board-filters='true'] select").forEach(function(select) {
            select.value = "";
          });
          shell.querySelectorAll("[data-flow-board-filters='true'] input[type='checkbox']").forEach(function(input) {
            input.checked = false;
          });
          persistBoardFilters(shell);
          applyBoardFilters(board);
        });
      }

      initQuickActions(shell, board);
      applyBoardFilters(board);
    });
  }

  function clampDelta(state, delta) {
    var min;
    var max;

    if (state.mode === "move") {
      min = diffDays(state.windowStart, state.startDate);
      max = diffDays(state.windowEnd, state.dueDate);
    } else if (state.mode === "start") {
      min = diffDays(state.windowStart, state.startDate);
      max = diffDays(state.dueDate, state.startDate);
    } else {
      min = diffDays(state.startDate, state.dueDate);
      max = diffDays(state.windowEnd, state.dueDate);
    }

    return Math.min(Math.max(delta, min), max);
  }

  function computeDates(state) {
    var delta = state.deltaDays;

    if (state.mode === "move") {
      return {
        startDate: addDays(state.startDate, delta),
        dueDate: addDays(state.dueDate, delta)
      };
    }

    if (state.mode === "start") {
      return {
        startDate: addDays(state.startDate, delta),
        dueDate: state.dueDate
      };
    }

    return {
      startDate: state.startDate,
      dueDate: addDays(state.dueDate, delta)
    };
  }

  function renderBar(bar, windowStart, dayWidth, startDate, dueDate) {
    var offset = diffDays(startDate, windowStart) * dayWidth;
    var width = (diffDays(dueDate, startDate) + 1) * dayWidth;

    bar.style.setProperty("--bar-offset", String(offset) + "px");
    bar.style.setProperty("--bar-width", String(Math.max(width, dayWidth)) + "px");
  }

  function renderBaseline(baseline, windowStart, dayWidth, startDate, dueDate) {
    if (!baseline) {
      return;
    }

    renderBar(baseline, windowStart, dayWidth, startDate, dueDate);
  }

  function syncDates(state, startDate, dueDate) {
    state.bar.dataset.startDate = formatISODate(startDate);
    state.bar.dataset.dueDate = formatISODate(dueDate);
    renderBar(state.bar, state.windowStart, state.dayWidth, startDate, dueDate);

    if (state.datesNode) {
      state.datesNode.textContent = humanRange(startDate, dueDate);
    }

    if (state.row) {
      state.row.dataset.isOverdue = utcValue(dueDate) < utcValue(new Date()) ? "true" : "false";
    }
  }

  function updatePlanningBarFromPayload(bar, issue, root) {
    if (!bar || !issue) {
      return;
    }

    var shell = bar.closest(".flow-shell");
    var row = bar.closest("[data-planning-row='true']");
    var datesNode = row && row.querySelector(".js-gantt-dates");
    var assigneeNode = row && row.querySelector(".planning-grid-cell--assignee");
    var progressNode = row && row.querySelector(".planning-grid-cell--progress");
    var titleLink = row && row.querySelector(".planning-title-line a");
    var nextDue;

    if (issue.subject !== undefined && titleLink) {
      titleLink.textContent = "#" + String(issue.id || bar.dataset.issueId || "") + " " + issue.subject;
      titleLink.title = issue.subject;
      bar.dataset.subject = issue.subject || "";
    }

    if (issue.start_date) {
      bar.dataset.startDate = issue.start_date;
    }

    if (issue.due_date) {
      bar.dataset.dueDate = issue.due_date;
    }

    if (issue.assigned_to_id !== undefined) {
      bar.dataset.assignedToId = issue.assigned_to_id || "";
      if (row) {
        row.dataset.assigneeId = issue.assigned_to_id || "";
        row.dataset.isUnassigned = issue.assigned_to_id ? "false" : "true";
      }
    }

    if (issue.assigned_to_name !== undefined) {
      bar.dataset.toneAssignee = issue.assigned_to_name || "";
      if (assigneeNode) {
        assigneeNode.textContent = issue.assigned_to_name || (shell && shell.dataset.flowUnassignedLabel) || "";
      }
    }

    if (issue.fixed_version_id !== undefined) {
      bar.dataset.fixedVersionId = issue.fixed_version_id || "";
    }

    if (issue.fixed_version_name !== undefined) {
      bar.dataset.toneVersion = issue.fixed_version_name || "";
    }

    if (issue.tracker_id !== undefined) {
      bar.dataset.trackerId = issue.tracker_id || "";
    }
    if (issue.tracker_name !== undefined) {
      bar.dataset.trackerName = issue.tracker_name || "";
      bar.dataset.toneTracker = issue.tracker_name || "";
    }
    if (issue.priority_id !== undefined) {
      bar.dataset.priorityId = issue.priority_id || "";
    }
    if (issue.priority_name !== undefined) {
      bar.dataset.priorityName = issue.priority_name || "";
      bar.dataset.tonePriority = issue.priority_name || "";
    }
    if (issue.status_name !== undefined) {
      bar.dataset.statusName = issue.status_name || "";
      bar.dataset.toneStatus = issue.status_name || "";
    }

    if (issue.done_ratio !== undefined) {
      bar.dataset.doneRatio = String(issue.done_ratio);
      bar.style.setProperty("--bar-progress", String(issue.done_ratio) + "%");
      var label = bar.querySelector(".planning-bar-label");
      if (label) {
        label.textContent = String(issue.done_ratio) + "%";
      }
      if (progressNode) {
        progressNode.textContent = String(issue.done_ratio) + "%";
      }
    }

    if (issue.schedule_label && datesNode) {
      datesNode.textContent = issue.schedule_label;
    }

    if (issue.critical !== undefined) {
      bar.dataset.critical = issue.critical ? "true" : "";
    }

    if (issue.closed !== undefined) {
      bar.classList.toggle("is-closed", !!issue.closed);
      if (row) {
        row.dataset.isClosed = issue.closed ? "true" : "false";
      }
    }

    if (bar.dataset.startDate && bar.dataset.dueDate) {
      nextDue = parseISODate(bar.dataset.dueDate);

      renderBar(
        bar,
        parseISODate(root.dataset.windowStart),
        Number(root.dataset.dayWidth || 28),
        parseISODate(bar.dataset.startDate),
        nextDue
      );

      if (row && nextDue) {
        row.dataset.isOverdue = nextDue && utcValue(nextDue) < utcValue(new Date()) && row.dataset.isClosed !== "true" ? "true" : "false";
      }
    }

    if (row) {
      row.dataset.searchText = normalizeText(row.textContent);
    }
  }

  function planningFilterState(shell) {
    return {
      search: normalizeText(shell.querySelector("[data-flow-filter-search='true']") && shell.querySelector("[data-flow-filter-search='true']").value),
      trackerId: String(shell.querySelector("[data-flow-filter-tracker='true']") && shell.querySelector("[data-flow-filter-tracker='true']").value || ""),
      assigneeId: String(shell.querySelector("[data-flow-filter-assignee='true']") && shell.querySelector("[data-flow-filter-assignee='true']").value || ""),
      overdueOnly: !!(shell.querySelector("[data-flow-filter-overdue='true']") && shell.querySelector("[data-flow-filter-overdue='true']").checked),
      unassignedOnly: !!(shell.querySelector("[data-flow-filter-unassigned='true']") && shell.querySelector("[data-flow-filter-unassigned='true']").checked),
      closedOnly: !!(shell.querySelector("[data-flow-filter-closed='true']") && shell.querySelector("[data-flow-filter-closed='true']").checked),
      showRelations: !(shell.querySelector("[data-flow-toggle-relations='true']") && !shell.querySelector("[data-flow-toggle-relations='true']").checked),
      showBaselines: !!(shell.querySelector("[data-flow-toggle-baselines='true']") && shell.querySelector("[data-flow-toggle-baselines='true']").checked)
    };
  }

  function planningFilterStorageKey(shell) {
    return "redmine_flow_planner:planning_filters:" + ((shell && shell.dataset.flowStorageKey) || window.location.pathname);
  }

  function restorePlanningFilters(shell) {
    var state = readStoredState(planningFilterStorageKey(shell));

    if (!state) {
      return;
    }

    var search = shell.querySelector("[data-flow-filter-search='true']");
    var tracker = shell.querySelector("[data-flow-filter-tracker='true']");
    var assignee = shell.querySelector("[data-flow-filter-assignee='true']");
    var overdue = shell.querySelector("[data-flow-filter-overdue='true']");
    var unassigned = shell.querySelector("[data-flow-filter-unassigned='true']");
    var closed = shell.querySelector("[data-flow-filter-closed='true']");
    var relations = shell.querySelector("[data-flow-toggle-relations='true']");
    var baselines = shell.querySelector("[data-flow-toggle-baselines='true']");

    if (search) {
      search.value = state.search || "";
    }
    if (tracker) {
      tracker.value = state.trackerId || "";
    }
    if (assignee) {
      assignee.value = state.assigneeId || "";
    }
    if (overdue) {
      overdue.checked = !!state.overdueOnly;
    }
    if (unassigned) {
      unassigned.checked = !!state.unassignedOnly;
    }
    if (closed) {
      closed.checked = !!state.closedOnly;
    }
    if (relations) {
      relations.checked = state.showRelations !== false;
    }
    if (baselines) {
      baselines.checked = !!state.showBaselines;
    }
  }

  function persistPlanningFilters(shell) {
    writeStoredState(planningFilterStorageKey(shell), planningFilterState(shell));
  }

  function matchesPlanningFilters(row, state) {
    if (state.search && row.dataset.searchText.indexOf(state.search) === -1) {
      return false;
    }

    if (state.trackerId && String(row.dataset.trackerId || "") !== state.trackerId) {
      return false;
    }

    if (state.assigneeId && String(row.dataset.assigneeId || "") !== state.assigneeId) {
      return false;
    }

    if (state.overdueOnly && row.dataset.isOverdue !== "true") {
      return false;
    }

    if (state.unassignedOnly && row.dataset.isUnassigned !== "true") {
      return false;
    }

    if (state.closedOnly && row.dataset.isClosed !== "true") {
      return false;
    }

    return true;
  }

  function planningRelationColor(type) {
    if (type === "blocks") {
      return "#b42318";
    }
    if (type === "relates") {
      return "#667085";
    }

    return "#0f5f9c";
  }

  function planningRelationDash(type) {
    return type === "relates" ? "6 4" : "";
  }

  function visiblePlanningBars(root) {
    var bars = {};

    root.querySelectorAll("[data-gantt-bar='true']").forEach(function(bar) {
      var row = bar.closest("[data-planning-row='true']");

      if (!row || row.classList.contains("is-filtered-out") || bar.offsetParent === null) {
        return;
      }

      bars[String(bar.dataset.issueId || "")] = bar;
    });

    return bars;
  }

  function requestPlanningRelationsRedraw(root) {
    if (!root || root._relationFrame) {
      return;
    }

    root._relationFrame = window.requestAnimationFrame(function() {
      root._relationFrame = null;
      drawPlanningRelations(root);
    });
  }

  function drawPlanningRelations(root) {
    var layer = root.querySelector("[data-planning-relations-layer='true']");
    var table = root.querySelector(".planning-table");
    var relations = parsePayload(root.getAttribute("data-relations"));

    if (!layer || !table) {
      return;
    }

    var width = table.scrollWidth || table.offsetWidth || 0;
    var height = table.scrollHeight || table.offsetHeight || 0;

    layer.style.width = String(width) + "px";
    layer.style.height = String(height) + "px";
    layer.setAttribute("width", String(width));
    layer.setAttribute("height", String(height));
    layer.setAttribute("viewBox", "0 0 " + String(width) + " " + String(height));

    if (root.classList.contains("hide-relations")) {
      layer.innerHTML = "";
      return;
    }

    var rootRect = root.getBoundingClientRect();
    var bars = visiblePlanningBars(root);
    var lines = [];
    var defs = [
      "<defs>",
      "<marker id='planning-relation-arrow' markerWidth='10' markerHeight='10' refX='9' refY='5' orient='auto' markerUnits='strokeWidth'>",
      "<path d='M 0 0 L 10 5 L 0 10 z' fill='context-stroke'></path>",
      "</marker>",
      "</defs>"
    ].join("");

    relations.forEach(function(relation) {
      var fromBar = bars[String(relation.from_id || "")];
      var toBar = bars[String(relation.to_id || "")];

      if (!fromBar || !toBar) {
        return;
      }

      var fromRect = fromBar.getBoundingClientRect();
      var toRect = toBar.getBoundingClientRect();
      var startX = Math.round(fromRect.right - rootRect.left + root.scrollLeft);
      var startY = Math.round(fromRect.top + (fromRect.height / 2) - rootRect.top + root.scrollTop);
      var endX = Math.round(toRect.left - rootRect.left + root.scrollLeft);
      var endY = Math.round(toRect.top + (toRect.height / 2) - rootRect.top + root.scrollTop);
      var elbowX = startX + Math.max(24, Math.min(84, Math.round((endX - startX) / 2)));
      var color = planningRelationColor(relation.relation_type);
      var dash = planningRelationDash(relation.relation_type);
      var endPointX = endX > elbowX ? endX - 8 : elbowX + 8;

      if (endX <= startX + 16) {
        elbowX = startX + 42;
        endPointX = elbowX + 8;
      }

      var relClass = 'planning-relation is-' + String(relation.relation_type || 'precedes');
      if (relation.critical) {
        relClass += ' is-critical';
      }

      lines.push(
        "<polyline class='" + relClass + "'" +
          " points='" + [startX + "," + startY, elbowX + "," + startY, elbowX + "," + endY, endPointX + "," + endY].join(" ") + "'" +
          " stroke='" + color + "'" +
          (dash ? " stroke-dasharray='" + dash + "'" : "") +
          " marker-end='url(#planning-relation-arrow)'></polyline>"
      );

      if (relation.delay) {
        lines.push(
          "<text class='planning-relation-label' x='" + String(elbowX + 6) + "' y='" + String(endY - 8) + "'>+" + String(relation.delay) + "d</text>"
        );
      }
    });

    layer.innerHTML = defs + lines.join("");
  }

  function applyPlanningFilters(root) {
    var shell = root.closest(".flow-shell");
    var state = planningFilterState(shell);

    root.classList.toggle("show-baselines", !!state.showBaselines);
    root.classList.toggle("hide-relations", !state.showRelations);

    root.querySelectorAll("[data-planning-row='true']").forEach(function(row) {
      row.classList.toggle("is-filtered-out", !matchesPlanningFilters(row, state));
    });

    requestPlanningRelationsRedraw(root);
  }

  function scrollPlanningToToday(root) {
    var board = root.closest(".planning-board");
    var marker = root.querySelector(".planning-today");

    if (!board || !marker) {
      return;
    }

    var target = marker.offsetLeft - Math.max((board.clientWidth / 2), 120);
    board.scrollTo({ left: Math.max(target, 0), behavior: "smooth" });
  }

  function initPlanningGantts() {
    document.querySelectorAll("[data-planning-gantt='true']").forEach(function(root) {
      if (root.dataset.bound === "true") {
        return;
      }
      root.dataset.bound = "true";

      var shell = root.closest(".flow-shell");
      var windowStart = parseISODate(root.dataset.windowStart);
      var windowEnd = parseISODate(root.dataset.windowEnd);
      var dayWidth = Number(root.dataset.dayWidth || 28);
      var active = null;
      var lastChange = null;
      var undoButton = shell.querySelector("[data-flow-planning-undo='true']");
      var zoomInButton = shell.querySelector("[data-flow-zoom-in='true']");
      var zoomOutButton = shell.querySelector("[data-flow-zoom-out='true']");
      var dayWidthSelect = shell.querySelector("#planner_day_width");
      var planningEditor = shell.querySelector("[data-flow-planning-editor='true']");
      var planningForm = shell.querySelector("[data-flow-planning-editor-form='true']");
      var planningIssueInput = shell.querySelector("[data-flow-planning-editor-issue='true']");
      var planningAssignee = shell.querySelector("[data-flow-planning-editor-assignee='true']");
      var planningVersion = shell.querySelector("[data-flow-planning-editor-version='true']");
      var planningStart = shell.querySelector("[data-flow-planning-editor-start='true']");
      var planningDue = shell.querySelector("[data-flow-planning-editor-due='true']");
      var planningDone = shell.querySelector("[data-flow-planning-editor-done='true']");

      function setPlanningSelection(bar) {
        root.querySelectorAll("[data-gantt-bar='true'].is-selected").forEach(function(node) {
          node.classList.remove("is-selected");
        });
        root.querySelectorAll("[data-planning-row='true'].is-selected").forEach(function(node) {
          node.classList.remove("is-selected");
        });

        if (bar) {
          bar.classList.add("is-selected");
          var row = bar.closest("[data-planning-row='true']");
          if (row) {
            row.classList.add("is-selected");
          }
        }

        if (planningEditor) {
          planningEditor.classList.toggle("is-empty", !bar);
        }

        if (!planningForm) {
          return;
        }

        planningForm.dataset.issueId = bar ? String(bar.dataset.issueId || "") : "";
        if (planningIssueInput) {
          planningIssueInput.value = bar ? "#" + String(bar.dataset.issueId || "") + " " + String(bar.dataset.subject || "") : "";
        }
        if (planningAssignee) {
          planningAssignee.value = bar ? String(bar.dataset.assignedToId || "") : "";
        }
        if (planningVersion) {
          planningVersion.value = bar ? String(bar.dataset.fixedVersionId || "") : "";
        }
        if (planningStart) {
          planningStart.value = bar ? String(bar.dataset.startDate || "") : "";
        }
        if (planningDue) {
          planningDue.value = bar ? String(bar.dataset.dueDate || "") : "";
        }
        if (planningDone) {
          planningDone.value = bar ? String(bar.dataset.doneRatio || "0") : "";
        }
      }

      function resolvePlanningSelection() {
        var issueId = extractIssueId((planningIssueInput && planningIssueInput.value) || (planningForm && planningForm.dataset.issueId));
        if (!issueId) {
          return null;
        }

        return root.querySelector("[data-gantt-bar='true'][data-issue-id='" + issueId + "']");
      }

      function savePlanningUpdate(bar, payload) {
        if (!bar || !bar.dataset.updateUrl) {
          showMessage(shell, "error", shell.dataset.flowFailureMessage || "Request failed");
          return Promise.resolve();
        }

        bar.dataset.saving = "true";

        return requestJSON(bar.dataset.updateUrl, payload).then(function(data) {
          updatePlanningBarFromPayload(bar, data.issue || {}, root);
          applyPlanningFilters(root);
          applyColorMode(shell);
          setPlanningSelection(bar);
          showMessage(shell, "success", data.message || shell.dataset.flowSavedMessage || "Saved");
          return data;
        }).catch(function(error) {
          showMessage(shell, "error", fallbackError(shell, error));
          throw error;
        }).finally(function() {
          delete bar.dataset.saving;
        });
      }

      restorePlanningFilters(shell);
      requestPlanningRelationsRedraw(root);

      // Planning preferences storage key
      var planningPrefsKey = "redmine_flow_planner:planning_prefs:" + ((shell && shell.dataset.flowStorageKey) || window.location.pathname);

      // Helper to apply a new day width (updates CSS vars and recomputes offsets/widths)
      function applyDayWidth(newDayWidth) {
        dayWidth = Number(newDayWidth) || dayWidth;
        root.dataset.dayWidth = String(dayWidth);
        var table = root.querySelector('.planning-table');
        if (table) {
          var totalDays = Math.round((utcValue(windowEnd) - utcValue(windowStart)) / DAY_IN_MS) + 1;
          table.style.setProperty('--day-width', String(dayWidth) + 'px');
          table.style.setProperty('--timeline-width', String(totalDays * dayWidth) + 'px');
        }

        // Recompute every bar and baseline positions based on data attributes
        root.querySelectorAll('[data-gantt-bar="true"], [data-gantt-baseline="true"]').forEach(function(el) {
          var s = parseISODate(el.dataset.startDate);
          var e = parseISODate(el.dataset.dueDate);
          if (!s || !e) return;
          var offset = diffDays(s, windowStart) * dayWidth;
          var width = (diffDays(e, s) + 1) * dayWidth;
          el.style.setProperty('--bar-offset', String(offset) + 'px');
          el.style.setProperty('--bar-width', String(Math.max(width, dayWidth)) + 'px');
        });

        // Reposition version markers
        root.querySelectorAll('.planning-marker').forEach(function(marker) {
          var dateAttr = marker.dataset && (marker.dataset.dueDate || marker.dataset.due_date || marker.getAttribute('data-due-date'));
          var date = parseISODate(dateAttr);
          if (!date) return;
          var offset = diffDays(date, windowStart) * dayWidth;
          marker.style.left = String(offset) + 'px';
        });

        // Persist preference (merge with existing prefs to avoid overwriting other keys)
        try {
          var _prefs = readStoredState(planningPrefsKey) || {};
          _prefs.dayWidth = dayWidth;
          writeStoredState(planningPrefsKey, _prefs);
        } catch (e) {
          // ignore storage errors
        }
      }

      // Restore day width preference if present without reloading the page.
      (function restoreDayWidthPref() {
        var prefs = readStoredState(planningPrefsKey) || {};
        if (prefs.dayWidth) {
          applyDayWidth(Number(prefs.dayWidth));
        }
      })();

      // Auto-fit button: compute day width so the whole timeline fits the visible board
      var autoFitButton = shell.querySelector("[data-flow-autoscale='true']");
      if (autoFitButton) {
        autoFitButton.addEventListener('click', function() {
          var board = root.closest('.planning-board') || root.parentElement;
          var totalDays = Math.round((utcValue(windowEnd) - utcValue(windowStart)) / DAY_IN_MS) + 1;
          var visibleWidth = (board && board.clientWidth) || root.clientWidth || 800;
          // Reserve some space for side gutters/rows/metrics. Use a conservative reserve value.
          var reserve = 160;
          var available = Math.max(100, visibleWidth - reserve);
          var fitted = Math.max(8, Math.min(200, Math.floor(available / Math.max(1, totalDays))));
          applyDayWidth(fitted);
        });
      }

      // Initialize progress fill from data attribute, label text, or grid cell (robust fallback)
      root.querySelectorAll("[data-gantt-bar='true']").forEach(function(bar) {
        try {
          var pct = null;

          // 1) prefer explicit data attribute
          if (bar.dataset && bar.dataset.doneRatio !== undefined && bar.dataset.doneRatio !== "") {
            pct = Number(bar.dataset.doneRatio);
          }

          // 2) fall back to label inside the bar
          if ((pct === null || Number.isNaN(pct)) && bar.querySelector) {
            var lbl = bar.querySelector('.planning-bar-label');
            if (lbl) {
              var txt = String(lbl.textContent || '').replace(/[^0-9]/g, '');
              if (txt !== '') pct = Number(txt);
            }
          }

          // 3) fall back to the grid progress cell in the same row
          if ((pct === null || Number.isNaN(pct)) && bar.closest) {
            var row = bar.closest("[data-planning-row='true']");
            if (row) {
              var gridDone = row.querySelector('.planning-grid-cell--progress');
              if (gridDone) {
                var gtxt = String(gridDone.textContent || '').replace(/[^0-9]/g, '');
                if (gtxt !== '') pct = Number(gtxt);
              }
            }
          }

          if (pct === null || Number.isNaN(pct)) {
            pct = 0;
          }

          pct = Math.max(0, Math.min(100, Number(pct)));

          // Apply visual fill and ensure label/grid reflect the same value
          bar.style.setProperty('--bar-progress', String(pct) + '%');
          try {
            var lbl2 = bar.querySelector('.planning-bar-label');
            if (lbl2) lbl2.textContent = String(pct) + '%';
          } catch (err) {}
          try {
            var row2 = bar.closest("[data-planning-row='true']");
            if (row2) {
              var gridDone2 = row2.querySelector('.planning-grid-cell--progress');
              if (gridDone2) gridDone2.textContent = String(pct) + '%';
            }
          } catch (err) {}

        } catch (e) {
          // ignore
        }

        if (bar.dataset.draggable !== "true") {
          return;
        }

        bar.addEventListener("click", function(event) {
          if (event.target.closest("[data-gantt-handle]")) {
            return;
          }
          setPlanningSelection(bar);
        });

        bar.addEventListener("pointerdown", function(event) {
          if (bar.dataset.saving === "true") {
            return;
          }

          var handle = event.target.closest("[data-gantt-handle]");
          active = {
            bar: bar,
            mode: handle ? handle.dataset.ganttHandle : "move",
            originX: event.clientX,
            dayWidth: dayWidth,
            windowStart: windowStart,
            windowEnd: windowEnd,
            startDate: parseISODate(bar.dataset.startDate),
            dueDate: parseISODate(bar.dataset.dueDate),
            deltaDays: 0,
            changed: false,
            row: bar.closest("[data-planning-row='true']"),
            baseline: bar.closest(".planning-row-track").querySelector("[data-gantt-baseline='true']"),
            datesNode: bar.closest("[data-planning-row='true']").querySelector(".js-gantt-dates")
          };

          bar.classList.add("is-preview");

          try {
            bar.setPointerCapture(event.pointerId);
          } catch (error) {
            // Ignore browsers that refuse pointer capture for synthetic sequences.
          }

          event.preventDefault();
        });

        // Double-click to edit done_ratio inline (percentage complete)
        bar.addEventListener('dblclick', function(event) {
          try {
            if (bar.dataset.saving === "true") {
              return;
            }

            var updateUrl = bar.dataset.updateUrl;
            if (!updateUrl) {
              return;
            }

            // Don't open editor when dblclicking a handle
            if (event.target.closest('[data-gantt-handle]')) {
              return;
            }

            // Prevent multiple editors
            if (bar.querySelector('.planning-bar-progress-input')) {
              return;
            }

            var label = bar.querySelector('.planning-bar-label');
            var current = label ? parseInt(String(label.textContent).replace(/[^0-9]/g, ''), 10) : NaN;
            if (isNaN(current)) {
              current = 0;
            }

            var input = document.createElement('input');
            input.type = 'number';
            input.min = 0;
            input.max = 100;
            input.value = String(current);
            input.className = 'planning-bar-progress-input';
            input.autocomplete = 'off';

            // stop propagation so it doesn't interfere with drag handlers
            input.addEventListener('pointerdown', function(ev) { ev.stopPropagation(); });

            function cleanup() {
              try { if (input && input.parentNode) input.parentNode.removeChild(input); } catch (e) {}
            }

            function doSave() {
              var parsed = parseInt(String(input.value).replace(/[^0-9]/g, ''), 10);
              if (isNaN(parsed)) {
                showMessage(shell, 'error', shell.dataset.flowInvalidPercentMessage || 'Invalid percent');
                cleanup();
                return;
              }
              var value = Math.max(0, Math.min(100, parsed));
              bar.dataset.saving = 'true';
              requestJSON(updateUrl, { issue: { done_ratio: value } }).then(function(data) {
                updatePlanningBarFromPayload(bar, data.issue || { done_ratio: value }, root);
                applyPlanningFilters(root);
                applyColorMode(shell);
                setPlanningSelection(bar);
                showMessage(shell, 'success', data.message || shell.dataset.flowSavedMessage || 'Saved');
              }).catch(function(error) {
                showMessage(shell, 'error', fallbackError(shell, error));
              }).finally(function() {
                delete bar.dataset.saving;
                cleanup();
              });
            }

            input.addEventListener('keydown', function(e) {
              if (e.key === 'Enter') {
                doSave();
              } else if (e.key === 'Escape') {
                cleanup();
              }
            });

            input.addEventListener('blur', function() {
              // small timeout to allow Enter handler to run first
              setTimeout(function() {
                if (document.activeElement !== input) {
                  doSave();
                }
              }, 150);
            });

            bar.appendChild(input);
            input.focus();
            input.select();
          } catch (err) {
            console.error(err);
          }
        });
      });

      root.addEventListener("pointermove", function(event) {
        if (!active) {
          return;
        }

        var rawDelta = Math.round((event.clientX - active.originX) / active.dayWidth);
        active.deltaDays = clampDelta(active, rawDelta);
        active.changed = active.deltaDays !== 0;

        var dates = computeDates(active);
        renderBar(active.bar, active.windowStart, active.dayWidth, dates.startDate, dates.dueDate);

        if (active.datesNode) {
          active.datesNode.textContent = humanRange(dates.startDate, dates.dueDate);
        }

        event.preventDefault();
      });

      function finishInteraction(event) {
        if (!active) {
          return;
        }

        var state = active;
        active = null;
        state.bar.classList.remove("is-preview");

        try {
          state.bar.releasePointerCapture(event.pointerId);
        } catch (error) {
          // Ignore browsers that did not capture the pointer.
        }

        if (!state.changed) {
          syncDates(state, state.startDate, state.dueDate);
          return;
        }

        var dates = computeDates(state);
        state.bar.dataset.saving = "true";

        requestJSON(state.bar.dataset.updateUrl, {
          issue: {
            start_date: formatISODate(dates.startDate),
            due_date: formatISODate(dates.dueDate)
          }
        }).then(function(data) {
          var nextStart = parseISODate((data.issue && data.issue.start_date) || formatISODate(dates.startDate));
          var nextDue = parseISODate((data.issue && data.issue.due_date) || formatISODate(dates.dueDate));

          lastChange = {
            bar: state.bar,
            row: state.row,
            datesNode: state.datesNode,
            previousStart: state.startDate,
            previousDue: state.dueDate,
            currentStart: nextStart,
            currentDue: nextDue,
            updateUrl: state.bar.dataset.updateUrl
          };
          if (undoButton) {
            undoButton.disabled = false;
          }

          updatePlanningBarFromPayload(state.bar, data.issue || {
            start_date: formatISODate(nextStart),
            due_date: formatISODate(nextDue)
          }, root);
          renderBaseline(state.baseline, state.windowStart, state.dayWidth, parseISODate(state.bar.dataset.baselineStartDate), parseISODate(state.bar.dataset.baselineDueDate));
          applyPlanningFilters(root);
          applyColorMode(shell);
          setPlanningSelection(state.bar);
          showMessage(shell, "success", data.message || shell.dataset.flowSavedMessage || "Saved");
        }).catch(function(error) {
          syncDates(state, state.startDate, state.dueDate);
          applyPlanningFilters(root);
          showMessage(shell, "error", fallbackError(shell, error));
        }).finally(function() {
          delete state.bar.dataset.saving;
        });
      }

      root.addEventListener("pointerup", finishInteraction);
      root.addEventListener("pointercancel", finishInteraction);
      root.addEventListener("pointerleave", function(event) {
        if (active && event.buttons === 0) {
          finishInteraction(event);
        }
      });

      shell.querySelectorAll("[data-flow-planning-filters='true'] input, [data-flow-planning-filters='true'] select").forEach(function(input) {
        input.addEventListener("input", function() {
          persistPlanningFilters(shell);
          applyPlanningFilters(root);
        });
        input.addEventListener("change", function() {
          persistPlanningFilters(shell);
          applyPlanningFilters(root);
        });
      });

      var resetButton = shell.querySelector("[data-flow-planning-filters='true'] [data-flow-reset-filters='true']");
      if (resetButton) {
        resetButton.addEventListener("click", function() {
          shell.querySelectorAll("[data-flow-planning-filters='true'] input[type='search']").forEach(function(input) {
            input.value = "";
          });
          shell.querySelectorAll("[data-flow-planning-filters='true'] select").forEach(function(select) {
            select.value = "";
          });
          shell.querySelectorAll("[data-flow-planning-filters='true'] input[type='checkbox']").forEach(function(input) {
            input.checked = false;
          });
          var relationsToggle = shell.querySelector("[data-flow-toggle-relations='true']");
          if (relationsToggle) {
            relationsToggle.checked = true;
          }
          persistPlanningFilters(shell);
          applyPlanningFilters(root);
        });
      }

      if (planningIssueInput) {
        planningIssueInput.addEventListener("change", function() {
          var bar = resolvePlanningSelection();
          if (bar) {
            setPlanningSelection(bar);
          }
        });
      }

      if (planningForm) {
        planningForm.addEventListener("submit", function(event) {
          var bar;
          var payload = { issue: {} };
          var startValue;
          var dueValue;
          var doneValue;

          event.preventDefault();
          bar = resolvePlanningSelection();
          if (!bar) {
            showMessage(shell, "error", shell.dataset.flowFailureMessage || "Request failed");
            return;
          }

          startValue = planningStart && planningStart.value ? planningStart.value : String(bar.dataset.startDate || "");
          dueValue = planningDue && planningDue.value ? planningDue.value : String(bar.dataset.dueDate || startValue);

          if (startValue && dueValue && dueValue < startValue) {
            dueValue = startValue;
            if (planningDue) {
              planningDue.value = dueValue;
            }
          }

          doneValue = planningDone ? Number(planningDone.value || bar.dataset.doneRatio || 0) : Number(bar.dataset.doneRatio || 0);
          doneValue = Math.max(0, Math.min(100, doneValue));

          payload.issue.assigned_to_id = planningAssignee ? planningAssignee.value : "";
          payload.issue.fixed_version_id = planningVersion ? planningVersion.value : "";
          payload.issue.start_date = startValue;
          payload.issue.due_date = dueValue;
          payload.issue.done_ratio = doneValue;

          savePlanningUpdate(bar, payload);
        });
      }

      var planningReset = shell.querySelector("[data-flow-planning-editor-reset='true']");
      if (planningReset) {
        planningReset.addEventListener("click", function() {
          setPlanningSelection(null);
        });
      }

      if (undoButton) {
        undoButton.addEventListener("click", function() {
          if (!lastChange || undoButton.disabled) {
            return;
          }

          var change = lastChange;
          undoButton.disabled = true;
          change.bar.dataset.saving = "true";

          requestJSON(change.updateUrl, {
            issue: {
              start_date: formatISODate(change.previousStart),
              due_date: formatISODate(change.previousDue)
            }
          }).then(function(data) {
            var nextStart = parseISODate((data.issue && data.issue.start_date) || formatISODate(change.previousStart));
            var nextDue = parseISODate((data.issue && data.issue.due_date) || formatISODate(change.previousDue));

            updatePlanningBarFromPayload(change.bar, data.issue || {
              start_date: formatISODate(nextStart),
              due_date: formatISODate(nextDue)
            }, root);
            lastChange = null;
            applyPlanningFilters(root);
            applyColorMode(shell);
            setPlanningSelection(change.bar);
            showMessage(shell, "success", shell.dataset.flowSavedMessage || "Saved");
          }).catch(function(error) {
            undoButton.disabled = false;
            showMessage(shell, "error", fallbackError(shell, error));
          }).finally(function() {
            delete change.bar.dataset.saving;
          });
        });
      }

      function stepZoom(direction) {
        // If there's a day width <select> present we keep previous behavior (submit form)
        if (dayWidthSelect && dayWidthSelect.form && dayWidthSelect.options && dayWidthSelect.options.length > 0) {
          var options = Array.prototype.map.call(dayWidthSelect.options, function(option) {
            return Number(option.value);
          });
          var currentValue = Number(dayWidthSelect.value || dayWidth);
          var currentIndex = options.indexOf(currentValue);
          var nextIndex = currentIndex + direction;

          if (currentIndex === -1 || nextIndex < 0 || nextIndex >= options.length) {
            return;
          }

          dayWidthSelect.value = String(options[nextIndex]);
          dayWidthSelect.form.submit();
          return;
        }

        // Otherwise fallback to client-side zoom (step by 4px)
        var next = Math.max(8, Math.min(200, Math.round(dayWidth + direction * 4)));
        applyDayWidth(next);
      }

      if (zoomInButton) {
        zoomInButton.addEventListener("click", function() {
          stepZoom(1);
        });
      }

      if (zoomOutButton) {
        zoomOutButton.addEventListener("click", function() {
          stepZoom(-1);
        });
      }

      var todayButton = shell.querySelector("[data-flow-scroll-today='true']");
      if (todayButton) {
        todayButton.addEventListener("click", function() {
          scrollPlanningToToday(root);
        });
      }

      setPlanningSelection(null);
      applyPlanningFilters(root);
      window.addEventListener("resize", function() {
        requestPlanningRelationsRedraw(root);
      });
      root.addEventListener("scroll", function() {
        requestPlanningRelationsRedraw(root);
      });
    });
  }

  onReady(function() {
    initFlowShells();
    initAgileBoards();
    initPlanningGantts();
  });
})();
