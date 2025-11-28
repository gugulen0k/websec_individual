class ChangePasswordToPasswordDigest < ActiveRecord::Migration[8.0]
  def up
    # Создаем новый столбец для хешированного пароля
    add_column :users, :password_digest, :string

    # Важно: Перезагружаем информацию о столбцах
    User.reset_column_information

    # Мигрируем существующие пароли (хешируем их с bcrypt)
    User.find_each do |user|
      if user.password.present?
        # Хешируем старый пароль с помощью bcrypt
        hashed = BCrypt::Password.create(user.password)
        user.update_column(:password_digest, hashed)
      end
    end

    # Удаляем старый столбец с паролями в открытом виде
    remove_column :users, :password

    # Добавляем NOT NULL constraint
    change_column_null :users, :password_digest, false
  end

  def down
    # Внимание: откат потеряет зашифрованные пароли!
    # При откате миграции пароли будут потеряны
    add_column :users, :password, :string
    remove_column :users, :password_digest
  end
end
