class UserController < ApplicationController
  before_action :require_login

  def dashboard; end
  def feature1; end
  def feature2; end
  def feature3; end
end
