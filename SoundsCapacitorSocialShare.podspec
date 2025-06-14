require 'json'

package = JSON.parse(File.read(File.join(__dir__, 'package.json')))

Pod::Spec.new do |spec|
    spec.name         = 'SoundsCapacitorSocialShare'
    spec.version      = package['version']
    spec.summary      = package['summary']
    spec.description  = package['description']
    spec.homepage     = package['repository']['url']
    spec.license      = package['license']
    spec.author       = package['author']
    spec.source       = { :git => package['repository']['url'], :tag => spec.version.to_s }
    spec.source_files = 'ios/Plugin/**/*.{swift,h,m,c,cc,cpp}'
    spec.platform     = :ios, '11.0'
    spec.dependency 'Capacitor', '>= 6.0.0'
    spec.framework = 'Photos', 'AVFoundation', 'Foundation', 'UIKit'
  end