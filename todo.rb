require 'sinatra'
require 'sinatra/content_for'
require 'sinatra/reloader'
require 'tilt/erubis'

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def find_list_name(id)
    session[:lists][id][:name]
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

# Return an error message if the name is invalid. Return nil if name is valid
def error_for_list_name(name)
  if !name.size.between?(1, 100)
    'The list name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Visits the page of a specific list
get "/lists/:list_id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Renders the edit list name form
get "/lists/:id/edit" do
  @id = params[:id].to_i
  @list = session[:lists][@id]
  erb :edit_list, layout: :layout
end

# Updates an existing todo list (It may just be the name at first, but if we want to edit other features in future, these actions will also be carried out here.)
post "/lists/:id" do
  list_name = params[:list_name].strip
  @id = params[:id].to_i
  @list = session[:lists][@id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been updated.'
    redirect "/lists/#{@id}"
  end
end

# Deletes the list specified by :id
post "/lists/:id/delete" do
  id = params[:id].to_i
  session[:lists].delete_at(id)
  session[:success] = 'The list has been deleted.'
  redirect "/lists"
end

def error_for_todo(name)
  if !name.size.between?(1, 100)
    "The todo name must be between 1 and 100 characters."
  end
end

# Enter a new todo item for the list specified by :id
post "/lists/:list_id/todos" do
  text = params[:todo].strip
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end
