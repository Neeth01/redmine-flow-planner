# frozen_string_literal: true

class CreateFlowChecklistTemplates < ActiveRecord::Migration[7.2]
  def change
    create_table :flow_checklist_templates do |t|
      t.string :name, null: false
      t.integer :project_id, null: true
      t.integer :tracker_id, null: true
      t.integer :position, null: false, default: 1
      t.boolean :active, null: false, default: true
      t.text :items_raw, null: false
      t.timestamps null: false
    end

    add_index :flow_checklist_templates, :project_id
    add_index :flow_checklist_templates, :tracker_id
    add_index :flow_checklist_templates, [:project_id, :tracker_id, :active], name: 'idx_flow_checklist_templates_scope'
  end
end
