# frozen_string_literal: true

# Сервис для логирования ошибок и предупреждений приложения
#
# Все ошибки записываются в файлы:
# - log/errors/errors_YYYYMMDD.log - ошибки и предупреждения
#
# Формат записи:
# [TIMESTAMP] [LEVEL] [USER] [IP] [ERROR_TYPE] Message | Details [Location]

class ErrorLogger
  LOG_DIR = Rails.root.join('log', 'errors')

  class << self
    # Логирование ошибки
    def log_error(error, user: nil, request: nil, context: {})
      write_log(
        level: :error,
        error_type: error.class.name,
        message: error.message,
        user: user,
        request: request,
        backtrace: error.backtrace&.first(5),
        context: context
      )
    end

    # Логирование предупреждения
    def log_warning(message, user: nil, request: nil, context: {})
      write_log(
        level: :warn,
        error_type: 'WARNING',
        message: message,
        user: user,
        request: request,
        context: context
      )
    end

    # Логирование ошибки валидации
    def log_validation_error(model, user: nil, request: nil)
      errors = model.errors.full_messages.join(', ')
      write_log(
        level: :warn,
        error_type: 'ValidationError',
        message: "Validation failed for #{model.class.name}",
        user: user,
        request: request,
        context: { errors: errors, model: model.class.name }
      )
    end

    # Логирование критической ошибки
    def log_critical(error, user: nil, request: nil, context: {})
      write_log(
        level: :critical,
        error_type: error.class.name,
        message: error.message,
        user: user,
        request: request,
        backtrace: error.backtrace&.first(10),
        context: context
      )
    end

    # Чтение логов ошибок за определенную дату
    def read_logs(date = Date.today, limit: 1000)
      log_file = log_file_path(date)
      return [] unless File.exist?(log_file)

      # Убедимся, что limit - это целое число в допустимом диапазоне
      safe_limit = case limit
                   when Integer
                     limit.clamp(1, 10000)
                   when Float
                     limit.finite? ? limit.to_i.clamp(1, 10000) : 1000
                   else
                     limit.to_i.clamp(1, 10000)
                   end

      entries = []
      lines = File.readlines(log_file)

      # Берём последние N строк
      lines_to_process = lines.size > safe_limit ? lines.last(safe_limit) : lines

      lines_to_process.each do |line|
        entries << parse_log_line(line)
      end
      entries.compact
    rescue StandardError => e
      Rails.logger.error("Error reading error logs: #{e.message}")
      []
    end

    # Поиск в логах
    def search_logs(query, date = Date.today)
      return [] if query.blank?

      all_logs = read_logs(date, limit: 10000)
      all_logs.select do |log|
        log.values.any? { |v| v.to_s.downcase.include?(query.downcase) }
      end
    end

    # Статистика за день
    def daily_statistics(date = Date.today)
      logs = read_logs(date, limit: 10000)

      {
        total_errors: logs.count,
        critical_errors: logs.count { |l| l[:level] == 'CRITICAL' },
        errors: logs.count { |l| l[:level] == 'ERROR' },
        warnings: logs.count { |l| l[:level] == 'WARN' },
        unique_error_types: logs.map { |l| l[:error_type] }.uniq.count,
        errors_by_type: logs.group_by { |l| l[:error_type] }.transform_values(&:count),
        errors_by_hour: logs.group_by { |l| l[:timestamp].split(' ').last.split(':').first.to_i }.transform_values(&:count)
      }
    end

    # Список доступных файлов логов ошибок
    def available_log_files
      ensure_log_directory
      Dir.glob(LOG_DIR.join('errors_*.log')).sort.reverse.map do |file|
        {
          name: File.basename(file),
          size: File.size(file),
          date: Date.parse(File.basename(file).match(/errors_(\d{8})\.log/)[1]),
          modified_at: File.mtime(file)
        }
      end
    rescue StandardError
      []
    end

    private

    def ensure_log_directory
      FileUtils.mkdir_p(LOG_DIR) unless Dir.exist?(LOG_DIR)
    end

    def log_file_path(date = Date.today)
      ensure_log_directory
      LOG_DIR.join("errors_#{date.strftime('%Y%m%d')}.log")
    end

    def write_log(level:, error_type:, message:, user: nil, request: nil, backtrace: nil, context: {})
      ensure_log_directory

      timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S.%3N')
      level_str = level.to_s.upcase
      user_str = format_user(user)
      ip_str = format_ip(request)
      location_str = format_location(backtrace)
      context_str = format_context(context)

      log_entry = "[#{timestamp}] [#{level_str}] [#{user_str}] [#{ip_str}] [#{error_type}] #{message}"
      log_entry += " | #{context_str}" if context_str.present?
      log_entry += " [#{location_str}]" if location_str.present?

      File.open(log_file_path, 'a') do |f|
        f.puts log_entry
        if backtrace.present?
          backtrace.each do |line|
            f.puts "  #{line}"
          end
        end
      end
    rescue StandardError => e
      Rails.logger.error("Failed to write to error log: #{e.message}")
    end

    def format_user(user)
      return 'ANONYMOUS' unless user
      "#{user.login}(ID:#{user.id})"
    end

    def format_ip(request)
      return 'N/A' unless request
      "IP:#{request.remote_ip}"
    end

    def format_location(backtrace)
      return nil unless backtrace&.any?
      backtrace.first.gsub(Rails.root.to_s + '/', '')
    end

    def format_context(context)
      return nil if context.blank?
      context.map { |k, v| "#{k}=#{v}" }.join(', ')
    end

    def parse_log_line(line)
      # Формат: [TIMESTAMP] [LEVEL] [USER] [IP] [ERROR_TYPE] Message | Details [Location]
      match = line.match(/\[(.*?)\] \[(.*?)\] \[(.*?)\] \[(.*?)\] \[(.*?)\] (.*)/)
      return nil unless match

      timestamp, level, user, ip, error_type, rest = match.captures

      # Разбиваем сообщение и детали
      message_parts = rest.split(' | ')
      message = message_parts[0]
      details = message_parts[1]&.split(' [')&.first || ''
      location = rest.match(/\[(.*?)\]$/)&.captures&.first || ''

      {
        timestamp: timestamp,
        level: level,
        user: user,
        ip: ip.gsub('IP:', ''),
        error_type: error_type,
        message: message,
        details: details,
        location: location
      }
    end
  end
end
