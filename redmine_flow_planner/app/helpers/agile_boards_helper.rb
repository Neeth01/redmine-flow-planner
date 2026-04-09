# frozen_string_literal: true

module AgileBoardsHelper
  AGILE_SORTS = {
    'priority' => :label_flow_sort_priority,
    'due_date' => :label_flow_sort_due_date,
    'updated_on' => :label_flow_sort_updated_on,
    'done_ratio' => :label_flow_sort_done_ratio,
    'subject' => :label_flow_sort_subject,
    'id' => :label_flow_sort_id
  }.freeze

  def agile_board_card_classes(issue)
    classes = ['flow-card']
    classes << 'is-closed' if issue.closed?
    classes << 'is-overdue' if issue.overdue?
    classes << 'is-behind' if issue.respond_to?(:behind_schedule?) && issue.behind_schedule?
    classes.join(' ')
  end

  def agile_board_issues_for(status, issues, sort_name)
    Array(issues).
      select {|issue| issue.status_id == status.id}.
      sort_by {|issue| agile_sort_key(issue, sort_name)}
  end

  def agile_board_count_for(status, issues)
    Array(issues).count {|issue| issue.status_id == status.id}
  end

  def agile_board_sort_options
    AGILE_SORTS.map {|value, label| [l(label), value]}
  end

  def agile_board_wip_state(status, issues, wip_limit)
    count = agile_board_count_for(status, issues)
    return :none unless wip_limit.to_i.positive?
    return :alert if count > wip_limit.to_i
    return :warning if count == wip_limit.to_i

    :ok
  end

  private

  def agile_sort_key(issue, sort_name)
    base = [issue.closed? ? 1 : 0]

    specific =
      case sort_name.to_s
      when 'due_date'
        [issue.due_date || Date.new(9999, 12, 31), -(issue.priority&.position || 0), issue.id]
      when 'updated_on'
        [issue.updated_on ? -issue.updated_on.to_i : 0, issue.id]
      when 'done_ratio'
        [-(issue.done_ratio || 0), issue.due_date || Date.new(9999, 12, 31), issue.id]
      when 'subject'
        [issue.subject.to_s.downcase, issue.id]
      when 'id'
        [issue.id]
      else
        [-(issue.priority&.position || 0), issue.due_date || Date.new(9999, 12, 31), issue.id]
      end

    base + specific
  end
end
