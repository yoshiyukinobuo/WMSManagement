class Customer < ApplicationRecord
  include Auditable

  has_many :items, dependent: :restrict_with_error
  has_many :lots, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true

  def to_s = "#{code} #{name}"
end
