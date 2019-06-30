require "bcrypt"

password = BCrypt::Password.create("secret")

p password

