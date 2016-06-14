class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Site scoping hook. Models tied to a site override this; global master data is visible to everyone.
  def self.accessible_by(_user) = all

  # Which site a record belongs to (nil = global). Used to stop users writing to sites they can't access.
  def site_id_for_access = nil
end
