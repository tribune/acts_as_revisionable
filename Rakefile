require 'bundler/gem_tasks'
require 'pathname'

# Important: For safety, we must chdir into this because we're modifying files
GEM_DIR = Pathname.new(__FILE__).parent

# NOTE: this deletes Gemfile.lock
def test_with_ar_version(ver_spec = :default)
  ENV['ACTS_AS_REVISIONABLE_AR_VER'] = ver_spec  if ver_spec != :default
  Dir.chdir GEM_DIR

  # We want to delete Gemfile.lock even for :default, in case a previous test left it around
  FileUtils.rm_f GEM_DIR.join('Gemfile.lock')

  if system "bundle check || bundle install"
    system "bundle exec rspec spec"
  else
    puts <<-END
===============================================================================
If you're getting this error:
  Bundler could not find compatible versions for gem "activerecord"

Make sure you're not running 'bundle exec rake ...'. This may happen behind your
back if you're using bundler binstubs.
If you're using rbenv-binstubs, try "DISABLE_BINSTUBS=1 rake ..."
===============================================================================
    END
  end

  if ver_spec != :default
    puts "Note: Deleting Gemfile.lock"
    FileUtils.rm_f GEM_DIR.join('Gemfile.lock')
  end
end

task :test do
  test_with_ar_version :default
end

# FIXME currently broken
task :test_with_ar_3_0 do
  test_with_ar_version '~> 3.0.20'
end

task :test_with_ar_3_1 do
  test_with_ar_version '~> 3.1.0'
end

task :test_with_ar_3_2 do
  test_with_ar_version '~> 3.2.0'
end

# TODO make compatible
task :test_with_ar_4_0 do
  test_with_ar_version '~> 4.0.0'
end

# TODO make compatible
task :test_with_ar_4_1 do
  test_with_ar_version '~> 4.1.0'
end

# TODO make compatible
task :test_with_ar_4_2 do
  test_with_ar_version '~> 4.2.0'
end
