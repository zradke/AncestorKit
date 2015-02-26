Pod::Spec.new do |s|
  s.name         = "AncestorKit"
  s.version      = "0.1.0"
  s.summary      = "Inherit properties from ancestors to limit configuration."
  s.homepage     = "https://github.com/zradke/AncestorKit"
  s.license      = 'MIT'
  s.author       = { "Zach Radke" => "zach.radke@gmail.com" }
  s.source       = { :git => "https://github.com/zradke/AncestorKit.git", :tag => s.version.to_s }
  s.platform     = :ios, '7.0'
  s.requires_arc = true
  s.source_files = 'Pod/Classes/**/*'
end
