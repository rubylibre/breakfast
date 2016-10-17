require "json"
require "digest"
require "fileutils"

module Breakfast
  class Manifest
    MANIFEST_REGEX = /^\.manifest-[0-9a-f]{32}.json$/
    FINGERPRINT_REGEX = /-[0-9a-f]{32}./

    attr_reader :base_dir, :manifest_path, :mappings
    def initialize(base_dir:)
      FileUtils.mkdir_p(base_dir)

      @base_dir = Pathname.new(base_dir)
      @manifest_path = find_manifest_or_create
      @mappings = update_mappings!
    end

    def asset(path)
      mappings[path]
    end

    # The #digest! method will run through all of the compiled assets and
    # create a copy of each asset with a digest fingerprint. This fingerprint
    # will change whenever the file contents change. This allows a us to use
    # HTTP headers to cache these assets as we will be able to reliably know
    # when they change.
    #
    # These fingerprinted files are copies of the original. The originals are
    # not removed and still available should the need arise to serve a
    # non-fingerprinted asset.
    #
    # Example manifest:
    # {
    #   app.js => app-76c6ee161ba431e823301567b175acda.js,
    #   images/logo.png => images/logo-869269cdf1773ff0dec91bafb37310ea.png,
    # }
    #
    # Resulting File Structure:
    # - /
    #   - app.js
    #   - app-76c6ee161ba431e823301567b175acda.js
    #   - images/
    #     - logo.png
    #     - logo-869269cdf1773ff0dec91bafb37310ea.png
    def digest!
      assets = asset_paths.map do |path|
        digest = Digest::MD5.new
        digest.update(File.read("#{base_dir}/#{path}"))

        digest_path = "#{path.sub_ext('')}-#{digest.hexdigest}#{File.extname(path)}"

        FileUtils.cp("#{base_dir}/#{path}", "#{base_dir}/#{digest_path}")

        [path, digest_path]
      end

      File.open(manifest_path, "w") do |manifest| 
        manifest.write(assets.to_h.to_json)
      end

      update_mappings!
    end

    # Remove any files not directly referenced by the manifest.
    def clean!
      all_files = Dir["#{base_dir}/**/*"].reject { |path| File.directory?(path) }
      files_to_keep = mappings.keys.concat(mappings.values)

      files_to_delete = all_files.select do |file|
        !Pathname(file).relative_path_from(base_dir).to_s.in?(files_to_keep)
      end

      files_to_delete.each do |file|
        FileUtils.rm(file)
      end
    end

    # Remove manifest, any fingerprinted files.
    def nuke!
      Dir["#{base_dir}/**/*"]
        .select { |path| path =~ FINGERPRINT_REGEX }
        .each { |file| FileUtils.rm(file) }

      FileUtils.rm(manifest_path)
    end

    private

    def update_mappings!
      @mappings = JSON.parse(File.read(manifest_path))
    end

    # Creates a or finds a manifest file in a given directory. The manifest
    # file is is prefixed with a dot ('.') and given a random string to ensure
    # the file is not served or easily discoverable.
    def find_manifest_or_create
      if (manifest = Dir.entries("#{base_dir}").detect { |entry| entry =~ MANIFEST_REGEX })
        "#{base_dir}/#{manifest}"
      else
        manifest = "#{base_dir}/.manifest-#{SecureRandom.hex(16)}.json"
        File.open(manifest, "w") { |manifest| manifest.write({}.to_json) }
        manifest
      end
    end

    def asset_paths
      Dir["#{base_dir}/**/*"]
        .reject { |path| File.directory?(path) || path =~ FINGERPRINT_REGEX }
        .map { |file| Pathname(file).relative_path_from(base_dir) }
    end
  end
end
