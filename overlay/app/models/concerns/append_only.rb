# Rows can be inserted but never edited or destroyed through ActiveRecord.
# Corrections are modelled as new rows that reference the original.
module AppendOnly
  extend ActiveSupport::Concern

  def readonly?
    persisted? || super
  end
end
