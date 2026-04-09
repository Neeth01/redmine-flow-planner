# frozen_string_literal: true

module RedmineFlowPlanner
  class Settings
    DEFAULTS = {
      'board_limit' => '200',
      'board_default_sort' => 'priority',
      'board_wip_limits' => '',
      'due_soon_days' => '7',
      'planner_limit' => '250',
      'planner_months' => '4',
      'planner_day_width' => '28'
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

    def due_soon_days
      integer_value('due_soon_days', 7, 1, 90)
    end

    def planner_months
      integer_value('planner_months', 4, 1, 12)
    end

    def planner_day_width
      integer_value('planner_day_width', 28, 20, 48)
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
