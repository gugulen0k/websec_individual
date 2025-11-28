# frozen_string_literal: true

# Сервис для журналирования действий пользователей в целях безопасности
#
# Записывает все критичные действия пользователей в лог-файлы:
# - Вход в систему
# - Выход из системы
# - Попытки несанкционированного доступа
# - Изменения в системе
# - Просмотр конфиденциальных данных
#
# Формат лога: [TIMESTAMP] [LEVEL] [USER] [IP] [ACTION] Details
#
# Пример использования:
#   SecurityLogger.log_login(user, request)
#   SecurityLogger.log_logout(user, request)
#   SecurityLogger.log_action(user, "view_admin_panel", request)

class SecurityLogger
  # Директория для хранения логов
  LOG_DIR = Rails.root.join('log', 'security')

  # Уровни логирования
  LEVELS = {
    info: 'INFO',
    warn: 'WARN',
    error: 'ERROR',
    critical: 'CRITICAL'
  }.freeze

  class << self
    # Логирование успешного входа
    def log_login(user, request, details = {})
      log_entry(
        level: :info,
        user: user,
        action: 'LOGIN',
        details: {
          role: user.role.name,
          **details
        },
        request: request
      )
    end

    # Логирование выхода
    def log_logout(user, request, details = {})
      log_entry(
        level: :info,
        user: user,
        action: 'LOGOUT',
        details: details,
        request: request
      )
    end

    # Логирование неудачной попытки входа
    def log_failed_login(login, request, reason = 'Invalid credentials')
      log_entry(
        level: :warn,
        user: nil,
        action: 'FAILED_LOGIN',
        details: {
          login: login,
          reason: reason
        },
        request: request
      )
    end

    # Логирование попытки несанкционированного доступа
    def log_unauthorized_access(user, action, request, details = {})
      log_entry(
        level: :warn,
        user: user,
        action: 'UNAUTHORIZED_ACCESS',
        details: {
          attempted_action: action,
          **details
        },
        request: request
      )
    end

    # Логирование любого действия пользователя
    def log_action(user, action, request, details = {}, level: :info)
      log_entry(
        level: level,
        user: user,
        action: action.to_s.upcase,
        details: details,
        request: request
      )
    end

    # Логирование изменения данных
    def log_data_change(user, resource, action, request, details = {})
      log_entry(
        level: :info,
        user: user,
        action: "#{action.upcase}_#{resource.upcase}",
        details: details,
        request: request
      )
    end

    # Логирование ошибки безопасности
    def log_security_event(event, user, request, details = {})
      log_entry(
        level: :critical,
        user: user,
        action: "SECURITY_EVENT: #{event}",
        details: details,
        request: request
      )
    end

    # Чтение логов за определенный период
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
      Rails.logger.error("Error reading logs: #{e.message}")
      []
    end

    # Чтение всех доступных лог-файлов
    def available_log_files
      ensure_log_directory
      Dir.glob(LOG_DIR.join('security_*.log')).sort.reverse.map do |file|
        {
          path: file,
          name: File.basename(file),
          date: extract_date_from_filename(file),
          size: File.size(file),
          modified_at: File.mtime(file)
        }
      end
    end

    # Поиск в логах
    def search_logs(query, date = Date.today)
      log_file = log_file_path(date)
      return [] unless File.exist?(log_file)

      results = []
      File.readlines(log_file).each do |line|
        results << parse_log_line(line) if line.include?(query)
      end
      results.compact
    end

    # Статистика за день
    def daily_statistics(date = Date.today)
      logs = read_logs(date, limit: Float::INFINITY)

      {
        total_events: logs.count,
        logins: logs.count { |l| l[:action] == 'LOGIN' },
        logouts: logs.count { |l| l[:action] == 'LOGOUT' },
        failed_logins: logs.count { |l| l[:action] == 'FAILED_LOGIN' },
        unauthorized_attempts: logs.count { |l| l[:action] == 'UNAUTHORIZED_ACCESS' },
        unique_users: logs.map { |l| l[:user] }.compact.uniq.count,
        unique_ips: logs.map { |l| l[:ip] }.compact.uniq.count,
        events_by_hour: group_by_hour(logs)
      }
    end

    private

    # Основной метод записи в лог
    def log_entry(level:, user:, action:, details:, request:)
      ensure_log_directory

      timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S.%3N')
      level_str = LEVELS[level] || 'INFO'
      user_str = user ? "#{user.login}(ID:#{user.id})" : 'ANONYMOUS'
      ip = extract_ip(request)
      user_agent = request&.user_agent || 'Unknown'

      # Формируем строку лога
      log_line = [
        "[#{timestamp}]",
        "[#{level_str}]",
        "[#{user_str}]",
        "[IP:#{ip}]",
        "[#{action}]",
        format_details(details),
        "[UserAgent:#{truncate(user_agent, 100)}]"
      ].join(' ')

      # Записываем в файл
      File.open(log_file_path, 'a') do |f|
        f.puts log_line
      end

      # Также пишем в Rails logger для отладки
      Rails.logger.info "[SecurityLog] #{log_line}"

      true
    rescue => e
      # Если не удалось записать в security лог, пишем в основной
      Rails.logger.error "Failed to write security log: #{e.message}"
      false
    end

    # Путь к файлу лога за текущий день
    def log_file_path(date = Date.today)
      LOG_DIR.join("security_#{date.strftime('%Y%m%d')}.log")
    end

    # Создаём директорию для логов если не существует
    def ensure_log_directory
      FileUtils.mkdir_p(LOG_DIR) unless Dir.exist?(LOG_DIR)
    end

    # Извлечение IP адреса из request
    def extract_ip(request)
      return 'N/A' unless request

      # Проверяем заголовки прокси
      request.headers['X-Forwarded-For']&.split(',')&.first&.strip ||
        request.headers['X-Real-IP'] ||
        request.remote_ip ||
        'Unknown'
    end

    # Форматирование деталей для лога
    def format_details(details)
      return '' if details.blank?

      details.map { |k, v| "#{k}=#{v}" }.join(', ')
    end

    # Обрезка строки
    def truncate(str, length)
      str.length > length ? "#{str[0...length]}..." : str
    end

    # Парсинг строки лога
    def parse_log_line(line)
      # Формат: [TIMESTAMP] [LEVEL] [USER] [IP:xxx] [ACTION] details [UserAgent:xxx]
      match = line.match(/\[([^\]]+)\] \[([^\]]+)\] \[([^\]]+)\] \[IP:([^\]]+)\] \[([^\]]+)\](.*)/)
      return nil unless match

      {
        timestamp: match[1],
        level: match[2],
        user: match[3],
        ip: match[4],
        action: match[5],
        details: match[6]&.strip,
        raw: line
      }
    end

    # Извлечение даты из имени файла
    def extract_date_from_filename(filename)
      match = filename.match(/security_(\d{8})\.log/)
      return Date.today unless match

      Date.parse(match[1])
    rescue
      Date.today
    end

    # Группировка логов по часам
    def group_by_hour(logs)
      logs.group_by do |log|
        Time.parse(log[:timestamp]).hour rescue 0
      end.transform_values(&:count)
    end
  end
end
