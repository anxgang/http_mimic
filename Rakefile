# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'lib' << 'test'
  t.test_files = FileList['test/test_*.rb'].exclude('test/test_live_*.rb')
  t.verbose = false
end

namespace :test do
  Rake::TestTask.new(:live) do |t|
    t.libs << 'lib' << 'test'
    t.pattern = 'test/test_live_fingerprint.rb'
    t.verbose = true
  end

  Rake::TestTask.new(:all) do |t|
    t.libs << 'lib' << 'test'
    t.pattern = 'test/test_*.rb'
    t.verbose = true
  end
end

task default: :test
