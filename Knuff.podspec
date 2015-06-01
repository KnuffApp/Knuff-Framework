Pod::Spec.new do |s|
  s.name         = "Knuff"
  s.version      = "1.0"
  s.summary      = "Automatic token detection support to use together with the Knuff Mac app."

  s.homepage     = "http://github.com/KnuffApp"
  
	s.license      = { :type => "MIT", :file => "LICENSE" }

  s.author             = { "Bowtie" => "howdy@madebybowtie.com" }
  s.social_media_url   = "http://twitter.com/madebybowtie"
  
	s.platform     = :ios, "7.0"

  s.source       = { :git => "https://github.com/KnuffApp/Knuff-Framework.git", :tag => "1.0" }
  s.source_files  = "Knuff/*.m"
end
