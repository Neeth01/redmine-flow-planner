require File.expand_path('../../test_helper', __FILE__)

class FlowChecklistItemsControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules, :users, :email_addresses, :members, :member_roles,
           :roles, :trackers, :projects_trackers, :issue_statuses, :issues,
           :enumerations, :queries, :versions, :workflows

  def setup
    @issue = Issue.find(1)
    @project = @issue.project
    @project.enabled_module_names = @project.enabled_module_names.map(&:to_sym) | [:flow_planner]
    @project.save!
    @request.session[:user_id] = 2
    Role.find(1).add_permission! :view_flow_checklists
    Role.find(1).add_permission! :manage_flow_checklists
  end

  def test_create_item
    assert_difference 'FlowChecklistItem.count', 1 do
      post :create, params: {issue_id: @issue.id, item: {subject: 'Verifier recette', mandatory: '1'}}
    end

    assert_response :created
    item = @issue.reload.flow_checklist_items.last
    assert_equal 'Verifier recette', item.subject
    assert item.mandatory?
  end

  def test_update_item
    item = FlowChecklistItem.create!(issue: @issue, subject: 'Analyser', position: 1)

    patch :update, params: {issue_id: @issue.id, id: item.id, item: {subject: 'Analyser et valider', is_done: '1'}}

    assert_response :success
    item.reload
    assert_equal 'Analyser et valider', item.subject
    assert item.done?
  end

  def test_reorder_items
    first = FlowChecklistItem.create!(issue: @issue, subject: 'Premier', position: 1)
    second = FlowChecklistItem.create!(issue: @issue, subject: 'Second', position: 2)

    patch :reorder, params: {issue_id: @issue.id, item_ids: [second.id, first.id]}

    assert_response :success
    assert_equal 1, second.reload.position
    assert_equal 2, first.reload.position
  end

  def test_create_item_requires_manage_permission
    Role.find(1).remove_permission! :manage_flow_checklists

    assert_no_difference 'FlowChecklistItem.count' do
      post :create, params: {issue_id: @issue.id, item: {subject: 'Interdit'}}
    end

    assert_response :forbidden
  ensure
    Role.find(1).add_permission! :manage_flow_checklists
  end
end
