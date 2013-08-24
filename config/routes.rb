# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

if Rails::VERSION::MAJOR >= 3
  RedmineApp::Application.routes.draw do
    match 'task_board', :to => 'stuff_to_do#index', :via => 'get'
    match 'task_board/:action.:format', :to => 'stuff_to_do', :via => [:get, :post]
    match 'time_grid', :to => 'stuff_to_do#time_grid', :via => [:get, :post]
  end
else
  ActionController::Routing::Routes.draw do |map|
    map.with_options :controller => 'stuff_to_do' do |stuff_routes|
      stuff_routes.with_options :conditions => {:method => :get} do |stuff_views|
        stuff_views.connect 'task_board', :action => 'index'
        stuff_views.connect 'task_board/:action.:format'
      end
      stuff_routes.with_options :conditions => {:method => :post} do |stuff_views|
        stuff_views.connect 'task_board', :action => 'index'
        stuff_views.connect 'task_board/:action.:format'
      end
    end
  end
end
