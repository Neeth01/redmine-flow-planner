# frozen_string_literal: true

class PlanningGanttsController < ApplicationController
  SCALE_PRESETS = {
    'day' => {months: 1, day_width: 40},
    'week' => {months: 2, day_width: 28},
    'month' => {months: 4, day_width: 24},
    'quarter' => {months: 8, day_width: 20}
  }.freeze

  menu_item :planning_gantt

  before_action :find_optional_project
  before_action :authorize_planning_view!
  before_action :find_issue_for_update, only: :update_issue
  before_action :authorize_planning_manage!, only: :update_issue

  helper :planning_gantts
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
    @scale_preset = scale_preset_name
    retrieve_query(IssueQuery, true)
    @query.group_by = nil if @query
    @query_total = @query.issue_count
    raw_issues = @query.issues(
      limit: query_limit,
      include: [:tracker, :assigned_to, :priority, :fixed_version, :author]
    )
    authorized_issues = filter_authorized_issues(raw_issues)
    @all_issues = authorized_issues.first(@settings.planner_limit)
    @timeline = RedmineFlowPlanner::Timeline.new(
      params: params,
      issues: @all_issues,
      default_months: @settings.planner_months
    )
    @day_width = day_width_from_params
    @scheduled_issues, @unscheduled_issues = @all_issues.partition {|issue| issue_schedule(issue).present?}
    @issues = @scheduled_issues.select {|issue| issue_visible_on_timeline?(issue)}
    @children_by_parent = build_children_map(@issues)
    @issues = ordered_visible_issues(@issues, @children_by_parent)
    @row_depths = issue_depths(@issues)
    @outside_window_count = @scheduled_issues.size - @issues.size
    @issue_count = @all_issues.size
    @truncated = authorized_issues.size > @all_issues.size || @query_total > @all_issues.size
    @dependency_relations = dependency_relations(@issues)
    # Compute critical path for visible issues and mark relations
    cp = compute_critical_path(@issues, @dependency_relations)
    @critical_issue_ids = cp[:issues]
    # Annotate relations with critical flag for the view
    if @dependency_relations && cp[:relations]
      rel_set = cp[:relations].map {|pair| [pair[0], pair[1]]}
      @dependency_relations.each do |r|
        r[:critical] = rel_set.include?([r[:from_id], r[:to_id]])
      end
    end
    @filter_options = filter_collection(@all_issues)
    @version_markers = version_markers(@all_issues)
    @planning_editor_options = {
      assignees: @filter_options[:assignees],
      versions: available_versions
    }
    @can_manage_planning = @all_issues.any? {|issue| can_manage_planning_for?(issue.project)} || can_manage_planning_for?(@project)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def update_issue
    @issue.init_journal(User.current)
    @issue.safe_attributes = schedule_issue_attributes

    if @issue.save
      render json: {issue: issue_payload(@issue), message: l(:notice_successful_update)}
    else
      render json: {errors: @issue.errors.full_messages}, status: :unprocessable_content
    end
  end

  private

  def schedule_issue_attributes
    issue_params = params.require(:issue)
    safe_names = @issue.safe_attribute_names(User.current).map(&:to_s)

    attributes = {}

    # Accept start_date/due_date when provided and allowed
    if issue_params.key?(:start_date) && safe_names.include?('start_date')
      attributes['start_date'] = issue_params[:start_date]
    end

    if issue_params.key?(:due_date) && safe_names.include?('due_date')
      attributes['due_date'] = issue_params[:due_date]
    end

    if issue_params.key?(:subject) && safe_names.include?('subject')
      attributes['subject'] = issue_params[:subject].to_s.strip
    end

    if issue_params.key?(:assigned_to_id) && safe_names.include?('assigned_to_id')
      attributes['assigned_to_id'] = issue_params[:assigned_to_id].presence
    end

    if issue_params.key?(:fixed_version_id) && safe_names.include?('fixed_version_id')
      attributes['fixed_version_id'] = issue_params[:fixed_version_id].presence
    end

    # Accept done_ratio updates when allowed
    if issue_params.key?(:done_ratio) && safe_names.include?('done_ratio')
      attributes['done_ratio'] = issue_params[:done_ratio].to_i.clamp(0, 100)
    end

    raise ActionController::ParameterMissing, :issue if attributes.empty?

    attributes
  end

  def issue_payload(issue)
    {
      id: issue.id,
      subject: issue.subject,
      start_date: issue.start_date&.iso8601,
      due_date: issue.due_date&.iso8601,
      schedule_label: view_context.flow_schedule_label(issue),
      status_name: issue.status&.name,
      assigned_to_id: issue.assigned_to_id,
      assigned_to_name: issue.assigned_to&.name,
      fixed_version_id: issue.fixed_version_id,
      fixed_version_name: issue.fixed_version&.name,
      tracker_id: issue.tracker_id,
      tracker_name: issue.tracker&.name,
      priority_id: issue.priority_id,
      priority_name: issue.priority&.name,
      project_id: issue.project_id,
      project_name: issue.project&.name,
      done_ratio: issue.done_ratio,
      critical: @critical_issue_ids && @critical_issue_ids.include?(issue.id),
      overdue: issue.overdue?,
      closed: issue.closed?,
      updated_on: issue.updated_on&.iso8601
    }
  end

  # Compute a simple Critical Path Method over the supplied issues and relations.
  # Returns a hash with :issues => [issue_id,...] (critical nodes) and :relations => [[from_id,to_id],...]
  def compute_critical_path(issues, relations)
    return {issues: [], relations: []} unless issues && issues.any?

    # Build node map with duration in days
    nodes = {}
    issues.each do |issue|
      dur = 1
      if issue.start_date && issue.due_date
        dur = (issue.due_date - issue.start_date).to_i + 1
        dur = 1 if dur <= 0
      end
      nodes[issue.id] = {issue: issue, dur: dur, preds: [], succs: []}
    end

    # Build adjacency
    Array(relations).each do |r|
      from = r[:from_id]
      to = r[:to_id]
      next unless nodes.key?(from) && nodes.key?(to)
      nodes[from][:succs] << to
      nodes[to][:preds] << from
    end

    # Topological sort (Kahn)
    indeg = {}
    nodes.each { |id, n| indeg[id] = n[:preds].size }
    queue = indeg.select { |k, v| v == 0 }.map { |k, _| k }
    topo = []
    until queue.empty?
      n = queue.shift
      topo << n
      nodes[n][:succs].each do |m|
        indeg[m] -= 1
        queue << m if indeg[m] == 0
      end
    end

    # If cycle detected, abort
    return {issues: [], relations: []} unless topo.size == nodes.size

    # Forward pass: earliest start (ES)
    es = {}
    topo.each do |id|
      if nodes[id][:preds].empty?
        es[id] = 0
      else
        es[id] = nodes[id][:preds].map { |p| es[p] + nodes[p][:dur] }.max || 0
      end
    end

    ef = {}
    nodes.each { |id, n| ef[id] = es[id] + n[:dur] }
    project_finish = ef.values.max || 0

    # Backward pass: latest finish (LF) and latest start (LS)
    lf = {}
    ls = {}
    nodes.keys.each { |id| lf[id] = project_finish }
    topo.reverse.each do |id|
      if nodes[id][:succs].empty?
        lf[id] = project_finish
      else
        min_succ_ls = nodes[id][:succs].map { |s| lf[s] - nodes[s][:dur] }.min
        lf[id] = min_succ_ls
      end
      ls[id] = lf[id] - nodes[id][:dur]
    end

    critical_nodes = nodes.keys.select { |id| es[id] == ls[id] }

    # Mark relations that are on critical path: from and to are critical and EF[from] == ES[to]
    critical_relations = []
    Array(relations).each do |r|
      from = r[:from_id]; to = r[:to_id]
      if critical_nodes.include?(from) && critical_nodes.include?(to)
        if (es[from] + nodes[from][:dur]) == es[to]
          critical_relations << [from, to]
        end
      end
    end

    {issues: critical_nodes, relations: critical_relations}
  end

  def issue_schedule(issue)
    start_date = issue.start_date || issue.due_date
    due_date = issue.due_date || issue.start_date
    return if start_date.blank? || due_date.blank?

    [start_date, due_date]
  end

  def issue_visible_on_timeline?(issue)
    schedule = issue_schedule(issue)
    schedule && @timeline.visible?(schedule.first, schedule.last)
  end

  def day_width_from_params
    value = params[:day_width].to_i
    value = scale_preset_options[:day_width] if value <= 0 && scale_preset_options
    return @settings.planner_day_width unless value.positive?

    [[value, 20].max, 48].min
  end

  def scale_preset_name
    name = params[:scale].presence.to_s
    name = @settings.planner_default_scale if name.blank? && defined?(@settings) && @settings
    SCALE_PRESETS.key?(name) ? name : nil
  end

  def scale_preset_options
    @scale_preset ? SCALE_PRESETS[@scale_preset] : nil
  end

  def planning_metrics(all_issues, visible_issues, relations)
    {
      total: all_issues.size,
      scheduled: all_issues.count {|issue| issue_schedule(issue).present?},
      unscheduled: all_issues.count {|issue| issue_schedule(issue).blank?},
      visible: visible_issues.size,
      dependencies: Array(relations).size,
      overdue: all_issues.count(&:overdue?),
      unassigned: all_issues.count {|issue| issue.assigned_to.blank?},
      versions: all_issues.map(&:fixed_version).compact.uniq.size
    }
  end

  def filter_collection(issues)
    {
      projects: issues.map(&:project).compact.uniq.sort_by(&:name),
      trackers: issues.map(&:tracker).compact.uniq.sort_by(&:name),
      assignees: issues.map(&:assigned_to).compact.uniq.sort_by(&:name)
    }
  end

  def version_markers(issues)
    issues.map(&:fixed_version).compact.uniq.filter_map do |version|
      next unless version.due_date.present?
      next unless version.due_date.between?(@timeline.start_date, @timeline.end_date)

      {id: version.id, name: version.name, due_date: version.due_date}
    end.sort_by {|marker| [marker[:due_date], marker[:name].to_s.downcase]}
  end

  def build_children_map(issues)
    index = Array(issues).index_by(&:id)
    Array(issues).each_with_object(Hash.new {|hash, key| hash[key] = []}) do |issue, hash|
      next unless issue.parent_id.present? && index.key?(issue.parent_id)

      hash[issue.parent_id] << issue
    end
  end

  def ordered_visible_issues(issues, children_by_parent)
    index = Array(issues).index_by(&:id)
    roots = Array(issues).select {|issue| issue.parent_id.blank? || !index.key?(issue.parent_id)}
    ordered = []

    visit = lambda do |issue|
      ordered << issue
      Array(children_by_parent[issue.id]).sort_by {|child| issue_order_key(child)}.each do |child|
        visit.call(child)
      end
    end

    roots.sort_by {|issue| issue_order_key(issue)}.each do |root_issue|
      visit.call(root_issue)
    end

    ordered
  end

  def issue_depths(issues)
    index = Array(issues).index_by(&:id)
    Array(issues).each_with_object({}) do |issue, hash|
      depth = 0
      current_parent_id = issue.parent_id
      seen = {}

      while current_parent_id.present? && index.key?(current_parent_id) && !seen[current_parent_id]
        seen[current_parent_id] = true
        depth += 1
        current_parent_id = index[current_parent_id].parent_id
      end

      hash[issue.id] = depth
    end
  end

  def dependency_relations(issues)
    issue_ids = Array(issues).map(&:id)
    return [] if issue_ids.size < 2

    IssueRelation.where(issue_from_id: issue_ids, issue_to_id: issue_ids, relation_type: %w[precedes blocks relates])
                 .order(:issue_from_id, :issue_to_id)
                 .map do |relation|
      {
        from_id: relation.issue_from_id,
        to_id: relation.issue_to_id,
        relation_type: relation.relation_type,
        delay: relation.delay.to_i
      }
    end
  rescue StandardError
    []
  end

  def issue_order_key(issue)
    schedule = issue_schedule(issue)
    [schedule.first, schedule.last, issue.lft || issue.id, issue.id]
  end

  def available_versions
    return @all_issues.map(&:fixed_version).compact.uniq.sort_by {|version| [version.effective_date || Date.new(9999, 12, 31), version.name.to_s.downcase]} unless @project

    project_ids = Project.where('lft >= ? AND rgt <= ?', @project.lft, @project.rgt).pluck(:id)
    Version.where(project_id: project_ids).order(:effective_date, :name).to_a
  rescue StandardError
    []
  end

  def find_issue_for_update
    @issue = Issue.find(params[:id])
    raise Unauthorized unless @issue.visible?
    raise ActiveRecord::RecordNotFound unless issue_in_scope?(@issue)
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def issue_in_scope?(issue)
    return true unless @project

    issue.project_id == @project.id ||
      (issue.project.lft >= @project.lft && issue.project.rgt <= @project.rgt)
  end

  def authorize_planning_view!
    return if can_view_planning_for?(@project)
    return if @project.blank? && global_planning_projects.any?

    raise Unauthorized
  end

  def authorize_planning_manage!
    scope_project = @issue&.project || @project
    raise Unauthorized unless can_manage_planning_for?(scope_project)
  end

  def can_view_planning_for?(project)
    return true if User.current.admin?
    return false if project.blank?

    User.current.allowed_to?(:view_planning_gantt, project)
  end

  def can_manage_planning_for?(project)
    return true if User.current.admin?
    return false if project.blank?

    User.current.allowed_to?(:manage_planning_gantt, project)
  end

  def global_planning_projects
    @global_planning_projects ||= selectable_projects_for(:view_planning_gantt)
  end

  def selectable_projects_for(permission)
    scope = Project.visible
    scope = scope.has_module(:flow_planner) if scope.respond_to?(:has_module)
    return scope.order(:name).to_a if User.current.admin?

    scope.order(:name).select {|project| User.current.allowed_to?(permission, project)}
  rescue StandardError
    []
  end

  def filter_authorized_issues(issues)
    Array(issues).select {|issue| can_view_planning_for?(issue.project)}
  end

  def query_limit
    return @settings.planner_limit unless @project.blank?

    [@settings.planner_limit * 3, 1000].min
  end

  def render_bad_request(exception)
    render json: {errors: [exception.message]}, status: :unprocessable_content
  end
end
