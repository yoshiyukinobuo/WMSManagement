class MissingDataCheckJob < ApplicationJob
  queue_as :default

  def perform
    Temperature::MissingDataCheck.call
  end
end
