# frozen_string_literal: true

module RedmineFlowPlanner
  module IssuePatch
    extend ActiveSupport::Concern

    included do
      has_many :flow_checklist_items,
               -> { ordered },
               class_name: 'FlowChecklistItem',
               dependent: :destroy

      after_commit :apply_flow_checklist_templates_after_create, on: :create
      validate :validate_flow_checklist_completion
    end

    def flow_checklist_available?
      FlowChecklistItem.table_exists?
    rescue StandardError
      false
    end

    def flow_checklist_stats
      return empty_flow_checklist_stats unless flow_checklist_available?

      items = FlowChecklistItem.where(issue_id: id).order(:position, :id).to_a
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
    rescue StandardError
      empty_flow_checklist_stats
    end

    def flow_checklist_blocked?
      flow_checklist_stats[:blocked]
    end

    private

    def apply_flow_checklist_templates_after_create
      return unless RedmineFlowPlanner.settings.checklist_auto_apply_templates?
      return unless flow_checklist_available?
      return false unless defined?(FlowChecklistTemplate) && FlowChecklistTemplate.table_exists?
      return unless project&.module_enabled?(:flow_planner)
      return unless FlowChecklistItem.where(issue_id: id).empty?

      FlowChecklistTemplate.matching(self).each do |template|
        template.apply_to(self, actor: author || User.current)
      end
    rescue StandardError
      nil
    end

    def validate_flow_checklist_completion
      return unless RedmineFlowPlanner.settings.checklist_enforce_completion?
      return unless flow_checklist_available?
      return unless project&.module_enabled?(:flow_planner)
      return unless status&.is_closed?
      return unless flow_checklist_blocked?

      errors.add(:base, I18n.t(:error_flow_checklist_incomplete_required))
    end

    def empty_flow_checklist_stats
      {
        total: 0,
        completed: 0,
        pending: 0,
        percent: 0,
        required_total: 0,
        required_completed: 0,
        blocked: false
      }
    end
  end
end
