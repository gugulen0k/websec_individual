class SessionsController < ApplicationController
  def new
  end

  def create
    # Берём входные данные (строки)
    login_param    = params[:login].to_s.strip
    password_param = params[:password].to_s

    # -----------------------------
    # ActiveRecord автоматически параметризует запросы,
    # поэтому SQL-инъекции через login_param невозможны.
    # -----------------------------
    user = User.find_by(login: login_param)

    if user && user.password == password_param
      # успешный вход
      session[:user_id] = user.id
      session[:role] = user.role.name

      # Перенаправление по роли
      case user.role.name
      when "admin"
        redirect_to admin_dashboard_path
      when "manager"
        redirect_to manager_dashboard_path
      else
        redirect_to user_dashboard_path
      end
    else
      flash[:alert] = "Неверный логин или пароль"
      render :new
    end
  end

  def destroy
    reset_session
    redirect_to login_path
  end
end
