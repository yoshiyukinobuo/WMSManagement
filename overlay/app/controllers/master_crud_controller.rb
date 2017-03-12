# Shared CRUD for master data. Subclasses declare: model, title, columns, permitted, form_fields
# (and optionally ability / order). Views live in app/views/master.
class MasterCrudController < ApplicationController
  before_action { authorize!(ability) unless action_name == "index" }
  before_action :set_record, only: %i[edit update destroy]
  helper_method :model, :title, :columns, :form_fields, :ability

  def index
    @records, @page, @has_next = paginate(scope.order(order))
    render "master/index"
  end

  def new
    @record = model.new
    render "master/form"
  end

  def create
    @record = model.new(record_params)
    return unless site_allowed?(@record)

    save_or_render(@record.save, "登録しました。")
  end

  def edit
    render "master/form"
  end

  def update
    @record.assign_attributes(record_params)
    return unless site_allowed?(@record)

    save_or_render(@record.save, "更新しました。")
  end

  def destroy
    if @record.destroy
      redirect_to polymorphic_path(model), notice: "削除しました。"
    else
      redirect_to polymorphic_path(model), alert: @record.errors.full_messages.to_sentence.presence || "削除できません。"
    end
  end

  private

  def ability = :manage_master
  def order = :id
  def scope = model.accessible_by(Current.user)
  def set_record = @record = scope.find(params[:id])
  def record_params = params.require(model.model_name.param_key).permit(*permitted)

  def save_or_render(saved, message)
    if saved
      redirect_to polymorphic_path(model), notice: message
    else
      render "master/form", status: :unprocessable_entity
    end
  end

  def site_allowed?(record)
    site_id = record.site_id_for_access
    return true if site_id.nil? || accessible_site_ids.include?(site_id)

    render_forbidden
    false
  end

  def site_options = accessible_sites.map { |s| [s.to_s, s.id] }
  def zone_options = Zone.accessible_by(Current.user).includes(:site).order(:site_id, :name).map { |z| [z.to_s, z.id] }
  def customer_options = Customer.order(:code).map { |c| [c.to_s, c.id] }
  def temperature_options(attr = :zone_type) = Zone::TYPES.map { |t| [I18n.t("wms.enums.#{attr}.#{t}"), t] }
end
