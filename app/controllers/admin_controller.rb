class AdminController < ApplicationController
  before_action :require_admin
  after_action :log_action

  def dashboard; end
  def feature1; end
  def feature2; end
  def feature3; end

  private

  def log_action
    # 📝 ЛОГИРОВАНИЕ: Действия администратора
    SecurityLogger.log_action(
      current_user,
      "admin_#{action_name}",
      request,
      { controller: controller_name }
    )
  end
end
