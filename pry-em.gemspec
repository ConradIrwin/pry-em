Gem::Specification.new do |s|
  s.name = "pry-em"
  s.version = "0.2.1"
  s.platform = Gem::Platform::RUBY
  s.author = "Conrad Irwin"
  s.email = "conrad.irwin@gmail.com"
  s.homepage = "http://github.com/ConradIrwin/pry-em"
  s.summary = "Provides an em! function that can be used to play with deferrable more easily."
  s.description = "em! is a synchronous wrapper around deferrables, so that you can interact with them as though they were normal function calls."
  s.files = ["lib/pry-em.rb", "README.markdown", "LICENSE.MIT"]
  s.require_path = "lib"
  s.add_dependency 'pry', '> 0.9.8'
  s.add_dependency 'eventmachine'
end
