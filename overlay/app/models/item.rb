class Item < ApplicationRecord
  include Auditable

  belongs_to :customer

  validates :code, presence: true, uniqueness: { scope: :customer_id }
  validates :name, presence: true
  validates :unit, presence: true
  validates :required_temperature_type, inclusion: { in: Zone::TYPES }, allow_blank: true

  def to_s = "#{code} #{name}"
end
