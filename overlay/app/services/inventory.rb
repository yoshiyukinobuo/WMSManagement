module Inventory
  class Error < WmsError; end
  class InsufficientStock < Error; end
  class ZoneMismatch < Error; end
end
