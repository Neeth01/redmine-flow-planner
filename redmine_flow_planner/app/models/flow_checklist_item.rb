# frozen_string_literal: true

class FlowChecklistItem < ActiveRecord::Base
  self.table_name = 'flow_checklist_items'

  belongs_to :issue
  belongs_to :created_by, class_name: 'User', optional: true
  belongs_to :done_by, class_name: 'User', optional: true

  scope :ordered, -> { order(:position, :id) }
  scope :required_items, -> { where(mandatory: true) }
  scope :pending, -> { where(is_done: false) }

  validates :issue, presence: true
  validates :subject, presence: true, length: {maximum: 255}

  before_validation :normalize_subject
  before_create :assign_default_position

  def done?
    is_done?
  end

  private

  def normalize_subject
    self.subject = subject.to_s.strip
  end

  def assign_default_position
    return if position.to_i.positive?

    self.position = FlowChecklistItem.where(issue_id: issue_id).maximum(:position).to_i + 1
  end
end
