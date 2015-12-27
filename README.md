The Nuimo controller is an intuitive controller for your computer and connected smart devices. This document demonstrates how to integrate your iOS and MacOS applications with Nuimo controllers using the Nuimo Swift SDK.

## Installation
[The Nuimo Swift SDK is available](https://cocoapods.org/pods/NuimoSwift) through [CocoaPods](https://cocoapods.org/), a very good dependency manager for Swift and Objective-C applications. (If you don't want to use CocoaPods just copy all `.swift` files from folder `SDK` into your Xcode project and skip to the next step.)

##### Prepare your project to use CocoaPods
If you haven't set up your project yet to use CocoaPods, please follow these steps first:

1. Install CocoaPods itself (if not yet installed). Open a terminal and run: `sudo gem install cocoapods`

2. Close Xcode

3. Create a file inside your project's root folder named `Podfile` and paste the following content. Make sure to adopt the right platform:

        platform :ios, '8.0'
        #Use the following line instead if you're developing for MacOS:
        #platform :osx, '10.9'
        use_frameworks!

4. From now on always open the workspace file `<YourProject>.xcworkspace` in Xcode. Otherwise the just added CocoaPods dependencies won't be available (see next step)

##### Add a dependency to the NuimoSwift SDK
Edit your project's `Podfile` to add the following line:
```
pod 'NuimoSwift', '~> 0.3.0'
```
Then from a terminal within your project's root folder run:
```bash
pod install
```
This should install the Nuimo Swift SDK and add it to your workspace. Now open your project's workspace and start playing around with the Nuimo Swift SDK. Don't forget to import the module `NuimoSwift` where necessary.

## Usage

#### Basic usage

The Nuimo SDK makes it very easy to connect your iOS and MacOS applications with Nuimo controllers. It only takes three steps and a very few lines of code to discover your Nuimo and receive gesture events:

1. Assign a delegate to an instance of `NuimoDiscoveryManager` and call `startDiscovery()`. This will discover Nuimo controllers nearby.

2. Receive discovered controllers by implementing the delegate method `nuimoDiscoveryManager:didDiscoverNuimoController:`. Here you can 
    1. Set the delegate of the discovered controller
    2. Initiate the Bluetooth connection to the discovered controller by calling `connect()`

3. Implement the delegate method `nuimoController:didReceiveGestureEvent:` to access user events performed with the Nuimo controller

The following code example demonstrates how to discover, connect and receive gesture events from your Nuimo. As you might know, use either `UIViewController` on iOS or `NSViewController` on MacOS systems.

#### Example code

```swift
import NuimoSwift

class ViewController : UIViewController|NSViewController, NuimoDiscoveryDelegate, NuimoControllerDelegate {
    let discovery = NuimoDiscoveryManager.sharedManager
    
    override func viewDidLoad() {
        super.viewDidLoad()
        discovery.delegate = self
        discovery.startDiscovery()
    }
    
    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController) {
        controller.delegate = self
        controller.connect()
    }
    
    func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent) {
        print("Received event: \(event.gesture.identifier), value: \(event.value)")
    }
}
```

#### A ready to checkout MacOS demo application

We've provided a ready to checkout application that demonstrates discovering, connecting and receiving events from your Nuimo controllers. Simply clone the [Nuimo MacOS demo repository](https://github.com/getSenic/nuimo-swift-demo-osx), open the included Xcode workspace and hit the _Run_ button to execute the application. Before that, make sure that the correct target `NuimoDemoOSX` is selected.

## Advanced use cases
The NuimoSwift SDK is much more powerful than the use cases presented above. More details to follow here soon.

## Contact & Support
Have questions or suggestions? Drop us a mail at developers@senic.com. We'll be happy to hear from you.

## License
The NuimoSwift source code is available under the MIT License.
