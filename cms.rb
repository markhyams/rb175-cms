require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sysrandom/securerandom"
require "redcarpet"
require "yaml"
require "bcrypt"


configure do
  enable :sessions
  set :session_secret, ENV.fetch('SESSION_SECRET') { SecureRandom.hex(64) }
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else 
    File.expand_path("../data", __FILE__)
  end
end

def load_user_credentials
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
end

def render_markdown(text)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(text)
end

def load_file_contents(path)
  contents = File.read(path)
  
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    contents
  when ".jpg"
    headers["Content-Type"] = "image/jpeg"
    contents
  when ".md"
    erb render_markdown(contents)
  end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end

def valid_credentials?(username, password)
  users = YAML.load_file(load_user_credentials)
  return false unless users.key?(username)
  
  hashed_pw = BCrypt::Password.new(users[username])
  hashed_pw == password
end

def user_signed_in?
  session.key?(:username)
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).select do |path|
    File.file?(path)
  end
  
  @files.map! do |path|
    File.basename(path)
  end
  
  erb :home
end

get "/new" do
  require_signed_in_user
  erb :new_doc
end

get "/users/signin" do
  erb :signin
end

get "/users/signup" do
  erb :signup
end

post "/users/signin" do
  password = params[:password]
  username = params[:username]

  if valid_credentials?(username, password)
    session[:username] = username
    session[:message] =  "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid Credentials."
    status 422
    erb :signin
  end
end

post "/users/signup" do
  password1 = params[:password1]
  password2 = params[:password2]
  username = params[:username]
  users = YAML.load_file(load_user_credentials)

  if users.key?(username)
    session[:message] = "Username already exists."
    status 422
    erb :signup
  elsif password1 != password2
    session[:message] = "Passwords do not match."
    status 422
    erb :signup
  elsif password1.strip.size < 5
    session[:message] = "Password must be at least five characters."
    status 422
    erb :signup
  else 
    users[username] = BCrypt::Password.create(password1).to_s
    File.open(load_user_credentials, "w") { |file| file.write(users.to_yaml) }
    session[:message] = "Account successfully created."
    redirect "/users/signin"
  end
  
end

get "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

get "/:filename" do
  path = File.join(data_path, File.basename(params[:filename]))

  if File.file?(path)
    load_file_contents(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  require_signed_in_user  
  
  path = File.join(data_path, File.basename(params[:filename]))
  
  if File.extname(path) == ".jpg"
    session[:message] = "Images cannot be edited."
    redirect "/"
  end  

  if File.file?(path)
    @file_name = params[:filename]
    @file_content = File.read(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
  
  erb :edit
end

post "/new" do
  require_signed_in_user  

  doc_name = params[:document_name]
  
  if doc_name.strip.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new_doc
  elsif !(doc_name =~ /\A\w+.(md|txt)\z/)
    session[:message] = "File name must have a .txt or .md extension, and must only contain letters, numbers and underscores."
    status 422
    erb :new_doc
  else
    create_document(doc_name)
    session[:message] = "#{doc_name} was created."
    redirect "/"
  end
end

post "/uploadimage" do
  if params[:image]
    filename = params[:image][:filename]
    image_data = params[:image][:tempfile]
  else
    session[:message] = "No file was selected."
    status 422
    halt erb :new_doc
  end

  if File.extname(filename) != ".jpg"
    session[:message] = "jpeg images only. Please try again."
    status 422
    erb :new_doc
  else
    File.open(File.join(data_path, filename), "wb") do |f|
      f.write(image_data.read)
    end
    session[:message] = "#{filename} was uploaded."
    redirect "/"
  end
end

post "/:filename" do
  require_signed_in_user  

  path = File.join(data_path, File.basename(params[:filename]))
  edited_contents = params[:file_content]

  if !File.file?(path)
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  elsif
    File.write(path, edited_contents)
    session[:message] = "#{params[:filename]} has been updated."
    redirect "/"
  end
end

post "/:filename/duplicate" do
  require_signed_in_user
  
  filename = File.basename(params[:filename])
  
  
  path = File.join(data_path, filename)
  
  if File.extname(path) == ".jpg"
    session[:message] = "Images cannot be duplicated."
    redirect "/"
  end 
  
  contents = File.read(path)
  new_filename = "copy_of_" + filename
  create_document(new_filename, contents)
  
  session[:message] = "#{new_filename} has been created."
  redirect "/#{new_filename}/edit"
end

post "/:filename/delete" do
  require_signed_in_user  

  path = File.join(data_path, File.basename(params[:filename]))
  
  if !File.file?(path)
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  elsif
    # @file_name = params[:filename]
    File.delete(path)
    session[:message] = "#{params[:filename]} has been deleted."
    redirect "/"
  end
end
