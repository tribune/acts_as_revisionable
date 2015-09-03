# Install gems for all appraisal definitions:
#
#     $ appraisal install
#
# To run tests on different versions:
#
#     $ appraisal activerecord_x.x rspec spec

# NOTE: ruby 2.2.2 requires rails 3.2.22+
[
  [ '3.1', '~> 3.1.0' ],
  [ '3.2', '~> 3.2.0' ],
].each do |ver_name, ver_req|
  # Note: for the rake task to work, these definition names must be the same as the corresponding
  # filename produced in "gemfiles/", i.e. all characters must be in this set: [A-Za-z0-9_.]
  appraise "activerecord_#{ver_name}" do
    gem 'activerecord', ver_req
  end
end
