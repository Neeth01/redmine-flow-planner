# frozen_string_literal: true

class AgileBoardsController < ApplicationController
  BOARD_SORTS = %w[priority due_date updated_on done_ratio subject id].freeze
  BOARD_SORT_LABELS = {
    'priority' => :label_flow_sort_priority,
    'due_date' => :label_flow_sort_due_date,
    'updated_on' => :label_flow_sort_updated_on,
    'done_ratio' => :label_flow_sort_done_ratio,
    'subject' => :label_flow_sort_subject,
    'id' => :label_flow_sort_id
  }.freeze

  menu_item :agile_board

  before_action :find_optional_project
  before_action :authorize
  before_action :ensure_project!, only: :create_issue
  before_action :find_issue_for_update, only: :update_issue

  helper :issues
  helper :projects
  helper :queries
  helper :flow_planner
  include QueriesHelper

  rescue_from Query::StatementInvalid, with: :query_statement_invalid
  rescue_from Query::QueryError, with: :query_error
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  def index
    @settings = RedmineFlowPlanner.settings
    retrieve_query(IssueQuery, true)
    @query.group_by = nil if @query
    @issue_count = @query.issue_count
    @board_sort = params[:sort].presence
    @board_sort = @settings.board_default_sort unless BOARD_SORTS.include?(@board_sort)
    @issues = @query.issues(
      limit: @settings.board_limit,
      include: [:tracker, :assigned_to, :priority, :fixed_version, :author]
    )
    @truncated = @issue_count > @issues.size
    @statuses = board_statuses(@issues)
    @wip_limits = @settings.board_wip_limits_for(@statuses)
    @board_columns = build_board_columns(@statuses, @issues, @board_sort, @wip_limits)
    @board_sort_options = board_sort_options
    @filter_options = filter_collection(@issues)
    @quick_create_options = quick_create_options
    @can_manage_board = User.current.allowed_to?(:manage_agile_board, @project)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def create_issue
    @settings = RedmineFlowPlanner.settings
    @issue = Issue.new(project: @project, author: User.current)
    apply_issue_tracker(@issue, params.dig(:issue, :tracker_id))
    @issue.safe_attributes = board_issue_attributes(@issue)

    if @issue.save
      @can_manage_board = User.current.allowed_to?(:manage_agile_board, @project)
      render json: {
        issue: issue_payload(@issue),
        html: render_to_string(partial: 'card', formats: [:html], locals: {issue: @issue}),
        message: l(:notice_successful_create)
      }
    else
      render json: {errors: @issue.errors.full_messages}, status: :unprocessable_content
    end
  end

  def update_issue
    @issue.init_journal(User.current)
    apply_issue_tracker(@issue, params.dig(:issue, :tracker_id))
    @issue.safe_attributes = board_issue_attributes(@issue)

    if @issue.save
      render json: {issue: issue_payload(@issue), message: l(:notice_successful_update)}
    else
      render json: {errors: @issue.errors.full_messages}, status: :unprocessable_content
    end
  end

  private

  def board_statuses(issues)
    issue_status_ids = Array(issues).map(&:status_id).compact
    project_status_ids =
      Array(@project&.trackers).flat_map do |tracker|
        tracker.respond_to?(:issue_status_ids) ? tracker.issue_status_ids : []
      end

    IssueStatus.where(id: (issue_status_ids + project_status_ids).uniq).order(:position, :name).to_a
  rescue StandardError
    Array(issues).map(&:status).compact.uniq.sort_by {|status| [status.respond_to?(:position) ? status.position.to_i : 0, status.name.to_s]}
  end

  def board_issue_attributes(issue = @issue)
    issue_params = params.require(:issue)
    safe_names = issue.safe_attribute_names(User.current).map(&:to_s)
    attributes = {}

    if issue_params.key?(:status_id) && safe_names.include?('status_id')
      attributes['status_id'] = issue_params[:status_id]
    end

    if issue_params.key?(:assigned_to_id) && safe_names.include?('assigned_to_id')
      value = issue_params[:assigned_to_id].to_s
      value = User.current.id.to_s if value == 'me'
      attributes['assigned_to_id'] = value
    end

    if issue_params.key?(:done_ratio) && safe_names.include?('done_ratio')
      attributes['done_ratio'] = issue_params[:done_ratio].to_i.clamp(0, 100)
    end

    if issue_params.key?(:subject) && safe_names.include?('subject')
      attributes['subject'] = issue_params[:subject].to_s.strip
    end

    if issue_params.key?(:due_date) && safe_names.include?('due_date')
      attributes['due_date'] = issue_params[:due_date].presence
    end

    if issue_params.key?(:priority_id) && safe_names.include?('priority_id')
      attributes['priority_id'] = issue_params[:priority_id].presence
    end

    if issue_params.key?(:fixed_version_id) && safe_names.include?('fixed_version_id')
      attributes['fixed_version_id'] = issue_params[:fixed_version_id].presence
    end

    raise ActionController::ParameterMissing, :issue if attributes.empty?

    attributes
  end

  def issue_payload(issue)
    settings = @settings || RedmineFlowPlanner.settings

    {
      id: issue.id,
      subject: issue.subject,
      status_id: issue.status_id,
      status_name: issue.status.name,
      tracker_id: issue.tracker_id,
      tracker_name: issue.tracker&.name,
      priority_id: issue.priority_id,
      priority_name: issue.priority&.name,
      assigned_to_id: issue.assigned_to_id,
      assigned_to_name: issue.assigned_to&.name,
      fixed_version_id: issue.fixed_version_id,
      fixed_version_name: issue.fixed_version&.name,
      due_date: issue.due_date&.iso8601,
      due_label: view_context.flow_due_label(issue, settings.due_soon_days),
      done_ratio: issue.done_ratio,
      overdue: issue.overdue?,
      closed: issue.closed?,
      estimated_hours: issue.respond_to?(:estimated_hours) ? issue.estimated_hours.to_f : 0.0,
      spent_hours: issue.respond_to?(:spent_hours) ? issue.spent_hours.to_f : 0.0,
      updated_on: issue.updated_on&.iso8601
    }
  end

  def board_metrics(issues)
    due_soon_days = @settings.due_soon_days

    {
      total: issues.size,
      open: issues.count {|issue| !issue.closed?},
      overdue: issues.count(&:overdue?),
      unassigned: issues.count {|issue| issue.assigned_to.blank?},
      due_soon: issues.count do |issue|
        issue.due_date.present? &&
          !issue.closed? &&
          issue.due_date >= User.current.today &&
          (issue.due_date - User.current.today).to_i <= due_soon_days
      end,
      closed: issues.count(&:closed?)
    }
  end

  def filter_collection(issues)
    {
      trackers: issues.map(&:tracker).compact.uniq.sort_by(&:name),
      assignees: issues.map(&:assigned_to).compact.uniq.sort_by(&:name)
    }
  end

  def build_board_columns(statuses, issues, sort_name, wip_limits)
    Array(statuses).map do |status|
      column_issues = Array(issues).select {|issue| issue.status_id == status.id}.sort_by {|issue| board_sort_key(issue, sort_name)}
      count = column_issues.size
      limit = wip_limits[status.id]

      {
        status: status,
        issues: column_issues,
        count: count,
        wip_limit: limit,
        wip_state: board_wip_state(count, limit)
      }
    end
  end

  def board_sort_options
    BOARD_SORT_LABELS.map {|value, label| [l(label), value]}
  end

  def board_sort_key(issue, sort_name)
    closed_weight = issue.closed? ? 1 : 0
    priority_position =
      if issue.priority && issue.priority.respond_to?(:position)
        issue.priority.position.to_i
      else
        0
      end

    case sort_name.to_s
    when 'due_date'
      [closed_weight, issue.due_date || Date.new(9999, 12, 31), -priority_position, issue.id]
    when 'updated_on'
      [closed_weight, issue.updated_on ? -issue.updated_on.to_i : 0, issue.id]
    when 'done_ratio'
      [closed_weight, -(issue.done_ratio || 0), issue.due_date || Date.new(9999, 12, 31), issue.id]
    when 'subject'
      [closed_weight, issue.subject.to_s.downcase, issue.id]
    when 'id'
      [closed_weight, issue.id]
    else
      [closed_weight, -priority_position, issue.due_date || Date.new(9999, 12, 31), issue.id]
    end
  end

  def board_wip_state(count, limit)
    return :none unless limit.to_i.positive?
    return :alert if count > limit.to_i
    return :warning if count == limit.to_i

    :ok
  end

  def find_issue_for_update
    @issue = Issue.find(params[:id])
    raise Unauthorized unless @issue.visible?
    raise ActiveRecord::RecordNotFound unless issue_in_scope?(@issue)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def quick_create_options
    {
      trackers: available_trackers.map {|tracker| [tracker.name, tracker.id]},
      assignees: available_assignees.map {|user| [user.name, user.id]},
      priorities: available_priorities.map {|priority| [priority.name, priority.id]},
      versions: available_versions.map {|version| [version.name, version.id]}
    }
  end

  def available_trackers
    return [] unless @project

    @project.trackers.to_a.sort_by(&:name)
  rescue StandardError
    @issues.map(&:tracker).compact.uniq.sort_by(&:name)
  end

  def available_assignees
    return @filter_options[:assignees] if @filter_options.present?

    Array(@project&.users).uniq.sort_by(&:name)
  end

  def available_priorities
    IssuePriority.all.sort_by do |priority|
      priority.respond_to?(:position) ? priority.position.to_i : priority.id.to_i
    end
  rescue StandardError
    []
  end

  def available_versions
    return [] unless @project

    project_ids = Project.where('lft >= ? AND rgt <= ?', @project.lft, @project.rgt).pluck(:id)
    Version.where(project_id: project_ids).order(:effective_date, :name).to_a
  rescue StandardError
    []
  end

  def apply_issue_tracker(issue, tracker_id)
    return if tracker_id.blank?
    return unless @project

    tracker = available_trackers.find {|item| item.id.to_s == tracker_id.to_s}
    issue.tracker = tracker if tracker
  end

  def ensure_project!
    render_404 unless @project
  end

  def issue_in_scope?(issue)
    return true unless @project

    issue.project_id == @project.id ||
      (issue.project.lft >= @project.lft && issue.project.rgt <= @project.rgt)
  end

  def render_bad_request(exception)
    render json: {errors: [exception.message]}, status: :unprocessable_content
  end
end
