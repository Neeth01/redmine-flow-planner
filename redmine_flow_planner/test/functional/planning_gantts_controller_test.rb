require File.expand_path('../../test_helper', __FILE__)

class PlanningGanttsControllerTest < Redmine::ControllerTest
  fixtures :projects, :enabled_modules, :users, :email_addresses, :members, :member_roles,
           :roles, :trackers, :projects_trackers, :issue_statuses, :issues,
           :enumerations, :queries, :versions, :workflows

  def setup
    @project = Project.find(1)
    @project.enabled_module_names = @project.enabled_module_names.map(&:to_sym) | [:flow_planner]
    @project.save!
    @request.session[:user_id] = 2
    Role.find(1).add_permission! :view_planning_gantt
    Role.find(1).add_permission! :manage_planning_gantt
  end

  def test_index
    get :index, params: {project_id: @project.id}

    assert_response :success
    assert_template 'index'
  end

  def test_update_issue_dates
    issue = Issue.find(1)

    patch :update_issue,
          params: {
            project_id: @project.id,
            id: issue.id,
            issue: {
              start_date: '2026-04-06',
              due_date: '2026-04-08'
            }
          }

    assert_response :success
    assert_equal Date.new(2026, 4, 6), issue.reload.start_date
    assert_equal Date.new(2026, 4, 8), issue.reload.due_date
  end
end
