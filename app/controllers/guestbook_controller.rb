class GuestbookController < ApplicationController
  before_action :require_login

  # Просмотр сообщений
  def index
    @messages = Guest.order(created_at: :desc)
  end

  # Форма
  def new
    @guest = Guest.new
  end

  def create
    @guest = Guest.new(
      name: sanitize_text(params[:name]),
      email: sanitize_text(params[:email]),
      message: sanitize_message(params[:message]),
      created_at: Time.current
    )

    if @guest.save
      redirect_to guestbook_path, notice: "Сообщение сохранено"
    else
      render :new
    end
  end

  private

  # Полная фильтрация: пропускаются только буквы, цифры, пробелы
  def sanitize_text(str)
    str.to_s.gsub(/[^0-9a-zA-Zа-яА-ЯёЁ@\.\-\_\s]/, "")
  end

  # Для сообщений разрешим безопасный поднабор HTML (жирный, курсив и т.п.)
  # Rails встроенная защита: sanitize()
  def sanitize_message(str)
    ActionController::Base.helpers.sanitize(
      str.to_s,
      tags: %w[b i strong em u br p],
      attributes: []
    )
  end
end
