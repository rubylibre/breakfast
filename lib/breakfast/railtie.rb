require "rails"
require "listen"

module BrunchRails
  class Railtie < ::Rails::Railtie
    config.breakfast = ActiveSupport::OrderedOptions.new

    config.before_configuration do |app|
      config.breakfast.html_reload_strategy = :turbolinks
      config.breakfast.js_reload_strategy = :page
      config.breakfast.css_reload_strategy = :hot
      config.breakfast.ruby_reload_strategy = :off

      config.breakfast.asset_output_folder = Rails.root.join("public", "assets")
      config.breakfast.source_code_folders = [Rails.root.join("app")]
      config.breakfast.environments = %w(development)
      config.breakfast.status_bar_location = :bottom
      config.breakfast.digest = !(Rails.env.development? || Rails.env.test?)

      if config.breakfast.digest
        config.breakfast.manifest = Breakfast::Manifest.new(base_dir: config.breakfast.asset_output_folder)
      end
    end

    initializer "breakfast.setup_view_helpers" do |app|
      ActiveSupport.on_load(:action_view) do
        include ::Breakfast::ViewHelper
      end
    end

    rake_tasks do
      load "tasks/breakfast.rake"
    end

    config.after_initialize do |app|
      if config.breakfast.environments.include?(Rails.env) && defined?(Rails::Server)
        Thread.new do
          Breakfast::BrunchWatcher.spawn(log: Rails.logger)
        end

        Breakfast::CompilationListener.start(
          asset_output_folder: config.breakfast.asset_output_folder,
          source_code_folders: config.breakfast.source_code_folders
        )
      end
    end

    ActionView::Helpers::AssetUrlHelper::ASSET_PUBLIC_DIRECTORIES[:javascript] = "/assets"
    ActionView::Helpers::AssetUrlHelper::ASSET_PUBLIC_DIRECTORIES[:image] = "/assets"
    ActionView::Helpers::AssetUrlHelper::ASSET_PUBLIC_DIRECTORIES[:stylesheet] = "/assets"
  end
end
