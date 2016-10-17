require "rake"
require "breakfast"

namespace :breakfast do
  namespace :assets do
    desc "Build assets"
    task :build => :environment do
      exec(Breakfast::PRODUCTION_BUILD_COMMAND)
    end

    desc "Build assets for production"
    task :build_production => :environment do
      exec(Breakfast::PRODUCTION_BUILD_COMMAND)
    end

    desc "Add a digest to non-fingerprinted assets"
    task :digest => :environment do
      Rails.configuration.breakfast.manifest.digest!
    end

    desc "Remove out of date assets"
    task :clean => :environment do
      Rails.configuration.breakfast.manifest.clean!
    end

    desc "Remove manifest and fingerprinted assets"
    task :nuke => :environment do
      Rails.configuration.breakfast.manifest.nuke!
    end
  end
end
