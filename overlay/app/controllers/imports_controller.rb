class ImportsController < ApplicationController
  before_action -> { authorize!(:import_data) }, only: %i[new create commit rollback]
  before_action :set_batch, only: %i[show commit rollback]

  def index
    @batches, @page, @has_next = paginate(ImportBatch.accessible_by(Current.user).includes(:uploaded_by, :site).order(created_at: :desc))
  end

  def new; end

  def create
    file = params[:file] or raise WmsError, "ファイルを選択してください"
    batch = ImportBatch.create!(kind: "stock_opening", filename: file.original_filename, uploaded_by: Current.user)
    batch.file.attach(file)
    Imports::StockOpening.validate!(batch, user: Current.user)
    redirect_to batch, notice: batch.status == "validated" ? "検証に成功しました。内容を確認して実行してください。" : "検証エラーがあります。"
  end

  def show; end

  def commit
    Imports::StockOpening.commit!(@batch)
    redirect_to @batch, notice: "取り込みを実行しました。"
  end

  def rollback
    Imports::StockOpening.rollback!(@batch)
    redirect_to @batch, notice: "取り込みを取り消しました。"
  end

  private

  def set_batch = @batch = ImportBatch.accessible_by(Current.user).find(params[:id])
end
