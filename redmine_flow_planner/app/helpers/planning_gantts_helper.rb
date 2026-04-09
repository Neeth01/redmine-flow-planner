# frozen_string_literal: true

module PlanningGanttsHelper
  def planning_gantt_row_classes(issue)
    classes = ['planning-row']
    classes << 'is-closed' if issue.closed?
    classes << 'is-overdue' if issue.overdue?
    classes.join(' ')
  end

  def planning_gantt_bar_style(issue, timeline, day_width)
    schedule = flow_issue_schedule(issue)
    return '' unless schedule

    visible_start = [schedule.first, timeline.start_date].max
    visible_end = [schedule.last, timeline.end_date].min
    offset = (visible_start - timeline.start_date).to_i * day_width
    width = ((visible_end - visible_start).to_i + 1) * day_width

    "--bar-offset: #{offset}px; --bar-width: #{[width, day_width].max}px;"
  end

  def planning_gantt_day_classes(day)
    classes = ['planning-day']
    classes << 'is-weekend' if day.saturday? || day.sunday?
    classes << 'is-today' if day == User.current.today
    classes.join(' ')
  end

  def planning_gantt_month_label(day)
    I18n.l(day, format: '%b %Y')
  end

  def planning_gantt_today_style(timeline, day_width)
    return unless User.current.today.between?(timeline.start_date, timeline.end_date)

    offset = (User.current.today - timeline.start_date).to_i * day_width
    "inset-inline-start: #{offset}px;"
  end

  def planning_gantt_marker_style(date, timeline, day_width)
    offset = (date - timeline.start_date).to_i * day_width
    "inset-inline-start: #{offset}px;"
  end

  def planning_gantt_day_width_options
    [20, 24, 28, 32, 36, 40, 44, 48].map {|value| [value, value]}
  end

  def planning_gantt_relation_label(relation)
    case relation[:relation_type].to_s
    when 'precedes'
      l(:text_flow_relation_precedes)
    when 'blocks'
      l(:text_flow_relation_blocks)
    else
      l(:text_flow_relation_relates)
    end
  end
end
