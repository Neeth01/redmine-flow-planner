require File.expand_path('../../test_helper', __FILE__)

class AgileBoardsControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules, :users, :email_addresses, :members, :member_roles,
           :roles, :trackers, :projects_trackers, :issue_statuses, :issues,
           :enumerations, :queries, :versions, :workflows

  def setup
    @project = Project.find(1)
    @project.enabled_module_names = @project.enabled_module_names.map(&:to_sym) | [:flow_planner]
    @project.save!
    @request.session[:user_id] = 2
    Role.find(1).add_permission! :view_agile_board
    Role.find(1).add_permission! :manage_agile_board
  end

  def test_index
    get :index, params: {project_id: @project.id}

    assert_response :success
    assert_template 'index'
  end

  def test_update_issue_status
    issue = Issue.find(1)
    next_status = issue.new_statuses_allowed_to(User.find(2)).first || issue.status

    patch :update_issue,
          params: {
            project_id: @project.id,
            id: issue.id,
            issue: {status_id: next_status.id}
          }

    assert_response :success
    assert_equal next_status.id, issue.reload.status_id
  end
end
