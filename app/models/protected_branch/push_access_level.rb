class ProtectedBranch::PushAccessLevel < ActiveRecord::Base
  include ProtectedBranchAccess

  belongs_to :protected_branch
  belongs_to :user

  delegate :project, to: :protected_branch

  validates :access_level, presence: true, inclusion: { in: [Gitlab::Access::MASTER,
                                                             Gitlab::Access::DEVELOPER,
                                                             Gitlab::Access::NO_ACCESS] }

  scope :by_user, -> (user) { where(user: user ) }

  def self.human_access_levels
    {
      Gitlab::Access::MASTER => "Masters",
      Gitlab::Access::DEVELOPER => "Developers + Masters",
      Gitlab::Access::NO_ACCESS => "No one"
    }.with_indifferent_access
  end

  def check_access(user)
    return false if access_level == Gitlab::Access::NO_ACCESS
    return true if user.is_admin?
    return user.id == self.user_id if self.user.present?

    project.team.max_member_access(user.id) >= access_level
  end
end
