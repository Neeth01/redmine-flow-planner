# frozen_string_literal: true

module RedmineFlowPlanner
  class Hooks < Redmine::Hook::ViewListener
    include FlowPlannerHelper

    def view_welcome_index_left(context = {})
      render_home_dashboard(context)
    end

    def view_issues_show_details_bottom(context = {})
      render_checklist_panel(context)
    end

    def view_layouts_base_html_head(context = {})
      return ''.html_safe unless issue_show_page?(context)

      stylesheet_link_tag('redmine_flow_checklists', plugin: 'redmine_flow_planner')
    end

    def view_layouts_base_body_bottom(context = {})
      return ''.html_safe unless issue_show_page?(context)

      javascript_include_tag('redmine_flow_checklists', plugin: 'redmine_flow_planner')
    end

    private

    def issue_show_page?(context)
      controller = context[:controller]
      controller.present? &&
        controller.controller_name.to_s == 'issues' &&
        controller.action_name.to_s == 'show'
    end

    def render_home_dashboard(context)
      controller = context[:controller]
      return ''.html_safe unless controller.is_a?(ActionController::Base)

      controller.render_to_string(
        partial: 'flow_home/dashboard',
        formats: [:html],
        locals: home_dashboard_locals
      )
    rescue StandardError => error
      Rails.logger.error(
        "[redmine_flow_planner] home dashboard render failed: #{error.class}: #{error.message}"
      )
      ''.html_safe
    end

    def home_dashboard_locals
      visible_projects_scope = Project.visible
      open_status_ids = IssueStatus.where(is_closed: false).select(:id)
      open_issues_scope = Issue.visible.where(status_id: open_status_ids)
      assigned_scope =
        if User.current.logged?
          open_issues_scope.where(assigned_to_id: User.current.id)
        else
          Issue.none
        end

      visible_projects = visible_projects_scope.order(updated_on: :desc).limit(6).to_a
      open_counts_by_project =
        if visible_projects.any?
          open_issues_scope.where(project_id: visible_projects.map(&:id)).group(:project_id).count
        else
          {}
        end

      {
        metrics: {
          projects: visible_projects_scope.count,
          open_issues: open_issues_scope.count,
          assigned: assigned_scope.count,
          overdue: open_issues_scope.where.not(due_date: nil).where('due_date < ?', User.current.today).count,
          scheduled: open_issues_scope.where('start_date IS NOT NULL OR due_date IS NOT NULL').count
        },
        priority_issues: load_home_priority_issues(open_issues_scope, assigned_scope),
        recent_issues: load_home_recent_issues,
        projects: visible_projects.map do |project|
          {
            record: project,
            open_count: open_counts_by_project[project.id].to_i,
            style: flow_project_style(project)
          }
        end,
        user_logged: User.current.logged?,
        admin_mode: User.current.admin?,
        templates_table_available: checklist_templates_available?,
        templates_count: checklist_templates_count
      }
    end

    def load_home_priority_issues(open_issues_scope, assigned_scope)
      scoped =
        if User.current.logged? && assigned_scope.exists?
          assigned_scope
        else
          open_issues_scope
        end

      issues =
        scoped
          .includes(:project, :tracker, :status, :assigned_to)
          .where.not(due_date: nil)
          .order(:due_date, updated_on: :desc)
          .limit(6)
          .to_a

      return issues if issues.any?

      scoped
        .includes(:project, :tracker, :status, :assigned_to)
        .order(updated_on: :desc)
        .limit(6)
        .to_a
    end

    def load_home_recent_issues
      Issue.visible
        .includes(:project, :tracker, :status, :assigned_to)
        .order(updated_on: :desc)
        .limit(7)
        .to_a
    end

    def checklist_templates_available?
      FlowChecklistTemplate.table_exists?
    rescue StandardError
      false
    end

    def checklist_templates_count
      return nil unless checklist_templates_available?

      FlowChecklistTemplate.active.count
    rescue StandardError
      nil
    end

    def render_checklist_panel(context)
      issue = context[:issue]
      controller = context[:controller]

      return ''.html_safe unless issue.present?
      return ''.html_safe unless checklist_visible?(issue)
      return ''.html_safe unless controller.is_a?(ActionController::Base)

      items = checklist_items(issue)
      stats = checklist_stats(items)
      templates = checklist_templates(issue)

      controller.render_to_string(
        partial: 'flow_checklist_items/panel',
        formats: [:html],
        locals: {
          issue: issue,
          items: items,
          stats: stats,
          templates: templates,
          can_manage_checklist: can_manage_checklist?(issue)
        }
      )
    rescue StandardError => error
      Rails.logger.error(
        "[redmine_flow_planner] checklist hook render failed for issue ##{issue&.id}: #{error.class}: #{error.message}"
      )
      ''.html_safe
    end

    def checklist_visible?(issue)
      return false unless FlowChecklistItem.table_exists?

      User.current.admin? || User.current.allowed_to?(:view_flow_checklists, issue.project)
    rescue StandardError
      false
    end

    def can_manage_checklist?(issue)
      User.current.admin? || User.current.allowed_to?(:manage_flow_checklists, issue.project)
    end

    def checklist_items(issue)
      FlowChecklistItem.where(issue_id: issue.id).order(:position, :id).to_a
    rescue StandardError
      []
    end

    def checklist_templates(issue)
      return [] unless checklist_templates_available?

      FlowChecklistTemplate.matching(issue).to_a
    rescue StandardError
      []
    end

    def checklist_stats(items)
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
    end
  end
end
