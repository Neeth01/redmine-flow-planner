# frozen_string_literal: true

module FlowPlannerHelper
  def flow_query_params
    request.query_parameters.except(:controller, :action, :project_id)
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
