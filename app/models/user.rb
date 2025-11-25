class User < ApplicationRecord
  validates :login, presence: true
  validates :password, presence: true

  belongs_to :role
end
