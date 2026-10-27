class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable,
         :rememberable, :trackable, :validatable

  has_many :posts, dependent: :destroy
  validates :username, presence: true
  validates :firstname, :lastname, presence: true, length: { minimum: 2 }

  def name
    [ firstname, lastname ].compact.join(" ")
  end
end
