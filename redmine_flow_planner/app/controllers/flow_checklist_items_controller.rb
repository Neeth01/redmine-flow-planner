# frozen_string_literal: true

class FlowChecklistItemsController < ApplicationController
  before_action :find_issue
  before_action :ensure_issue_visible
  before_action :authorize_view
  before_action :authorize_manage, except: :index
  before_action :find_item, only: [:update, :destroy]

  helper :flow_planner

  rescue_from ActionController::ParameterMissing, with: :render_bad_request
  rescue_from Unauthorized, with: :render_forbidden
  rescue_from StandardError, with: :render_internal_error

  def index
    render json: checklist_response
  end

  def create
    @item = FlowChecklistItem.new(checklist_item_create_attributes)
    @item.issue = @issue
    @item.created_by = User.current
    apply_completion_metadata(@item, boolean_param(params.dig(:item, :is_done)))
    @item.position = params.dig(:item, :position).to_i if params.dig(:item, :position).to_i.positive?

    if @item.save
      rebalance_positions
      append_issue_journal(l(:text_flow_checklist_journal_item_added, subject: @item.subject))
      render json: checklist_response(message: l(:notice_successful_create)), status: :created
    else
      render json: {errors: @item.errors.full_messages}, status: :unprocessable_content
    end
  end

  def update
    previous_done = @item.done?
    previous_subject = @item.subject
    @item.assign_attributes(checklist_item_update_attributes)
    apply_completion_metadata(@item, boolean_param(params.dig(:item, :is_done), @item.is_done))

    if @item.save
      append_issue_journal(checklist_update_message(@item, previous_subject, previous_done))
      render json: checklist_response(message: l(:notice_successful_update))
    else
      render json: {errors: @item.errors.full_messages}, status: :unprocessable_content
    end
  end

  def destroy
    subject = @item.subject
    @item.destroy
    rebalance_positions
    append_issue_journal(l(:text_flow_checklist_journal_item_removed, subject: subject))
    render json: checklist_response(message: l(:notice_successful_delete))
  end

  def reorder
    ids = Array(params[:item_ids]).map(&:to_i)
    expected_ids = issue_checklist_scope.pluck(:id)

    unless ids.sort == expected_ids.sort
      return render json: {errors: [l(:text_flow_checklist_invalid_reorder)]}, status: :unprocessable_content
    end

    FlowChecklistItem.transaction do
      ids.each_with_index do |id, index|
        issue_checklist_scope.where(id: id).update_all(position: index + 1)
      end
    end

    append_issue_journal(l(:text_flow_checklist_journal_reordered))
    render json: checklist_response(message: l(:notice_successful_update))
  end

  def apply_template
    return render json: {errors: [l(:text_flow_checklist_templates_unavailable)]}, status: :unprocessable_content unless checklist_templates_available?

    template = matching_templates.find(params.require(:template_id))
    added = template.apply_to(@issue, actor: User.current)

    if added.positive?
      append_issue_journal(l(:text_flow_checklist_journal_template_applied, template: template.name, count: added))
      render json: checklist_response(message: l(:text_flow_checklist_template_applied, template: template.name, count: added))
    else
      render json: checklist_response(message: l(:text_flow_checklist_template_applied_nothing, template: template.name))
    end
  rescue ActiveRecord::RecordNotFound
    render json: {errors: [l(:text_flow_checklist_template_not_found)]}, status: :not_found
  end

  private

  def checklist_response(message: nil)
    issue = @issue.reload
    items = issue_checklist_items(issue)
    stats = issue_checklist_stats(issue, items)
    templates = issue_checklist_templates(issue)

    {
      items: items.map {|item| checklist_item_payload(item)},
      stats: stats,
      blocked: stats[:blocked],
      can_manage: User.current.admin? || User.current.allowed_to?(:manage_flow_checklists, @issue.project),
      html: render_to_string(
        partial: 'flow_checklist_items/panel',
        formats: [:html],
        locals: {
          issue: issue,
          items: items,
          stats: stats,
          templates: templates,
          can_manage_checklist: User.current.admin? || User.current.allowed_to?(:manage_flow_checklists, @issue.project)
        }
      ),
      message: message
    }
  end

  def checklist_item_payload(item)
    {
      id: item.id,
      subject: item.subject,
      is_done: item.done?,
      mandatory: item.mandatory?,
      position: item.position,
      done_at: item.done_at&.iso8601,
      done_by_name: item.done_by&.name
    }
  end

  def checklist_item_create_attributes
    item_params = params.require(:item)
    {
      'subject' => item_params[:subject].to_s.strip,
      'mandatory' => boolean_param(item_params[:mandatory])
    }
  end

  def checklist_item_update_attributes
    item_params = params.require(:item)
    attributes = {}
    attributes['subject'] = item_params[:subject].to_s.strip if item_params.key?(:subject)
    attributes['mandatory'] = boolean_param(item_params[:mandatory]) if item_params.key?(:mandatory)
    attributes
  end

  def apply_completion_metadata(item, done)
    item.is_done = done

    if item.is_done?
      item.done_at = Time.current if item.done_at.blank? || item.will_save_change_to_is_done?
      item.done_by = User.current if item.done_by.blank? || item.will_save_change_to_is_done?
    else
      item.done_at = nil
      item.done_by = nil
    end
  end

  def checklist_update_message(item, previous_subject, previous_done)
    if previous_done != item.done?
      key = item.done? ? :text_flow_checklist_journal_item_done : :text_flow_checklist_journal_item_reopened
      l(key, subject: item.subject)
    elsif previous_subject != item.subject
      l(:text_flow_checklist_journal_item_renamed, before: previous_subject, after: item.subject)
    else
      l(:text_flow_checklist_journal_item_updated, subject: item.subject)
    end
  end

  def append_issue_journal(message)
    return if message.blank?

    @issue.init_journal(User.current, message)
    @issue.save(validate: false)
  rescue StandardError
    nil
  end

  def rebalance_positions
    issue_checklist_scope.each_with_index do |item, index|
      next if item.position == index + 1

      item.update_column(:position, index + 1)
    end
  end

  def find_issue
    @issue = Issue.find(params[:issue_id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def find_item
    @item = issue_checklist_scope.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_404
  end

  def issue_checklist_scope(issue = @issue)
    FlowChecklistItem.where(issue_id: issue.id).order(:position, :id)
  end

  def issue_checklist_items(issue = @issue)
    issue_checklist_scope(issue).to_a
  end

  def issue_checklist_stats(issue = @issue, items = nil)
    items ||= issue_checklist_items(issue)
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

  def checklist_templates_available?
    defined?(FlowChecklistTemplate) && FlowChecklistTemplate.table_exists?
  rescue StandardError
    false
  end

  def issue_checklist_templates(issue = @issue)
    return [] unless checklist_templates_available?

    FlowChecklistTemplate.matching(issue).to_a
  rescue StandardError
    []
  end

  def matching_templates
    FlowChecklistTemplate.matching(@issue)
  end

  def ensure_issue_visible
    raise Unauthorized unless @issue.visible?
  end

  def authorize_view
    return if User.current.admin?

    raise Unauthorized unless User.current.allowed_to?(:view_flow_checklists, @issue.project)
  end

  def authorize_manage
    return if User.current.admin?

    raise Unauthorized unless User.current.allowed_to?(:manage_flow_checklists, @issue.project)
  end

  def boolean_param(value, fallback = false)
    return fallback if value.nil?

    %w[1 true t yes on].include?(value.to_s.downcase)
  end

  def render_bad_request(exception)
    render json: {errors: [exception.message]}, status: :unprocessable_content
  end

  def render_forbidden(_exception)
    render json: {errors: [l(:notice_not_authorized)]}, status: :forbidden
  end

  def render_internal_error(exception)
    Rails.logger.error(
      "[redmine_flow_planner] checklist endpoint failed for issue ##{@issue&.id}: #{exception.class}: #{exception.message}\n" \
      "#{Array(exception.backtrace).first(15).join("\n")}"
    )

    message = if User.current&.admin?
                "#{exception.class}: #{exception.message}"
              else
                l(:text_flow_save_failed)
              end

    render json: {errors: [message]}, status: :internal_server_error
  end
end
