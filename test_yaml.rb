require 'yaml'
require 'bcrypt'

# module TestMod
  
#   class TestUser
#     def initialize(name)
#       @name = name
#     end
#   end
# end

# users = YAML.load_file('users_test.yml')

# username = "steve"
# password1 = "hello"

# users[username] = BCrypt::Password.create(password1)

# # users["testman"] = TestMod::TestUser.new("steveman")

# File.open('users_test.yml', "w") { |file| file.write(users.to_yaml) }

path = "/usr/bin/ruby.rb"

name = File.basename(path, ".*")
ext = File.extname(path)

20.times do |n|
  puts name + "_ver_" + n.to_s + ext
end