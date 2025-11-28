# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Создание ролей
puts "Создание ролей..."
admin_role = Role.find_or_create_by!(name: "admin")
manager_role = Role.find_or_create_by!(name: "manager")
user_role = Role.find_or_create_by!(name: "user")
puts "✅ Роли созданы"

# Создание пользователей с хешированными паролями
puts "\nСоздание пользователей..."

# Удаляем старых пользователей если есть
User.destroy_all

# Создаем пользователей с bcrypt хешированием
User.create!(
  login: "admin",
  password: "admin123",
  password_confirmation: "admin123",
  role: admin_role
)
puts "✅ Создан admin (пароль: admin123)"

User.create!(
  login: "manager",
  password: "manager123",
  password_confirmation: "manager123",
  role: manager_role
)
puts "✅ Создан manager (пароль: manager123)"

User.create!(
  login: "john",
  password: "user123",
  password_confirmation: "user123",
  role: user_role
)
puts "✅ Создан john (пароль: user123)"

puts "\n" + "="*80
puts "ПРОВЕРКА: Пользователи с хешированными паролями"
puts "="*80
User.all.each do |user|
  puts "\nID: #{user.id}"
  puts "Login: #{user.login}"
  puts "Password Digest: #{user.password_digest[0..60]}..."
  puts "Role: #{user.role.name}"
end

puts "\n✅ База данных успешно заполнена!"
