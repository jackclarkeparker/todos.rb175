require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def complete?(item)
    completed_status = item[:completed]
    
    if !completed_status.nil?
      completed_status
    else
      list_complete?(item)
    end
  end

  def list_class(list)
    'complete' if list_complete?(list)
  end

  def todos_count(list)
    list[:todos].size
  end

  def todos_remaining_count(list)
    list[:todos].count { |todo| todo[:completed] == false }
  end

  def sort_by_remaining(list)
    list.sort_by { |item| complete?(item) ? 1 : 0 }
  end
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# GET  /lists          -> view all lists
# GET  /lists/new      -> new list form
# POST /lists          -> create new list
# GET  /lists/1        -> view a single list

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

def load_list(id)
  list = session[:lists].find { |list| list[:id] == id }
  return list if list

  session[:error] = 'The specified list was not found.'
  redirect '/lists'
end

# Return an error message if the name is invalid. Return nil if name is valid
def error_for_list_name(name)
  if !name.size.between?(1, 100)
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

def next_list_id
  max = session[:lists].map { |list| list[:id] }.max || 0
  max + 1
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    id = next_list_id
    session[:lists] << { id: id, name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Visits the page of a specific list
get '/lists/:list_id' do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  erb :list, layout: :layout
end

# Renders the edit list name form
get '/lists/:list_id/edit' do
  list_id = params[:list_id].to_i
  @list = load_list(list_id)
  erb :edit_list, layout: :layout
end

# Updates an existing todo list (It may just be the name at first, but if we want to edit other features in future, these actions will also be carried out here.)
post '/lists/:list_id' do
  list_name = params[:list_name].strip
  list_id = params[:list_id].to_i
  @list = load_list(list_id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been updated.'
    redirect "/lists/#{list_id}"
  end
end

# Deletes a list
post '/lists/:list_id/destroy' do
  list_id = params[:list_id].to_i
  session[:lists].delete_if { |list| list[:id] == list_id }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'The list has been deleted.'
    redirect '/lists'  
  end
end

def error_for_todo_name(name)
  if !name.size.between?(1, 100)
    'The todo name must be between 1 and 100 characters.'
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# Enter a new todo item for the list specified by :id
post '/lists/:list_id/todos' do
  text = params[:todo].strip
  list_id = params[:list_id].to_i
  @list = session[:lists].find { |list| list[:id] == list_id }

  error = error_for_todo_name(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }

    session[:success] = 'The todo was added.'
    redirect "/lists/#{list_id}"
  end
end

# Delete a todo from a list
post '/lists/:list_id/todos/:todo_id/destroy' do
  list_id = params[:list_id].to_i
  list = session[:lists].find { |list| list[:id] == list_id }
  
  todo_id = params[:todo_id].to_i
  list[:todos].delete_if { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = 'The todo has been deleted.'
    redirect "/lists/#{list_id}"
  end
end

# Mark / unmark a todo complete
post '/lists/:list_id/todos/:todo_id' do
  list_id = params[:list_id].to_i
  list = session[:lists].find { |list| list[:id] == list_id }

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == 'true'
  list[:todos].find { |todo| todo[:id] == todo_id }[:completed] = is_completed

  redirect "/lists/#{list_id}"
end

# Mark all todos complete
post '/lists/:list_id/complete_all' do
  list_id = params[:list_id].to_i
  list = session[:lists].find { |list| list[:id] == list_id }

  list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = 'All todos have been completed!'
  redirect "/lists/#{list_id}"
end
