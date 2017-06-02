# Tailwind class helpers. Large touch targets because staff may wear gloves in cold rooms (NFR usability).
module UiHelper
  BTN = "inline-flex min-h-[44px] items-center justify-center rounded-md px-4 py-2 text-base font-medium shadow-sm " \
        "focus:outline-none focus:ring-2 focus:ring-offset-1 cursor-pointer".freeze
  TONES = {
    green: "bg-green-100 text-green-800", amber: "bg-amber-100 text-amber-800", red: "bg-red-100 text-red-800",
    slate: "bg-slate-100 text-slate-700", sky: "bg-sky-100 text-sky-800"
  }.freeze

  def btn_class(kind = :primary)
    case kind
    when :danger then "#{BTN} bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
    when :secondary then "#{BTN} border border-slate-300 bg-white text-slate-700 hover:bg-slate-50 focus:ring-slate-400"
    else "#{BTN} bg-sky-700 text-white hover:bg-sky-800 focus:ring-sky-500"
    end
  end

  def input_class
    "block w-full min-h-[44px] rounded-md border border-slate-300 bg-white px-3 py-2 text-base shadow-sm " \
      "focus:border-sky-500 focus:outline-none focus:ring-1 focus:ring-sky-500"
  end

  def label_class = "block text-sm font-medium text-slate-700 mb-1"
  def card_class = "rounded-lg border border-slate-200 bg-white p-4 shadow-sm"
  def table_class = "min-w-full divide-y divide-slate-200 text-sm"
  def th_class = "px-3 py-2 text-left text-xs font-semibold uppercase tracking-wide text-slate-500 whitespace-nowrap"
  def td_class = "px-3 py-2 align-top"

  def badge(text, tone = :slate)
    content_tag(:span, text, class: "inline-block rounded-full px-2 py-0.5 text-xs font-medium #{TONES.fetch(tone)}")
  end
end
