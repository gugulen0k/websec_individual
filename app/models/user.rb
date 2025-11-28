class User < ApplicationRecord
  # has_secure_password предоставляет:
  # - Автоматическое хеширование пароля с bcrypt
  # - Методы password= и password_confirmation=
  # - Метод authenticate для проверки пароля
  # - Валидацию password и password_confirmation
  has_secure_password

  validates :login, presence: true, uniqueness: true

  belongs_to :role
end
