require "spec_helper"
require "tmpdir"
require "json"

RSpec.describe Breakfast::Manifest do
  before do
    allow_any_instance_of(Digest::MD5).to receive(:hexdigest).and_return("digest")
    allow(SecureRandom).to receive(:hex) { "digest" }
  end

  let(:output_dir) { Dir.mktmpdir }

  it "will generate a manifest file and comiple digested assets" do
    Dir.mkdir("#{output_dir}/images/")

    app_js = File.open("#{output_dir}/app.js", "w")
    image = File.open("#{output_dir}/images/test.jpeg", "w")

    manifest = Breakfast::Manifest.new(base_dir: output_dir)
    manifest.digest!

    expect(File).to exist("#{output_dir}/app.js")
    expect(File).to exist("#{output_dir}/app-digest.js")

    expect(File).to exist("#{output_dir}/images/test.jpeg")
    expect(File).to exist("#{output_dir}/images/test-digest.jpeg")

    expect(JSON.parse(File.read("#{output_dir}/.manifest-digest.json"))).to eq({
      "app.js" => "app-digest.js",
      "images/test.jpeg" => "images/test-digest.jpeg"
    })
  end

  it "will not fingerprint already fingerprinted assets" do
    File.open("#{output_dir}/app-523a40ea7f96cd5740980e61d62dbc77.js", "w")

    manifest = Breakfast::Manifest.new(base_dir: output_dir)
    manifest.digest!

    expect(File).to exist("#{output_dir}/app-523a40ea7f96cd5740980e61d62dbc77.js")
    expect(number_of_files(output_dir)).to eq(1)
  end

  it "will find an existing manifest" do
    File.open("#{output_dir}/.manifest-869269cdf1773ff0dec91bafb37310ea.json", "w") do |file| 
      file.write({ "app.js" => "app-abc123.js" }.to_json)
    end

    manifest = Breakfast::Manifest.new(base_dir: output_dir)

    expect(manifest.asset("app.js")).to eq("app-abc123.js")
  end

  it "will return the digested asset path for a given asset" do
    Dir.mkdir("#{output_dir}/images/")

    app_js = File.open("#{output_dir}/app.js", "w")
    image = File.open("#{output_dir}/images/test.jpeg", "w")

    manifest = Breakfast::Manifest.new(base_dir: output_dir)
    manifest.digest!

    expect(manifest.asset("app.js")).to eq("app-digest.js")
    expect(manifest.asset("images/test.jpeg")).to eq("images/test-digest.jpeg")
    expect(manifest.asset("doesnt-exist.png")).to be nil
  end

  it "will remove assets that are no longer referenced by the manifest" do
    Dir.mkdir("#{output_dir}/images/")

    File.open("#{output_dir}/outdated-523a40ea7f96cd5740980e61d62dbc77.js", "w")
    File.open("#{output_dir}/app.js", "w")
    File.open("#{output_dir}/images/test.jpeg", "w")
    File.open("#{output_dir}/images/outdated-523a40ea7f96cd5740980e61d62dbc77.jpeg", "w")

    manifest = Breakfast::Manifest.new(base_dir: output_dir)
    manifest.digest!

    expect { manifest.clean! }.to change { number_of_files(output_dir) }.by(-2)
  end

  def number_of_files(dir)
    Dir["#{dir}/**/*"].reject { |f| File.directory?(f) }.size
  end
end
