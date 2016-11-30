module Receiving
  # FR-R2/R3/R4/R5: record one lot on a receipt, write the ledger entries, optionally put away at once.
  class AddLine
    def self.call(**kwargs) = new(**kwargs).call

    def initialize(receipt:, attrs:, location: nil, force: false)
      @receipt = receipt
      @attrs = attrs
      @location = location
      @force = force
    end

    def call
      ActiveRecord::Base.transaction do
        raise Inventory::Error, "完了済みの入荷には追加できません" if @receipt.completed?

        line = ReceiptLine.new(@attrs.merge(receipt_id: @receipt.id))
        raise ActiveRecord::RecordInvalid, line unless line.valid?

        required = line.required_temperature_type.presence || line.item&.required_temperature_type
        if @location && !@force && !@location.zone.satisfies?(required)
          raise Inventory::ZoneMismatch, "ロケーション #{@location.code} の温度帯は要求温度帯を満たしません"
        end

        lot = Lot.create!(
          customer: @receipt.customer, item: line.item, site: @receipt.site, lot_number: line.lot_number,
          received_on: @receipt.arrival_at.to_date, required_temperature_type: required, expires_on: line.expires_on
        )
        line.assign_attributes(lot: lot, required_temperature_type: required)
        line.save!

        Inventory::Ledger.record!(lot: lot, type: "receive", quantity: line.received_quantity, reference: line)
        if @location
          Inventory::Putaway.call(lot: lot, location: @location, quantity: line.received_quantity, force: @force, reference: line)
        end
        line
      end
    end
  end
end
