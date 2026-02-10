# frozen_string_literal: true

module Heavylog
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.enable_reloading = false
    config.consider_all_requests_local = true
    config.action_controller.perform_caching = false
    config.action_dispatch.show_exceptions = :all
    config.action_controller.allow_forgery_protection = false
    config.active_support.deprecation = :stderr
    config.hosts.clear
  end
end

class CustomException < StandardError; end

class TestController < ActionController::Base
  rescue_from CustomException do
    head :not_found
  end

  def test_action
    Rails.logger.info("logger from action")

    head :ok
  end

  def redirect_action
    redirect_to "http://redirected.com", allow_other_host: true
  end

  def raise_action
    raise StandardError, "This action raises an exception"
  end

  def raise_rescued
    raise CustomException, "This action raises a rescued exception"
  end
end

Rails.application.initialize!

Rails.application.routes.draw do
  get "/test" => "test#test_action"
  get "/ignore" => "test#test_action"
  get "/redirect" => "test#redirect_action"
  get "/raise" => "test#raise_action"
  get "/raise_rescued" => "test#raise_rescued"
end
