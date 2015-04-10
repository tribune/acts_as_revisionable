# Install gems for all appraisal definitions:
#
#     $ appraisal install
#
# To run tests on different versions:
#
#     $ appraisal activerecord-x.x rake spec
#
# OR
#
#     $ appraisal activerecord-x.x rspec spec
#
# To test multiple versions:
#
#     $ for ver in 4.0 4.1; do appraisal activerecord-$ver rspec spec; done

[
  [ '4.0', '~> 4.0.0' ],
  [ '4.1', '~> 4.1.0' ],
  [ '4.2', '~> 4.2.0' ],
].each do |ver_name, ver_req|
  appraise "activerecord-#{ver_name}" do
    gem 'activerecord', ver_req
    # attr_protected / attr_accessible moved to external gem in rails 4.
    # It's not a runtime dependency, but we need to make sure our code works with it.
    gem 'protected_attributes'
  end
end
