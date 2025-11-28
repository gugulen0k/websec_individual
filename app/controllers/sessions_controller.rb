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

    # Используем метод authenticate из has_secure_password
    # Он безопасно сравнивает хешированный пароль
    if user && user.authenticate(password_param)
      # успешный вход
      session[:user_id] = user.id
      session[:role] = user.role.name

      # 📝 ЛОГИРОВАНИЕ: Успешный вход в систему
      SecurityLogger.log_login(user, request, {
        role: user.role.name,
        session_id: session.id.to_s[0..10]
      })

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
      # 📝 ЛОГИРОВАНИЕ: Неудачная попытка входа
      SecurityLogger.log_failed_login(
        login_param,
        request,
        user ? 'Invalid password' : 'User not found'
      )

      flash[:alert] = "Неверный логин или пароль"
      render :new
    end
  end

  def destroy
    # 📝 ЛОГИРОВАНИЕ: Выход из системы
    if current_user
      SecurityLogger.log_logout(current_user, request)
    end

    reset_session
    redirect_to login_path
  end
end
