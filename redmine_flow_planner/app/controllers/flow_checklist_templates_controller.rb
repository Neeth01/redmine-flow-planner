# frozen_string_literal: true

class FlowChecklistTemplatesController < ApplicationController
  layout 'admin'

  before_action :require_admin
  before_action :find_template, only: [:edit, :update, :destroy]

  helper :flow_planner

  def index
    load_index_context
  rescue StandardError => error
    render_safe_index(error)
  end

  def create
    return redirect_with_missing_table unless templates_table_available?

    @template = FlowChecklistTemplate.new(template_params)

    if @template.save
      flash[:notice] = l(:notice_successful_create)
      redirect_to flow_checklist_templates_path
    else
      load_index_context(preserve_template: true)
      render :index, status: :unprocessable_content
    end
  rescue StandardError => error
    render_safe_index(error, status: :unprocessable_content, preserve_template: true)
  end

  def edit
    return redirect_with_missing_table unless templates_table_available?

    load_index_context(preserve_template: true)
    render :index
  rescue StandardError => error
    render_safe_index(error, preserve_template: true)
  end

  def update
    return redirect_with_missing_table unless templates_table_available?

    if @template.update(template_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to flow_checklist_templates_path
    else
      load_index_context(preserve_template: true)
      render :index, status: :unprocessable_content
    end
  rescue StandardError => error
    render_safe_index(error, status: :unprocessable_content, preserve_template: true)
  end

  def destroy
    return redirect_with_missing_table unless templates_table_available?

    @template.destroy
    flash[:notice] = l(:notice_successful_delete)
    redirect_to flow_checklist_templates_path
  rescue StandardError => error
    log_template_error('destroy', error)
    flash[:error] = admin_template_error_message(error)
    redirect_to flow_checklist_templates_path
  end

  private

  def templates_table_available?
    FlowChecklistTemplate.table_exists?
  rescue StandardError
    false
  end

  def find_template
    return redirect_with_missing_table unless templates_table_available?

    @template = FlowChecklistTemplate.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  rescue StandardError => error
    log_template_error('find_template', error)
    flash[:error] = admin_template_error_message(error)
    redirect_to flow_checklist_templates_path
  end

  def load_index_context(preserve_template: false)
    @settings = RedmineFlowPlanner.settings
    @templates_table_available = templates_table_available?
    @templates = load_templates
    load_collections
    @template = build_template unless preserve_template && @template.present?
    flash.now[:warning] = l(:text_flow_checklist_templates_migration_required) unless @templates_table_available
  end

  def load_templates
    return [] unless @templates_table_available

    FlowChecklistTemplate.includes(:project, :tracker).ordered.to_a
  rescue StandardError => error
    log_template_error('load_templates', error)
    @templates_table_available = false
    []
  end

  def build_template
    return nil unless @templates_table_available

    FlowChecklistTemplate.new(active: true)
  rescue StandardError => error
    log_template_error('build_template', error)
    @templates_table_available = false
    nil
  end

  def load_collections
    @template_projects = []
    @template_trackers = []
    return unless @templates_table_available

    scope = Project.order(:name)
    scope = scope.active if scope.respond_to?(:active)
    @template_projects = scope.to_a
    @template_trackers = Tracker.order(:position, :name).to_a
  rescue StandardError => error
    log_template_error('load_collections', error)
    @template_projects = []
    @template_trackers = []
  end

  def template_params
    attributes = params.require(:flow_checklist_template).permit(:name, :project_id, :tracker_id, :active, :items_raw)
    attributes[:project_id] = attributes[:project_id].presence
    attributes[:tracker_id] = attributes[:tracker_id].presence
    attributes
  end

  def redirect_with_missing_table
    flash[:error] = l(:text_flow_checklist_templates_migration_required)
    redirect_to flow_checklist_templates_path
  end

  def render_safe_index(error, status: :ok, preserve_template: false)
    log_template_error(action_name, error)
    load_index_context(preserve_template: preserve_template)
    flash.now[:error] = admin_template_error_message(error)
    render :index, status: status
  rescue StandardError => secondary_error
    log_template_error("#{action_name}_fallback", secondary_error)
    flash[:error] = admin_template_error_message(error)
    redirect_to controller: 'admin', action: 'plugins'
  end

  def admin_template_error_message(error)
    return 'Checklist templates page could not be loaded.' unless User.current&.admin?

    "#{error.class}: #{error.message}"
  end

  def log_template_error(context, error)
    Rails.logger.error("[redmine_flow_planner] checklist templates #{context} failed: #{error.class}: #{error.message}")
  end
end
