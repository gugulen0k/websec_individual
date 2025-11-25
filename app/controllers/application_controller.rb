class ApplicationController < ActionController::Base
  helper_method :current_user

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def require_login
    unless current_user
      redirect_to login_path, alert: "Сначала войдите в систему"
    end
  end

  def require_admin
    require_login
    unless session[:role] == "admin"
      redirect_to user_dashboard_path, alert: "Недостаточно прав"
    end
  end

  def require_manager
    require_login
    unless [ "manager", "admin" ].include?(session[:role])
      redirect_to user_dashboard_path, alert: "Недостаточно прав"
    end
  end
end
