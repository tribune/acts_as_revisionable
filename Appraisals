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
#     $ for ver in 3.1 3.2; do appraisal activerecord-$ver rspec spec; done

[
  [ '3.1', '~> 3.1.0' ],
  [ '3.2', '~> 3.2.0' ],
].each do |ver_name, ver_req|
  appraise "activerecord-#{ver_name}" do
    gem 'activerecord', ver_req
  end
end
