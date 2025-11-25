class AdminController < ApplicationController
  before_action :require_admin

  def dashboard; end
  def feature1; end
  def feature2; end
  def feature3; end
end
