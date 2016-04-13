# FIFO ("fifo") or first-expired-first-out ("fefo"). To be confirmed with Yokoun staff (design doc FR-S2).
Rails.configuration.x.allocation_rule = ENV.fetch("ALLOCATION_RULE", "fifo")
