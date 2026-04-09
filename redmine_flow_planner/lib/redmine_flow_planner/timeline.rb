# frozen_string_literal: true

module RedmineFlowPlanner
  class Timeline
    MAX_MONTHS = 12
    MAX_RANGE_DAYS = 186

    attr_reader :start_date, :end_date, :months_count, :range_days

    def initialize(params:, issues:, default_months:)
      custom_start = parse_date(params[:start])
      custom_end = parse_date(params[:end])

      if custom_start || custom_end
        @start_date = custom_start || custom_end || current_month
        @end_date = custom_end || custom_start || @start_date
        @end_date = @start_date if @end_date < @start_date
        @end_date = [@end_date, @start_date + (MAX_RANGE_DAYS - 1)].min
        @range_days = ((@end_date - @start_date).to_i + 1)
        @months_count = month_span(@start_date, @end_date)
        @custom_range = true
      else
        @months_count = clamped_integer(params[:months], preset_months(params[:scale], default_months), 1, MAX_MONTHS)
        @start_date = extract_start_date(params, issues)
        @end_date = (@start_date >> @months_count) - 1
        @range_days = total_days
        @custom_range = false
      end
    end

    def days
      @days ||= (@start_date..@end_date).to_a
    end

    def month_segments
      @month_segments ||=
        begin
          segments = []
          cursor = @start_date
          while cursor <= @end_date
            segment_end = [end_of_month(cursor), @end_date].min
            segments << {date: cursor, days: (segment_end - cursor).to_i + 1}
            cursor = segment_end + 1
          end
          segments
        end
    end

    def total_days
      (@end_date - @start_date).to_i + 1
    end

    def total_width(day_width)
      total_days * day_width
    end

    def previous_params
      if custom_range?
        previous_start = @start_date - @range_days
        previous_end = @end_date - @range_days
        {start: previous_start.iso8601, end: previous_end.iso8601}
      else
        date = @start_date << @months_count
        {year: date.year, month: date.month, months: @months_count}
      end
    end

    def next_params
      if custom_range?
        next_start = @start_date + @range_days
        next_end = @end_date + @range_days
        {start: next_start.iso8601, end: next_end.iso8601}
      else
        date = @start_date >> @months_count
        {year: date.year, month: date.month, months: @months_count}
      end
    end

    def visible?(start_date, end_date)
      start_date <= @end_date && end_date >= @start_date
    end

    def custom_range?
      @custom_range
    end

    private

    def extract_start_date(params, issues)
      year = params[:year].to_i
      month = clamped_integer(params[:month], current_month.month, 1, 12)

      return Date.civil(year, month, 1) if year.positive?

      seed = issues.filter_map {|issue| issue.start_date || issue.due_date}.min
      seed ? Date.civil(seed.year, seed.month, 1) : current_month
    end

    def current_month
      today = User.current.today
      Date.civil(today.year, today.month, 1)
    end

    def parse_date(value)
      return if value.blank?

      Date.iso8601(value.to_s)
    rescue StandardError
      nil
    end

    def month_span(start_date, end_date)
      months = ((end_date.year * 12) + end_date.month) - ((start_date.year * 12) + start_date.month) + 1
      [[months, 1].max, MAX_MONTHS].min
    end

    def end_of_month(date)
      (Date.civil(date.year, date.month, 1) >> 1) - 1
    end

    def clamped_integer(raw_value, fallback, minimum, maximum)
      value = raw_value.to_i
      value = fallback.to_i if value <= 0
      [[value, minimum].max, maximum].min
    end

    def preset_months(scale_name, fallback)
      case scale_name.to_s
      when 'day'
        1
      when 'week'
        2
      when 'month'
        4
      when 'quarter'
        8
      else
        fallback
      end
    end
  end
end
