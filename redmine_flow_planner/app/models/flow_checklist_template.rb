# frozen_string_literal: true

class FlowChecklistTemplate < ActiveRecord::Base
  self.table_name = 'flow_checklist_templates'

  belongs_to :project, optional: true
  belongs_to :tracker, optional: true

  scope :active, -> { where(active: true) }
  scope :ordered, lambda {
    order(Arel.sql('CASE WHEN project_id IS NULL THEN 1 ELSE 0 END ASC'))
      .order(Arel.sql('CASE WHEN tracker_id IS NULL THEN 1 ELSE 0 END ASC'))
      .order(:position, :id)
  }

  validates :name, presence: true, length: {maximum: 255}
  validates :items_raw, presence: true

  before_validation :normalize_name
  before_create :assign_default_position

  def display_scope
    [
      project&.name || I18n.t(:label_flow_all_projects),
      tracker&.name || I18n.t(:label_flow_all_trackers)
    ].join(' / ')
  end

  def parsed_items
    items_raw.to_s.lines.filter_map.with_index do |line, index|
      subject, mandatory = parse_line(line)
      next if subject.blank?

      {
        subject: subject,
        mandatory: mandatory,
        position: index + 1
      }
    end
  end

  def apply_to(issue, actor: User.current)
    return 0 unless issue.present?
    return 0 unless active?

    existing_subjects = FlowChecklistItem.where(issue_id: issue.id).pluck(:subject).map {|value| normalize_subject(value)}
    added = 0

    FlowChecklistItem.transaction do
      parsed_items.each do |item|
        next if existing_subjects.include?(normalize_subject(item[:subject]))

        FlowChecklistItem.create!(
          issue_id: issue.id,
          subject: item[:subject],
          mandatory: item[:mandatory],
          created_by: actor
        )
        existing_subjects << normalize_subject(item[:subject])
        added += 1
      end
    end

    added
  end

  def self.matching(issue)
    return none unless table_exists?
    return none unless issue.present?

    active
      .where('project_id IS NULL OR project_id = ?', issue.project_id)
      .where('tracker_id IS NULL OR tracker_id = ?', issue.tracker_id)
      .ordered
  end

  private

  def parse_line(line)
    content = line.to_s.strip
    return if content.blank?

    mandatory = false

    if content.match?(/\A(?:!|\*|\[required\]|\[mandatory\])\s*/i)
      mandatory = true
      content = content.sub(/\A(?:!|\*|\[required\]|\[mandatory\])\s*/i, '').strip
    end

    return if content.blank?

    [content, mandatory]
  end

  def normalize_name
    self.name = name.to_s.strip
  end

  def normalize_subject(value)
    value.to_s.strip.downcase
  end

  def assign_default_position
    return if position.to_i.positive?

    self.position = FlowChecklistTemplate.maximum(:position).to_i + 1
  end
end
