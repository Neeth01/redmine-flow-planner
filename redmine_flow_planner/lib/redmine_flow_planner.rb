# frozen_string_literal: true

require_relative 'redmine_flow_planner/settings'
require_relative 'redmine_flow_planner/timeline'

module RedmineFlowPlanner
  PLUGIN_ID = :redmine_flow_planner

  module_function

  def settings
    Settings.new
  end
end
