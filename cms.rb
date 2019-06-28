require "sinatra"
require "sinatra/reloader" if development?
require "tilt/erubis"
require "sysrandom/securerandom"
require "redcarpet"

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
  when ".md"
    erb render_markdown(contents)
  end
end

def create_document(name, content = "")
  File.open(File.join(data_path, name), "w") do |file|
    file.write(content)
  end
end


get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :home
end

get "/new" do
  erb :new_doc
end

get "/:filename" do
  path = File.join(data_path, params[:filename])

  if File.file?(path)
    load_file_contents(path)
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
end

get "/:filename/edit" do
  path = File.join(data_path, params[:filename])

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

post "/:filename" do
  path = File.join(data_path, params[:filename])
  edited_contents = params[:file_content]

  if File.file?(path)
    @file_name = params[:filename]
    File.write(path, edited_contents)
    
  else
    session[:message] = "#{params[:filename]} does not exist."
    redirect "/"
  end
  
  session[:message] = "#{params[:filename]} has been updated."
  redirect "/"
end

