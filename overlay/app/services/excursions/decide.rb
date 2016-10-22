module Excursions
  # FR-T5: hold -> review -> release or discard, with approver and comment.
  # Writes an append-only ExcursionDecision; the impact row mirrors the latest decision.
  class Decide
    def self.call(impact:, disposition:, comment:, user: Current.user)
      raise Inventory::Error, "判定は「リリース」か「廃棄」を選択してください" unless %w[release discard].include?(disposition)
      raise Inventory::Error, "コメントを入力してください" if comment.blank?
      raise Inventory::Error, "廃棄済みのため判定を変更できません" if impact.disposition == "discard"

      ActiveRecord::Base.transaction do
        ExcursionDecision.create!(excursion_lot_impact: impact, disposition: disposition, comment: comment, decided_by: user)
        impact.update!(disposition: disposition, decided_by: user, decided_at: Time.current, comment: comment)
        lot = impact.lot
        if disposition == "release"
          lot.release_if_clear!
        else
          Inventory::Discard.all!(lot: lot, note: "温度逸脱 ##{impact.excursion_id} により廃棄")
        end
      end
    end
  end
end
