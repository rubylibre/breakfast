namespace :breakfast do
  desc "Compile assets for production use"
  task :compile do
    on roles fetch(:breakfast_roles) do |host|
      within release_path do
        execute fetch(:breakfast_npm_path).to_sym, "install"
        execute :rails, "breakfast:assets:build_production"
        execute :rails, "breakfast:assets:digest"
      end
    end
  end

  desc "Remove any unused assets"
  task :clean do
    execute :rails, "breakfast:assets:clean"
  end

 after "deploy:updated", "breakfast:compile"
 after "deploy:publish", "breakfast:clean"
end


namespace :load do
  task :defaults do
    set :breakfast_roles, -> { :web }
    set :breakfast_npm_path, "/usr/bin/npm"
  end
end
