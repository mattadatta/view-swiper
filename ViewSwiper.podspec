Pod::Spec.new do |s|
  s.name                  = "ViewSwiper"
  s.version               = "1.0.0"
  s.summary               = "The ViewSwiper allows for the swiping and revealing of views that underly a a draggable view."
  s.homepage              = "https://github.com/mattadatta/viewswiper"
  s.authors               = { "Matthew Brown" => "me.matt.brown@gmail.com" }
  s.license               = { :type => "MIT", :file => 'LICENSE' }

  s.platform              = :ios
  s.ios.deployment_target = "9.0"
  s.requires_arc          = true
  s.source                = { :git => "https://github.com/mattadatta/viewswiper.git", :tag => "v/#{s.version}" }
  s.source_files          = "ViewSwiper/**/*.{swift,h,m}"
  s.module_name           = s.name
end
