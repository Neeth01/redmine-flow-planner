# frozen_string_literal: true

class CreateFlowChecklistItems < ActiveRecord::Migration[6.1]
  def change
    create_table :flow_checklist_items do |t|
      t.integer :issue_id, null: false
      t.string :subject, null: false
      t.integer :position, null: false, default: 1
      t.boolean :is_done, null: false, default: false
      t.boolean :mandatory, null: false, default: false
      t.integer :created_by_id
      t.integer :done_by_id
      t.datetime :done_at
      t.timestamps null: false
    end

    add_index :flow_checklist_items, :issue_id
    add_index :flow_checklist_items, [:issue_id, :position]
    add_index :flow_checklist_items, [:issue_id, :mandatory]
  end
end
