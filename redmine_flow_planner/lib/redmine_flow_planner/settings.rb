# frozen_string_literal: true

module RedmineFlowPlanner
  class Settings
    DEFAULTS = {
      'board_limit' => '200',
      'board_default_sort' => 'priority',
      'board_default_grouping' => '',
      'board_column_width' => '320',
      'board_quick_create' => '1',
      'board_inline_edit' => '1',
      'board_quick_actions' => '1',
      'board_show_hours' => '1',
      'board_show_version_badges' => '1',
      'checklist_enforce_completion' => '0',
      'checklist_show_summary' => '1',
      'checklist_auto_apply_templates' => '1',
      'board_wip_limits' => '',
      'due_soon_days' => '7',
      'planner_limit' => '250',
      'planner_months' => '4',
      'planner_day_width' => '28',
      'planner_default_scale' => 'month',
      'planner_show_relations' => '1',
      'planner_show_legend' => '1',
      'planner_show_unscheduled' => '1',
      'planner_show_editor' => '1',
      'ui_density' => 'comfortable',
      'ui_accent_color' => '#0f5f9c',
      'ui_accent_soft_color' => '#e8f2ff',
      'gantt_bar_color_start' => '#155eef',
      'gantt_bar_color_end' => '#0f5f9c',
      'gantt_closed_bar_color_start' => '#64748b',
      'gantt_closed_bar_color_end' => '#475569',
      'gantt_relation_color' => '#0f5f9c',
      'gantt_today_color' => '#0f5f9c',
      'gantt_version_marker_color' => '#f4a261',
      'weekend_tint_color' => '#f7f8fa',
      'panel_radius' => '18',
      'card_radius' => '16'
    }.freeze

    def board_limit
      integer_value('board_limit', 200, 50, 1000)
    end

    def planner_limit
      integer_value('planner_limit', 250, 50, 1000)
    end

    def board_default_sort
      value = raw_settings['board_default_sort'].to_s
      %w[priority due_date updated_on done_ratio subject id].include?(value) ? value : 'priority'
    end

    def board_default_grouping
      value = raw_settings['board_default_grouping'].to_s
      %w[ assignee tracker priority version].include?(value) ? value : ''
    end

    def board_column_width
      integer_value('board_column_width', 320, 260, 420)
    end

    def board_quick_create?
      boolean_value('board_quick_create', true)
    end

    def board_inline_edit?
      boolean_value('board_inline_edit', true)
    end

    def board_quick_actions?
      boolean_value('board_quick_actions', true)
    end

    def board_show_hours?
      boolean_value('board_show_hours', true)
    end

    def board_show_version_badges?
      boolean_value('board_show_version_badges', true)
    end

    def checklist_enforce_completion?
      boolean_value('checklist_enforce_completion', false)
    end

    def checklist_show_summary?
      boolean_value('checklist_show_summary', true)
    end

    def checklist_auto_apply_templates?
      boolean_value('checklist_auto_apply_templates', true)
    end

    def due_soon_days
      integer_value('due_soon_days', 7, 1, 90)
    end

    def planner_months
      integer_value('planner_months', 4, 1, 12)
    end

    def planner_day_width
      integer_value('planner_day_width', 28, 20, 48)
    end

    def planner_default_scale
      value = raw_settings['planner_default_scale'].to_s
      %w[day week month quarter].include?(value) ? value : 'month'
    end

    def planner_show_relations?
      boolean_value('planner_show_relations', true)
    end

    def planner_show_legend?
      boolean_value('planner_show_legend', true)
    end

    def planner_show_unscheduled?
      boolean_value('planner_show_unscheduled', true)
    end

    def planner_show_editor?
      boolean_value('planner_show_editor', true)
    end

    def ui_density
      value = raw_settings['ui_density'].to_s
      %w[comfortable compact].include?(value) ? value : 'comfortable'
    end

    def compact_density?
      ui_density == 'compact'
    end

    def ui_accent_color
      color_value('ui_accent_color', '#0f5f9c')
    end

    def ui_accent_soft_color
      color_value('ui_accent_soft_color', '#e8f2ff')
    end

    def gantt_bar_color_start
      color_value('gantt_bar_color_start', '#155eef')
    end

    def gantt_bar_color_end
      color_value('gantt_bar_color_end', '#0f5f9c')
    end

    def gantt_closed_bar_color_start
      color_value('gantt_closed_bar_color_start', '#64748b')
    end

    def gantt_closed_bar_color_end
      color_value('gantt_closed_bar_color_end', '#475569')
    end

    def gantt_relation_color
      color_value('gantt_relation_color', '#0f5f9c')
    end

    def gantt_today_color
      color_value('gantt_today_color', '#0f5f9c')
    end

    def gantt_version_marker_color
      color_value('gantt_version_marker_color', '#f4a261')
    end

    def weekend_tint_color
      color_value('weekend_tint_color', '#f7f8fa')
    end

    def panel_radius
      integer_value('panel_radius', 18, 12, 28)
    end

    def card_radius
      integer_value('card_radius', 16, 10, 24)
    end

    def board_wip_limits_for(statuses)
      rules = parsed_wip_limits
      Array(statuses).each_with_object({}) do |status, hash|
        hash[status.id] = rules[status.id.to_s] || rules[status.name.to_s.downcase]
      end
    end

    private

    def integer_value(key, fallback, minimum, maximum)
      value = raw_settings[key].to_i
      value = fallback if value <= 0
      [[value, minimum].max, maximum].min
    end

    def boolean_value(key, fallback)
      value = raw_settings[key]
      return fallback if value.nil?

      %w[1 true t yes on].include?(value.to_s.downcase)
    end

    def color_value(key, fallback)
      value = raw_settings[key].to_s.strip
      value.match?(/\A#(?:\h{3}|\h{6})\z/) ? value : fallback
    end

    def raw_settings
      values =
        if Setting.respond_to?(:plugin_redmine_flow_planner)
          Setting.plugin_redmine_flow_planner || {}
        else
          {}
        end

      DEFAULTS.merge(values.transform_keys(&:to_s))
    end

    def parsed_wip_limits
      raw_settings['board_wip_limits'].to_s.lines.each_with_object({}) do |line, hash|
        entry = line.strip
        next if entry.blank?

        key, value = entry.split(/[=:]/, 2).map {|part| part.to_s.strip}
        next if key.blank?

        limit = value.to_i
        next unless limit.positive?

        hash[key] = limit
        hash[key.downcase] = limit
      end
    end
  end
end
