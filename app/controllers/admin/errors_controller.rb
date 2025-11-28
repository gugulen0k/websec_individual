# frozen_string_literal: true

class Admin::ErrorsController < ApplicationController
  before_action :require_admin

  # GET /admin/errors
  def index
    @log_files = ErrorLogger.available_log_files
    @current_date = params[:date] ? Date.parse(params[:date]) : Date.today
    @errors = ErrorLogger.read_logs(@current_date, limit: 500)
    @statistics = ErrorLogger.daily_statistics(@current_date)

    # 📝 ЛОГИРОВАНИЕ: Просмотр логов ошибок
    SecurityLogger.log_action(
      current_user,
      'view_error_logs',
      request,
      { date: @current_date }
    )
  rescue Date::Error
    @current_date = Date.today
    @errors = ErrorLogger.read_logs(@current_date, limit: 500)
    flash.now[:alert] = "Неверный формат даты, показываются логи за сегодня"
  end

  # GET /admin/errors/search
  def search
    @query = params[:query]
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @errors = ErrorLogger.search_logs(@query, @date)
    @log_files = ErrorLogger.available_log_files
    @current_date = @date
    @statistics = ErrorLogger.daily_statistics(@date)

    # 📝 ЛОГИРОВАНИЕ: Поиск в логах ошибок
    SecurityLogger.log_action(
      current_user,
      'search_error_logs',
      request,
      { query: @query, date: @date }
    )

    render :index
  end

  # GET /admin/errors/download
  def download
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    log_file = Rails.root.join('log', 'errors', "errors_#{date.strftime('%Y%m%d')}.log")

    unless File.exist?(log_file)
      redirect_to admin_errors_path, alert: "Файл лога ошибок за #{date.strftime('%d.%m.%Y')} не найден"
      return
    end

    # 📝 ЛОГИРОВАНИЕ: Скачивание файла логов ошибок
    SecurityLogger.log_action(
      current_user,
      'download_error_log',
      request,
      { date: date },
      level: :warn
    )

    send_file(
      log_file,
      filename: "errors_log_#{date.strftime('%Y%m%d')}.log",
      type: 'text/plain',
      disposition: 'attachment'
    )
  end

  # GET /admin/errors/stats
  def stats
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @statistics = ErrorLogger.daily_statistics(@date)

    # Статистика за последние 7 дней
    @weekly_stats = (0..6).map do |days_ago|
      date = @date - days_ago.days
      {
        date: date,
        stats: ErrorLogger.daily_statistics(date)
      }
    end.reverse
  end
end
