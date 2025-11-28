class ApplicationController < ActionController::Base
  helper_method :current_user

  # 🔴 ОБРАБОТКА ОШИБОК: Глобальная обработка исключений
  rescue_from StandardError, with: :handle_standard_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActionController::ParameterMissing, with: :handle_parameter_missing

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
      # 📝 ЛОГИРОВАНИЕ: Попытка несанкционированного доступа к админ-панели
      SecurityLogger.log_unauthorized_access(
        current_user,
        'admin_access',
        request,
        { required_role: 'admin', user_role: session[:role] }
      )

      redirect_to user_dashboard_path, alert: "Недостаточно прав"
    end
  end

  def require_manager
    require_login
    unless [ "manager", "admin" ].include?(session[:role])
      # 📝 ЛОГИРОВАНИЕ: Попытка несанкционированного доступа к панели менеджера
      SecurityLogger.log_unauthorized_access(
        current_user,
        'manager_access',
        request,
        { required_role: 'manager', user_role: session[:role] }
      )

      redirect_to user_dashboard_path, alert: "Недостаточно прав"
    end
  end

  private

  # 🔴 ОБРАБОТЧИКИ ОШИБОК

  # Обработка ошибки "запись не найдена"
  def handle_not_found(exception)
    ErrorLogger.log_error(exception, user: current_user, request: request, context: {
      controller: controller_name,
      action: action_name,
      params: params.to_unsafe_h.except('controller', 'action')
    })

    flash[:alert] = "Запрашиваемая запись не найдена. Пожалуйста, проверьте правильность введённых данных."
    redirect_to(request.referer || root_path)
  end

  # Обработка ошибок валидации
  def handle_validation_error(exception)
    ErrorLogger.log_validation_error(exception.record, user: current_user, request: request)

    flash[:alert] = "Проверьте правильность заполнения формы: #{exception.record.errors.full_messages.join(', ')}"
    redirect_to(request.referer || root_path)
  end

  # Обработка отсутствующих параметров
  def handle_parameter_missing(exception)
    ErrorLogger.log_warning(
      "Missing required parameter: #{exception.param}",
      user: current_user,
      request: request,
      context: { controller: controller_name, action: action_name }
    )

    flash[:alert] = "Отсутствует обязательный параметр. Пожалуйста, заполните все необходимые поля."
    redirect_to(request.referer || root_path)
  end

  # Обработка стандартных ошибок
  def handle_standard_error(exception)
    # Логируем критическую ошибку
    ErrorLogger.log_critical(exception, user: current_user, request: request, context: {
      controller: controller_name,
      action: action_name,
      params: params.to_unsafe_h.except('controller', 'action')
    })

    flash[:alert] = "Произошла ошибка при выполнении операции. Пожалуйста, попробуйте позже или обратитесь к администратору."

    # В режиме разработки показываем детальную ошибку
    raise exception if Rails.env.development?

    redirect_to root_path
  end
end
