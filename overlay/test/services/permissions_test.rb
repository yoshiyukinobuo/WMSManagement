require "test_helper"
require "support/builders"

class PermissionsTest < ActiveSupport::TestCase
  include Builders

  test "role matrix" do
    assert make_user(role: "quality").can?(:decide_excursion)
    refute make_user(role: "floor_staff").can?(:decide_excursion)
    assert make_user(role: "floor_staff").can?(:operate_stock)
    refute make_user(role: "management").can?(:operate_stock)
    assert make_user(role: "system_admin").can?(:manage_users)
  end

  test "non-admin users only reach their assigned sites" do
    a = make_site
    b = make_site
    user = make_user(role: "site_supervisor", sites: [a])
    assert_equal [a.id], user.accessible_site_ids
    assert_equal [a.id], Site.accessible_by(user).pluck(:id)
    assert_includes make_user(role: "system_admin").accessible_site_ids, b.id
  end

  test "audit log records who changed what" do
    user = make_user
    Current.session = Session.create!(user: user)
    site = Site.create!(code: "AUD", name: "監査")
    site.update!(name: "監査2")
    logs = AuditLog.where(entity_type: "Site", entity_id: site.id).order(:id)
    assert_equal %w[create update], logs.map(&:action)
    assert_equal user.id, logs.last.actor_id
    assert_equal ["監査", "監査2"], logs.last.changeset["name"]
  ensure
    Current.reset
  end
end
