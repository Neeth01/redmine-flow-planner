# frozen_string_literal: true

module FlowPlannerHelper
  def flow_shell_classes(settings = nil)
    classes = ['flow-shell']
    classes << 'is-compact' if settings&.compact_density?
    classes.join(' ')
  end

  def flow_shell_style(settings)
    return '' unless settings

    {
      '--flow-accent' => settings.ui_accent_color,
      '--flow-accent-soft' => settings.ui_accent_soft_color,
      '--flow-panel-radius' => "#{settings.panel_radius}px",
      '--flow-card-radius' => "#{settings.card_radius}px",
      '--flow-column-width' => "#{settings.board_column_width}px",
      '--flow-gantt-bar-start' => settings.gantt_bar_color_start,
      '--flow-gantt-bar-end' => settings.gantt_bar_color_end,
      '--flow-gantt-closed-start' => settings.gantt_closed_bar_color_start,
      '--flow-gantt-closed-end' => settings.gantt_closed_bar_color_end,
      '--flow-gantt-relation' => settings.gantt_relation_color,
      '--flow-gantt-today' => settings.gantt_today_color,
      '--flow-gantt-marker' => settings.gantt_version_marker_color,
      '--flow-weekend-tint' => settings.weekend_tint_color
    }.map {|name, value| "#{name}: #{value}"}.join('; ')
  end

  def flow_query_params
    request.query_parameters.except(:controller, :action, :project_id)
  end

  def flow_global_mode?(project = @project)
    project.blank?
  end

  def flow_agile_board_path_for(project = @project, options = {})
    if flow_global_mode?(project)
      global_agile_board_path(options)
    else
      project_agile_board_path(project, options)
    end
  end

  def flow_agile_board_issue_path_for(issue, project = @project)
    if flow_global_mode?(project)
      global_agile_board_issue_path(issue)
    else
      project_agile_board_issue_path(project, issue)
    end
  end

  def flow_agile_board_issues_path_for(project = @project)
    return nil if flow_global_mode?(project)

    project_agile_board_issues_path(project)
  end

  def flow_planning_gantt_path_for(project = @project, options = {})
    if flow_global_mode?(project)
      global_planning_gantt_path(options)
    else
      project_planning_gantt_path(project, options)
    end
  end

  def flow_planning_gantt_issue_path_for(issue, project = @project)
    if flow_global_mode?(project)
      global_planning_gantt_issue_path(issue)
    else
      project_planning_gantt_issue_path(project, issue)
    end
  end

  def flow_issues_path_for(project = @project, options = {})
    if flow_global_mode?(project)
      issues_path(options)
    else
      project_issues_path(project, options)
    end
  end

  def flow_project_label(issue)
    issue.project&.name
  end

  def flow_project_palette(project)
    return unless project

    seed = project.id.to_i
    seed = project.identifier.to_s.each_byte.sum if seed <= 0
    seed += project.name.to_s.each_byte.sum
    hue = (seed * 47) % 360

    {
      accent: "hsl(#{hue} 62% 48%)",
      accent_strong: "hsl(#{hue} 58% 28%)",
      soft: "hsl(#{hue} 88% 96%)",
      soft_alt: "hsl(#{hue} 82% 92%)",
      border: "hsl(#{hue} 44% 78%)",
      bar_start: "hsl(#{hue} 78% 58%)",
      bar_end: "hsl(#{(hue + 18) % 360} 74% 40%)",
      bar_glow: "hsla(#{hue} 76% 42% / 0.18)",
      closed_start: "hsl(#{hue} 32% 58%)",
      closed_end: "hsl(#{(hue + 16) % 360} 28% 40%)"
    }
  end

  def flow_project_style(project)
    palette = flow_project_palette(project)
    return '' unless palette

    {
      '--flow-project-accent' => palette[:accent],
      '--flow-project-accent-strong' => palette[:accent_strong],
      '--flow-project-soft' => palette[:soft],
      '--flow-project-soft-alt' => palette[:soft_alt],
      '--flow-project-border' => palette[:border],
      '--flow-project-bar-start' => palette[:bar_start],
      '--flow-project-bar-end' => palette[:bar_end],
      '--flow-project-bar-glow' => palette[:bar_glow],
      '--flow-project-bar-closed-start' => palette[:closed_start],
      '--flow-project-bar-closed-end' => palette[:closed_end]
    }.map {|name, value| "#{name}: #{value}"}.join('; ')
  end

  def flow_issue_manageable_on_board?(issue)
    User.current.admin? || User.current.allowed_to?(:manage_agile_board, issue.project)
  rescue StandardError
    false
  end

  def flow_issue_manageable_on_planning?(issue)
    User.current.admin? || User.current.allowed_to?(:manage_planning_gantt, issue.project)
  rescue StandardError
    false
  end

  def flow_query_filters(query)
    query.filters.filter_map do |field, filter|
      filter_options = query.available_filters[field]
      next unless filter_options

      values = Array(filter[:values]).reject(&:blank?)
      summary =
        if filter[:operator].to_s == 'o'
          l(:label_flow_open)
        elsif values.any?
          label_map = filter_value_labels(filter_options)
          values.map {|value| label_map[value.to_s] || value}.join(', ')
        else
          filter[:operator].to_s
        end

      "#{filter_options[:name]}: #{summary}"
    end
  end

  def flow_issue_status_editable?(issue)
    editable_core_field?(issue, 'status_id')
  end

  def flow_issue_schedule_editable?(issue)
    editable_core_field?(issue, 'start_date') && editable_core_field?(issue, 'due_date')
  end

  def flow_issue_assignee_editable?(issue)
    editable_core_field?(issue, 'assigned_to_id')
  end

  def flow_issue_done_ratio_editable?(issue)
    editable_core_field?(issue, 'done_ratio')
  end

  def flow_issue_schedule(issue)
    start_date = issue.start_date || issue.due_date
    due_date = issue.due_date || issue.start_date
    return if start_date.blank? || due_date.blank?

    [start_date, due_date]
  end

  def flow_schedule_label(issue)
    schedule = flow_issue_schedule(issue)
    return l(:label_none) unless schedule

    start_date, due_date = schedule
    return format_date(start_date) if start_date == due_date

    "#{format_date(start_date)} -> #{format_date(due_date)}"
  end

  def flow_due_label(issue, due_soon_days)
    return l(:label_none) unless issue.due_date
    return l(:label_flow_overdue) if issue.overdue?

    delta = (issue.due_date - User.current.today).to_i
    return l(:text_flow_due_today) if delta.zero?
    return l(:text_flow_due_tomorrow) if delta == 1
    return l(:text_flow_due_soon, count: delta) if delta.positive? && delta <= due_soon_days

    format_date(issue.due_date)
  end

  def flow_hours_label(value)
    amount = value.to_f
    return '0h' if amount <= 0.0

    rounded =
      if (amount % 1.0).zero?
        amount.to_i.to_s
      else
        format('%.1f', amount).sub(/\.0\z/, '')
      end

    "#{rounded}h"
  end

  def flow_checklist_stats(issue)
    if issue.respond_to?(:flow_checklist_stats)
      stats = issue.flow_checklist_stats
      return stats if stats[:total].to_i.positive?
    else
      stats = nil
    end

    items = FlowChecklistItem.where(issue_id: issue.id).order(:position, :id).to_a
    total = items.size
    completed = items.count(&:done?)
    required_total = items.count(&:mandatory?)
    required_completed = items.count {|item| item.mandatory? && item.done?}

    {
      total: total,
      completed: completed,
      pending: total - completed,
      percent: total.zero? ? 0 : ((completed.to_f / total) * 100).round,
      required_total: required_total,
      required_completed: required_completed,
      blocked: required_total.positive? && required_completed < required_total
    }
  rescue StandardError
    {total: 0, completed: 0, pending: 0, percent: 0, required_total: 0, required_completed: 0, blocked: false}
  end

  def flow_checklist_summary_label(issue)
    stats = flow_checklist_stats(issue)
    return l(:label_flow_checklist_empty) if stats[:total].zero?

    l(:label_flow_checklist_progress_compact, completed: stats[:completed], total: stats[:total])
  end

  def flow_checklist_required_label(issue)
    stats = flow_checklist_stats(issue)
    return nil if stats[:required_total].zero?

    l(:label_flow_checklist_required_compact, completed: stats[:required_completed], total: stats[:required_total])
  end

  def flow_metrics_for(issues, due_soon_days)
    list = Array(issues)
    {
      total: list.size,
      open: list.count {|issue| !issue.closed?},
      overdue: list.count(&:overdue?),
      unassigned: list.count {|issue| issue.assigned_to.blank?},
      due_soon: list.count do |issue|
        issue.due_date.present? &&
          !issue.closed? &&
          issue.due_date >= User.current.today &&
          (issue.due_date - User.current.today).to_i <= due_soon_days
      end,
      scheduled: list.count {|issue| flow_issue_schedule(issue).present?}
    }
  end

  def flow_filter_collection(issues)
    {
      projects: Array(issues).map(&:project).compact.uniq.sort_by(&:name),
      trackers: Array(issues).map(&:tracker).compact.uniq.sort_by(&:name),
      assignees: Array(issues).map(&:assigned_to).compact.uniq.sort_by(&:name)
    }
  end

  private

  def editable_core_field?(issue, field_name)
    names = Array(issue.safe_attribute_names(User.current)).map(&:to_s)
    issue.respond_to?(:attributes_editable?) && issue.attributes_editable?(User.current) && names.include?(field_name)
  rescue StandardError
    false
  end

  def filter_value_labels(filter_options)
    values = filter_options[:values]
    values = values.call if values.respond_to?(:call)
    Array(values).each_with_object({}) do |(label, value), map|
      map[value.to_s] = label
    end
  rescue StandardError
    {}
  end
end
