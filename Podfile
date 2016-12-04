platform :ios, '9.0'
use_frameworks!

source 'https://github.com/CocoaPods/Specs'
source 'https://github.com/angryDuck2/CocoaSpecs'
source 'https://github.com/PopcornTimeTV/Specs'

target "Popcorn Time" do
    pod 'PopcornTorrent', '~> 1.1.1.8'
    pod 'PopcornKit', '~> 3.1.0'

    pod 'Alamofire', '~> 4.0'
    pod 'AlamofireImage', '~> 3.0'
    pod 'AlamofireNetworkActivityIndicator', '~> 2.0'
    pod 'Reachability', '~> 3.2'
    pod 'XCDYouTubeKit', '~> 2.5.3'
    pod 'JGProgressHUD', '~> 1.4'
    pod 'google-cast-sdk', '~> 3.2'
    pod 'OBSlider', '~> 1.1.1'
    pod 'ColorArt', '~> 0.1.1'
    pod '1PasswordExtension', '~> 1.8.4'
    pod 'MobileVLCKit-unstable', '~> 3.0.0a10'
    pod 'SwiftyTimer', '~> 2.0.0'
end

post_install do |installer|
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
          config.build_settings['SWIFT_VERSION'] = '3.0'
        end
    end
end
