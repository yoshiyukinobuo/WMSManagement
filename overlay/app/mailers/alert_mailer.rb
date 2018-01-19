class AlertMailer < ApplicationMailer
  def excursion_opened(user, excursion)
    @excursion = excursion
    @zone = excursion.zone
    mail to: user.email_address, subject: "【温度逸脱】#{@zone} (開始 #{I18n.l(excursion.started_at, format: :short)})"
  end

  def missing_data(user, zone)
    @zone = zone
    mail to: user.email_address, subject: "【測定データ欠測】#{zone}"
  end
end
