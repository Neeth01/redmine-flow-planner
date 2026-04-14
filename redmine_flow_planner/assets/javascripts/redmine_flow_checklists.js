(function() {
  "use strict";

  function onReady(callback) {
    document.addEventListener("DOMContentLoaded", callback);
    document.addEventListener("turbo:load", callback);
  }

  function csrfToken() {
    var token = document.querySelector("meta[name='csrf-token']");
    return token ? token.getAttribute("content") : null;
  }

  function requestJSON(url, payload, method) {
    var headers = {
      "Accept": "application/json"
    };
    var token = csrfToken();

    if (token) {
      headers["X-CSRF-Token"] = token;
    }

    if (payload) {
      headers["Content-Type"] = "application/json";
    }

    return fetch(url, {
      method: method || "PATCH",
      credentials: "same-origin",
      headers: headers,
      body: payload ? JSON.stringify(payload) : null
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

  function showMessage(root, kind, text) {
    var box = root && root.querySelector("[data-flow-checklist-message='true']");
    if (!box || !text) {
      return;
    }

    box.hidden = false;
    box.textContent = text;
    box.classList.remove("is-error", "is-success");
    box.classList.add(kind === "error" ? "is-error" : "is-success");

    clearTimeout(box._timeout);
    box._timeout = setTimeout(function() {
      box.hidden = true;
    }, 4000);
  }

  function fallbackError(root, error) {
    if (error && error.message && error.message !== "Request failed") {
      return error.message;
    }

    return (root && root.dataset.failureMessage) || (root && root.dataset.errorMessage) || "Request failed";
  }

  function subjectRequiredMessage(root) {
    return (root && root.dataset.subjectRequiredMessage) || "Le texte du point est obligatoire.";
  }

  function templateRequiredMessage(root) {
    return (root && root.dataset.templateRequiredMessage) || "Choisissez un template.";
  }

  function extractRoot(html) {
    var wrapper = document.createElement("div");
    wrapper.innerHTML = html;
    return wrapper.querySelector("[data-flow-checklist='true']");
  }

  function replaceRoot(root, html) {
    var nextRoot = extractRoot(html);
    if (!nextRoot) {
      return root;
    }

    root.replaceWith(nextRoot);
    initFlowChecklists();
    return nextRoot;
  }

  function hideNode(node) {
    if (!node) {
      return;
    }

    node.hidden = true;
    node.classList.add("is-hidden");
  }

  function showNode(node) {
    if (!node) {
      return;
    }

    node.hidden = false;
    node.classList.remove("is-hidden");
  }

  function payloadFromForm(form) {
    var subject = form.querySelector("input[name='item[subject]']");
    var mandatory = form.querySelector("input[name='item[mandatory]']");
    var payload = {
      item: {
        subject: subject ? subject.value.trim() : "",
        mandatory: mandatory && mandatory.checked ? "1" : "0"
      }
    };

    if (form.dataset.flowChecklistEditForm === "true") {
      var toggle = form.closest("[data-flow-checklist-item='true']").querySelector("[data-flow-checklist-toggle='true']");
      payload.item.is_done = toggle && toggle.checked ? "1" : "0";
    }

    return payload;
  }

  function syncEmptyState(root) {
    var empty = root.querySelector("[data-flow-checklist-empty='true']");
    var hasItems = root.querySelectorAll("[data-flow-checklist-item='true']").length > 0;

    if (!empty) {
      return;
    }

    if (hasItems) {
      hideNode(empty);
    } else {
      showNode(empty);
    }
  }

  function issueShowPage() {
    var body = document.body;
    return body &&
      body.classList.contains("controller-issues") &&
      body.classList.contains("action-show");
  }

  function currentIssueId() {
    var match = window.location.pathname.match(/\/issues\/(\d+)(?:$|[/?#])/);
    return match ? match[1] : null;
  }

  function mountChecklistPanel(html) {
    var panel = extractRoot(html);
    var issue;
    var mount;
    var beforeNode;
    var separator;

    if (!panel || document.querySelector("[data-flow-checklist='true']")) {
      return;
    }

    issue = document.querySelector("#content .issue.details") || document.querySelector("#content .issue");
    if (!issue) {
      return;
    }

    mount = document.createElement("div");
    mount.className = "flow-checklist-mount";

    separator = document.createElement("hr");
    mount.appendChild(separator);
    mount.appendChild(panel);

    beforeNode = issue.querySelector("#issue_tree") || issue.querySelector("#relations");
    if (beforeNode) {
      issue.insertBefore(mount, beforeNode);
    } else {
      issue.appendChild(mount);
    }
  }

  function ensureChecklistMounted() {
    var body = document.body;
    var issueId;
    var fetchUrl;

    if (!issueShowPage() || document.querySelector("[data-flow-checklist='true']")) {
      return;
    }

    if (body && body.dataset.flowChecklistMountRequested === "true") {
      return;
    }

    issueId = currentIssueId();
    if (!issueId) {
      return;
    }

    if (body) {
      body.dataset.flowChecklistMountRequested = "true";
    }

    fetchUrl = "/issues/" + issueId + "/flow_checklist_items";
    requestJSON(fetchUrl, null, "GET").then(function(data) {
      if (data && data.html) {
        mountChecklistPanel(data.html);
        initFlowChecklists();
      }
    }).catch(function() {
      if (body) {
        body.dataset.flowChecklistMountRequested = "false";
      }
      return null;
    });
  }

  function saveChecklist(root, url, payload, method) {
    root.classList.add("is-loading");

    return requestJSON(url, payload, method).then(function(data) {
      var nextRoot = data.html ? replaceRoot(root, data.html) : root;
      showMessage(nextRoot, "success", data.message || nextRoot.dataset.savedMessage);
      return nextRoot;
    }).catch(function(error) {
      showMessage(root, "error", fallbackError(root, error));
      return root;
    }).finally(function() {
      root.classList.remove("is-loading");
    });
  }

  function bindAddForm(root) {
    var toggle = root.querySelector("[data-flow-checklist-add-toggle='true']");
    var cancel = root.querySelector("[data-flow-checklist-add-cancel='true']");
    var form = root.querySelector("[data-flow-checklist-form='true']");

    if (!form) {
      return;
    }

    if (toggle) {
      toggle.addEventListener("click", function() {
        showNode(form);
        hideNode(toggle);
        var input = form.querySelector("input[type='text']");
        if (input) {
          input.focus();
        }
      });
    }

    if (cancel) {
      cancel.addEventListener("click", function() {
        form.reset();
        hideNode(form);
        if (toggle) {
          showNode(toggle);
        }
      });
    }

    form.addEventListener("submit", function(event) {
      event.preventDefault();

      var payload = payloadFromForm(form);
      if (!payload.item.subject) {
        showMessage(root, "error", subjectRequiredMessage(root));
        return;
      }

      saveChecklist(root, root.dataset.createUrl, payload, "POST");
    });
  }

  function bindTemplateForm(root) {
    var form = root.querySelector("[data-flow-checklist-template-form='true']");
    var select;

    if (!form) {
      return;
    }

    select = form.querySelector("[data-flow-checklist-template-select='true']");

    form.addEventListener("submit", function(event) {
      event.preventDefault();

      if (!select || !select.value) {
        showMessage(root, "error", templateRequiredMessage(root));
        return;
      }

      saveChecklist(root, root.dataset.applyTemplateUrl, {template_id: select.value}, "POST");
    });
  }

  function bindItems(root) {
    root.querySelectorAll("[data-flow-checklist-item='true']").forEach(function(item) {
      var updateUrl = item.dataset.updateUrl;
      var destroyUrl = item.dataset.destroyUrl;
      var toggle = item.querySelector("[data-flow-checklist-toggle='true']");
      var editToggle = item.querySelector("[data-flow-checklist-edit-toggle='true']");
      var editCancel = item.querySelector("[data-flow-checklist-edit-cancel='true']");
      var editForm = item.querySelector("[data-flow-checklist-edit-form='true']");
      var destroy = item.querySelector("[data-flow-checklist-delete='true']");

      if (toggle) {
        toggle.addEventListener("change", function() {
          saveChecklist(root, updateUrl, {item: {is_done: toggle.checked ? "1" : "0"}}, "PATCH");
        });
      }

      if (editToggle && editForm) {
        editToggle.addEventListener("click", function() {
          root.querySelectorAll("[data-flow-checklist-edit-form='true']").forEach(hideNode);
          showNode(editForm);
          var input = editForm.querySelector("input[type='text']");
          if (input) {
            input.focus();
            input.select();
          }
        });
      }

      if (editCancel && editForm) {
        editCancel.addEventListener("click", function() {
          hideNode(editForm);
        });
      }

      if (editForm) {
        editForm.addEventListener("submit", function(event) {
          event.preventDefault();
          var payload = payloadFromForm(editForm);

          if (!payload.item.subject) {
            showMessage(root, "error", subjectRequiredMessage(root));
            return;
          }

          saveChecklist(root, updateUrl, payload, "PATCH");
        });
      }

      if (destroy) {
        destroy.addEventListener("click", function() {
          if (!window.confirm(root.dataset.deleteConfirmMessage || "Delete?")) {
            return;
          }

          saveChecklist(root, destroyUrl, null, "DELETE");
        });
      }
    });
  }

  function bindReorder(root) {
    var list = root.querySelector("[data-flow-checklist-list='true']");
    var draggedId = null;

    if (!list) {
      return;
    }

    list.querySelectorAll("[data-flow-checklist-item='true']").forEach(function(item) {
      item.addEventListener("dragstart", function(event) {
        if (!event.target.closest("[data-flow-checklist-drag='true']")) {
          event.preventDefault();
          return;
        }

        draggedId = item.dataset.itemId;
        item.classList.add("is-dragging");
        event.dataTransfer.effectAllowed = "move";
      });

      item.addEventListener("dragend", function() {
        draggedId = null;
        item.classList.remove("is-dragging");
        list.querySelectorAll(".is-drop-target").forEach(function(node) {
          node.classList.remove("is-drop-target");
        });
      });

      item.addEventListener("dragover", function(event) {
        if (!draggedId || draggedId === item.dataset.itemId) {
          return;
        }

        event.preventDefault();
        item.classList.add("is-drop-target");
      });

      item.addEventListener("dragleave", function() {
        item.classList.remove("is-drop-target");
      });

      item.addEventListener("drop", function(event) {
        var dragged;
        var afterTarget;
        var ids;

        if (!draggedId || draggedId === item.dataset.itemId) {
          return;
        }

        event.preventDefault();
        item.classList.remove("is-drop-target");

        dragged = list.querySelector("[data-item-id='" + draggedId + "']");
        if (!dragged) {
          return;
        }

        afterTarget = event.clientY > (item.getBoundingClientRect().top + item.offsetHeight / 2);
        list.insertBefore(dragged, afterTarget ? item.nextSibling : item);

        ids = Array.prototype.map.call(
          list.querySelectorAll("[data-flow-checklist-item='true']"),
          function(node) { return Number(node.dataset.itemId); }
        );

        saveChecklist(root, root.dataset.reorderUrl, {item_ids: ids}, "PATCH");
      });
    });
  }

  function initFlowChecklists() {
    document.querySelectorAll("[data-flow-checklist='true']").forEach(function(root) {
      if (root.dataset.flowChecklistBound === "true") {
        syncEmptyState(root);
        return;
      }

      root.dataset.flowChecklistBound = "true";
      syncEmptyState(root);
      bindAddForm(root);
      bindTemplateForm(root);
      bindItems(root);
      bindReorder(root);
    });
  }

  onReady(function() {
    ensureChecklistMounted();
    initFlowChecklists();
  });
})();
