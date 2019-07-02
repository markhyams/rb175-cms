ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CmsTest < Minitest::Test
  include Rack::Test::Methods
  
  def app 
    Sinatra::Application
  end
  
  def setup
    FileUtils.mkdir_p(data_path)
    FileUtils.mkdir_p(File.join(data_path, "history"))
  end
  
  def teardown
    FileUtils.rm_rf(data_path)
  end
  
  def session
    last_request.env["rack.session"]
  end
  
  def admin_session
    { "rack.session" => { username: "admin" } }
  end

  def test_home
    create_document("about.md")
    create_document("changes.txt")
    
    get "/"
    
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end
  
  def test_display_file
    create_document("changes.txt", "Ruby 1.2 released")

    get "/changes.txt"
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 1.2 released"
  end
  
  def test_non_existant_file
    get "/fake_file.text"
    assert_equal "fake_file.text does not exist.", session[:message]
    
    assert_equal 302, last_response.status
    
    get last_response["Location"]
    
    assert_equal 200, last_response.status

    get "/"
    refute_includes last_response.body, "fake_file.text does not exist."
  end
  
  def test_markdown
    create_document("about.md", "# Ruby is...")
    
    get "/about.md"
    assert_equal 200, last_response.status
    
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "<h1>Ruby is...</h1>"
  end
  
  def test_editing_document
    create_document("history.txt")
    
    get "/history.txt/edit", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_updating_document
    create_document("changes.txt")

    post "/changes.txt", {file_content: "new content"}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "changes.txt has been updated.", session[:message]
    
    get last_response.headers["Location"]

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end
  
  def test_version_created_after_editing
    create_document("changes.txt", "old content")

    post "/changes.txt", {file_content: "new content"}, admin_session
    history_version_path = File.join(data_path, "history", "changes_v000.txt")
    assert File.file?(history_version_path)
    assert_includes File.read(history_version_path), "old content"
  end
  
  def test_restore_version
    create_document("changes.txt", "old content")

    post "/changes.txt", {file_content: "new content"}, admin_session
    history_version_path = File.join(data_path, "history", "changes_v000.txt")
    
    post "/changes.txt/history/changes_v000.txt/restore"
    assert_equal "changes_v000.txt has been restored to changes.txt.", session[:message]
    assert !File.file?(history_version_path)
    assert_includes File.read(File.join(data_path, "changes.txt")), "old content"
  end
  
  def test_no_edits_made
    create_document("changes.txt", "new content")

    post "/changes.txt", {file_content: "new content"}, admin_session
    
    assert_equal 302, last_response.status
    assert_equal "No edits were made.", session[:message]
  end
  
  def test_create_document
    post "/new", {document_name: "newfile.txt"}, admin_session
    assert_equal 302, last_response.status
    assert_equal "newfile.txt was created.", session[:message]
    
    get last_response.headers["Location"]

    get "/newfile.txt"
    assert_equal 200, last_response.status
    
    get "/"
    assert_includes last_response.body, "newfile.txt"
  end
  
  def test_view_new_doc_form
    get "/new", {}, admin_session
    
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_create_new_doc_no_filename
    post "/new", {document_name: ""}, admin_session
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required."
  end
  
  def test_no_file_extension
    post "/new", {document_name: "test"}, admin_session
    
    assert_equal 422, last_response.status
    assert_includes last_response.body, ".txt or .md extension"
  end
  
  def test_delete_file
    create_document("test_delete.txt")
    
    get "/", {}, admin_session
    assert_includes last_response.body, "test_delete.txt"
    
    post "/test_delete.txt/delete"
    assert_equal "test_delete.txt has been deleted.", session[:message]
    assert_equal 302, last_response.status
    
    get last_response.headers["Location"]
    assert_equal 200, last_response.status

    get "/"
    refute_includes last_response.body, "test_delete.txt"
  end
  
  def test_signin
    get "/"
    assert_includes last_response.body, "Sign In"
    
    post "/users/signin", { username: "admin", password: "secret" }
    assert_equal "Welcome!", session[:message]
    assert_equal 302, last_response.status
    
    get last_response.headers["Location"]
    assert_includes last_response.body, "Signed in as admin."
    
    get "/users/signout"
    assert_equal "You have been signed out.", session[:message]
    get last_response.headers["Location"]
  end
  
  def test_failed_signin
    post "/users/signin", { username: "adm", password: "secret" }
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Invalid"
  end
  
  def test_signin_form
    get "users/signin"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end
  
  def test_signed_in_user
    get "/", {}, {"rack.session" => { :username => "admin" } }
    
    assert_includes last_response.body, "Signed in as admin."
    
    get "/users/signout"
    assert_equal "You have been signed out.", session[:message]
    assert_nil session[:username]
  end
  
  def test_create_user
    users_test = YAML.load_file(load_user_credentials)
    
    post "/users/signup", {username: "user", password1: "password", password2: "password"}
    assert_equal "Account successfully created.", session[:message]
    assert_equal 302, last_response.status
    
    post "/users/signin", {username: "user", password: "password"}
    assert_equal "Welcome!", session[:message]
    
    File.open(load_user_credentials, "w") { |file| file.write(users_test.to_yaml)}
  end
  
  def test_user_already_exists
    post "/users/signup", {username: "admin", password1: "password", password2: "password"}
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Username already exists."
  end
  
  def test_passwords_dont_match
    post "/users/signup", {username: "user", password1: "passwjord", password2: "password"}
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Passwords do not match."
  end
  
  def test_password_too_short
    post "/users/signup", {username: "user", password1: "pass", password2: "pass"}
    assert_equal 422, last_response.status
    assert_includes last_response.body, "Password must be at least five characters."
  end
end
