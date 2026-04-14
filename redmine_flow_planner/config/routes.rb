get 'projects/:project_id/agile_board',
    to: 'agile_boards#index',
    as: 'project_agile_board'

get 'flow_planner/agile_board',
    to: 'agile_boards#index',
    as: 'global_agile_board'

post 'projects/:project_id/agile_board/issues',
     to: 'agile_boards#create_issue',
     as: 'project_agile_board_issues'

patch 'projects/:project_id/agile_board/issues/:id',
      to: 'agile_boards#update_issue',
      as: 'project_agile_board_issue'

patch 'flow_planner/agile_board/issues/:id',
      to: 'agile_boards#update_issue',
      as: 'global_agile_board_issue'

get 'projects/:project_id/planning_gantt',
    to: 'planning_gantts#index',
    as: 'project_planning_gantt'

get 'flow_planner/planning_gantt',
    to: 'planning_gantts#index',
    as: 'global_planning_gantt'

patch 'projects/:project_id/planning_gantt/issues/:id',
      to: 'planning_gantts#update_issue',
      as: 'project_planning_gantt_issue'

patch 'flow_planner/planning_gantt/issues/:id',
      to: 'planning_gantts#update_issue',
      as: 'global_planning_gantt_issue'

resources :flow_checklist_templates, except: [:show]

resources :issues, only: [] do
  resources :flow_checklist_items, only: [:index, :create, :update, :destroy] do
    collection do
      post :apply_template
      patch :reorder
    end
  end
end
