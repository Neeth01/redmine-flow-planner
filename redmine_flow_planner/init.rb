# frozen_string_literal: true

require_relative 'lib/redmine_flow_planner'
require_relative 'app/models/flow_checklist_item'
require_relative 'app/models/flow_checklist_template'
require_relative 'app/helpers/flow_planner_helper'
require_relative 'lib/redmine_flow_planner/issue_patch'
require_relative 'lib/redmine_flow_planner/hooks'

Rails.configuration.to_prepare do
  require_dependency 'issue'
  Issue.include RedmineFlowPlanner::IssuePatch unless Issue.included_modules.include?(RedmineFlowPlanner::IssuePatch)
end

Redmine::Plugin.register :redmine_flow_planner do
  name 'Redmine Flow Planner'
  author 'SPRUNGARD Jonas'
  description 'Agile board and interactive planning Gantt for Redmine projects.'
  version '0.1.0'
  url 'https://github.com/Neeth01'
  author_url 'https://github.com/Neeth01'

  requires_redmine version_or_higher: '6.1.2'

  settings default: RedmineFlowPlanner::Settings::DEFAULTS,
           partial: 'settings/redmine_flow_planner_settings'

  project_module :flow_planner do
    permission :view_agile_board, agile_boards: [:index]
    permission :manage_agile_board, agile_boards: [:create_issue, :update_issue]
    permission :view_planning_gantt, planning_gantts: [:index]
    permission :manage_planning_gantt, planning_gantts: [:update_issue]
    permission :view_flow_checklists, flow_checklist_items: [:index]
    permission :manage_flow_checklists, flow_checklist_items: [:create, :update, :destroy, :reorder]
  end

  menu :project_menu,
       :agile_board,
       {controller: 'agile_boards', action: 'index'},
       caption: :label_agile_board,
       after: :issues,
       param: :project_id

  menu :project_menu,
       :planning_gantt,
       {controller: 'planning_gantts', action: 'index'},
       caption: :label_planning_gantt,
       after: :agile_board,
       param: :project_id

  menu :top_menu,
       :flow_global_agile_board,
       {controller: 'agile_boards', action: 'index'},
       caption: :label_flow_global_agile_board,
       after: :projects

  menu :top_menu,
       :flow_global_planning_gantt,
       {controller: 'planning_gantts', action: 'index'},
       caption: :label_flow_global_planning_gantt,
       after: :flow_global_agile_board

  menu :admin_menu,
       :flow_checklist_templates,
       {controller: 'flow_checklist_templates', action: 'index'},
       caption: :label_flow_checklist_templates,
       html: {class: 'icon icon-issue'}
end
