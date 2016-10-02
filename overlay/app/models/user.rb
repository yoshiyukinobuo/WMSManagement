class User < ApplicationRecord
  include Auditable

  ROLES = Permissions::ALL

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_site_scopes, dependent: :destroy
  has_many :sites, through: :user_site_scopes

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :email_address, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :password, length: { minimum: 10 }, allow_nil: true

  ROLES.each do |r|
    define_method("#{r}?") { role == r }
  end

  # System admins see every site; everyone else only the sites they are assigned to.
  def accessible_site_ids
    system_admin? ? Site.pluck(:id) : site_ids
  end

  def can?(ability)
    Permissions.allow?(role, ability)
  end

  def to_s = name.presence || email_address
end
