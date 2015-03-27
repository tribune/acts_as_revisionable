require 'bundler/gem_tasks'
require 'pathname'

# Important: For safety, we must chdir into this because we're modifying files
GEM_DIR = Pathname.new(__FILE__).parent

# NOTE: this deletes Gemfile.lock
# Raises if tests couldn't be run or did not pass.
def test_with_ar_version(ver_spec = :default)
  passed = false
  with_ver_spec(ver_spec) do
    Dir.chdir GEM_DIR
  
    # We want to delete Gemfile.lock even for :default, in case a previous test left it around
    FileUtils.rm_f GEM_DIR.join('Gemfile.lock')
  
    # 'bundle check' avoids unnecessarily contacting the rubygems server, but it
    # may not test the newest version that conforms to the ver_spec.
    if system "bundle check || bundle install"
      passed = system "bundle exec rspec spec"
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
  end
  raise "-----> ERROR: Tests failed for AR version #{ver_spec}" unless passed
end

def with_ver_spec(ver_spec = :default)
  is_ver_spec_custom = (ver_spec != :default)
  ENV['ACTS_AS_REVISIONABLE_AR_VER'] = ver_spec  if is_ver_spec_custom

  yield

  if is_ver_spec_custom
    ENV.delete('ACTS_AS_REVISIONABLE_AR_VER')
    # To enable debug, use "ruby -d -S rake ..."
    if $DEBUG
      puts "(debug) Skipping delete of Gemfile.lock - make sure you delete it manually"
    else
      puts "Note: Deleting Gemfile.lock"
      FileUtils.rm_f GEM_DIR.join('Gemfile.lock')
    end
  end
end

# Will test with the latest compatible AR that's currently installed.
task :test_ar_default do
  test_with_ar_version :default
end

single_ver_tasks = []
[
  ['3.0', '~> 3.0.20'],  # FIXME currently broken, or should we drop support?
  ['3.1', '~> 3.1.0' ],
  ['3.2', '~> 3.2.0' ],
  ['4.0', '~> 4.0.0' ],  # TODO make compatible
  ['4.1', '~> 4.1.0' ],  # TODO make compatible
  ['4.2', '~> 4.2.0' ],  # TODO make compatible
].each do |ver_name, ver_spec|
  ver_label = ver_name.gsub(/\W/, '_')
  task_name = "test_with_ar_#{ver_label}"
  task task_name do
    test_with_ar_version ver_spec
  end
  single_ver_tasks << task_name
end

task :test_all_ar_versions => single_ver_tasks do
  # each ver task will raise on failure
  puts "-----> All versions passed"
end

task :default => :test_all_ar_versions
