# frozen_string_literal: true

class Admin::LogsController < ApplicationController
  before_action :require_admin

  # GET /admin/logs
  def index
    @log_files = SecurityLogger.available_log_files
    @current_date = params[:date] ? Date.parse(params[:date]) : Date.today
    @logs = SecurityLogger.read_logs(@current_date, limit: 500)
    @statistics = SecurityLogger.daily_statistics(@current_date)

    # 📝 ЛОГИРОВАНИЕ: Просмотр логов безопасности
    SecurityLogger.log_action(
      current_user,
      'view_security_logs',
      request,
      { date: @current_date }
    )
  rescue Date::Error
    @current_date = Date.today
    @logs = SecurityLogger.read_logs(@current_date, limit: 500)
    flash.now[:alert] = "Неверный формат даты, показываются логи за сегодня"
  end

  # GET /admin/logs/search
  def search
    @query = params[:query]
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @logs = SecurityLogger.search_logs(@query, @date)

    # 📝 ЛОГИРОВАНИЕ: Поиск в логах
    SecurityLogger.log_action(
      current_user,
      'search_security_logs',
      request,
      { query: @query, date: @date }
    )

    render :index
  end

  # GET /admin/logs/download
  def download
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    log_file = Rails.root.join('log', 'security', "security_#{date.strftime('%Y%m%d')}.log")

    unless File.exist?(log_file)
      redirect_to admin_logs_path, alert: "Файл лога за #{date.strftime('%d.%m.%Y')} не найден"
      return
    end

    # 📝 ЛОГИРОВАНИЕ: Скачивание файла логов
    SecurityLogger.log_action(
      current_user,
      'download_security_log',
      request,
      { date: date },
      level: :warn
    )

    send_file(
      log_file,
      filename: "security_log_#{date.strftime('%Y%m%d')}.log",
      type: 'text/plain',
      disposition: 'attachment'
    )
  end

  # GET /admin/logs/stats
  def stats
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @statistics = SecurityLogger.daily_statistics(@date)

    # Статистика за последние 7 дней
    @weekly_stats = (0..6).map do |days_ago|
      date = @date - days_ago.days
      {
        date: date,
        stats: SecurityLogger.daily_statistics(date)
      }
    end.reverse
  end
end
