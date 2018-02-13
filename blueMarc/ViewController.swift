//
//  ViewController.swift
//  blueMarc
//
//  Created by Tomas Vega on 12/7/17.
//  Copyright © 2017 Tomas Vega. All rights reserved.
//

import UIKit
import CoreBluetooth
import CoreMotion

class ViewController: UIViewController,
                      CBCentralManagerDelegate,
                      CBPeripheralDelegate {
  
  var manager:CBCentralManager!
  var _peripheral:CBPeripheral!
  var sendCharacteristic: CBCharacteristic!
  var loadedService: Bool = true
  
  let NAME = "RFduino"
  let UUID_SERVICE = CBUUID(string: "2220")
  let UUID_READ = CBUUID(string: "2221")
  let UUID_WRITE = CBUUID(string: "2222")
  
  @IBOutlet weak var stateInput: UISwitch!
  @IBOutlet weak var intensityInput: UIStepper!
  @IBOutlet weak var intensityLabel: UILabel!
  @IBOutlet weak var modeInput: UIButton!
  
  @IBOutlet weak var xLabel: UILabel!
  @IBOutlet weak var yLabel: UILabel!
  @IBOutlet weak var zLabel: UILabel!
  
  var xAvg: Int = 0
  var yAvg: Int = 0
  var zAvg: Int = 0
  
  var prevState: Bool = false
  
  var xPrev: Int = 0
  var yPrev: Int = 0
  var zPrev: Int = 0
  var counter: Int = 0
  
  var stateValue: Bool = false
  var modeValue: Int = 0
  var timer: Timer = Timer()
  
  func getData() -> NSData{
    let state: UInt8 = stateValue ? 1 : 0
    let intensity: UInt8 = UInt8(intensityInput.value)
    let mode: UInt8 = UInt8(modeValue)
    var theData : [UInt8] = [ state, intensity, mode ]
    print(theData)
    let data = NSData(bytes: &theData, length: theData.count)
    return data
  }
  

  func updateSettings() {
    if loadedService {
      if _peripheral?.state == CBPeripheralState.connected {
        if let characteristic:CBCharacteristic? = sendCharacteristic{
          let data: Data = getData() as Data
          _peripheral?.writeValue(data,
                                  for: characteristic!,
                                  type: CBCharacteristicWriteType.withResponse)
        }
      }
    }
  }
  
  @IBAction func stateChanged(_ sender: UISwitch) {
    print("STATE CHANGED")
    stateValue = stateInput.isOn
    print(stateValue)
    if !stateValue {
      intensityInput.value = 0;
      intensityLabel.text = Int(intensityInput.value).description
    } else {

    }
    updateSettings()
  }

  
  
  @IBAction func intensityChanged(_ sender: UIStepper) {
    intensityLabel.text = Int(sender.value).description
    updateSettings()
  }
  
  @IBAction func modePressed(_ sender: UIButton) {
    modeValue = (modeValue + 1) % 7
    updateSettings()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    manager = CBCentralManager(delegate: self, queue: nil)
    stateInput.setOn(false, animated: false)

    
    // Do any additional setup after loading the view, typically from a nib.
    stateValue = stateInput.isOn
    intensityInput.wraps = false
    intensityInput.autorepeat = true
    intensityInput.maximumValue = 10
    
    startAccelerometers()
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    if central.state == CBManagerState.poweredOn {
      print("Buscando a Marc")
      central.scanForPeripherals(withServices: nil, options: nil)
    }
  }
  
  // Found a peripheral
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//    print("found a peripheral")
    // Device
    let device = (advertisementData as NSDictionary).object(forKey: CBAdvertisementDataLocalNameKey) as? NSString
    // Check if this is the device we want
    if device?.contains(NAME) == true {

      // Stop looking for devices
      // Track as connected peripheral
      // Setup delegate for events
      self.manager.stopScan()
      self._peripheral = peripheral
      self._peripheral.delegate = self
      
      // Connect to the perhipheral proper
      manager.connect(peripheral, options: nil)
      
      // Debug
      debugPrint("Found Bean.")
    }
  }
  
  // Connected to peripheral
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    // Ask for services
    peripheral.discoverServices(nil)
    
    // Debug
    debugPrint("Getting services ...")
  }
  
  // Discovered peripheral services
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    // Look through the service list
    for service in peripheral.services! {
      let thisService = service as CBService
      
      // If this is the service we want
      print(service.uuid)
      if service.uuid == UUID_SERVICE {
        // Ask for specific characteristics
        peripheral.discoverCharacteristics(nil, for: thisService)
        
        // Debug
        debugPrint("Using scratch.")
      }
      
      // Debug
      debugPrint("Service: ", service.uuid)
    }
  }
  
  // Discovered peripheral characteristics
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    debugPrint("Enabling ...")
    
    // Look at provided characteristics
    for characteristic in service.characteristics! {
      let thisCharacteristic = characteristic as CBCharacteristic
      
      // If this is the characteristic we want
      print(thisCharacteristic.uuid)
      if thisCharacteristic.uuid == UUID_READ {
        // Start listening for updates
        // Potentially show interface
        self._peripheral.setNotifyValue(true, for: thisCharacteristic)
        
        // Debug
        debugPrint("Set to notify: ", thisCharacteristic.uuid)
      } else if thisCharacteristic.uuid == UUID_WRITE {
        sendCharacteristic = thisCharacteristic
        loadedService = true
      }
      
      // Debug
      debugPrint("Characteristic: ", thisCharacteristic.uuid)
    }
  }
  
  // Data arrived from peripheral
  func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    print("Data")
    // Make sure it is the peripheral we want
    print(characteristic.uuid)
    if characteristic.uuid == UUID_READ {
      // Get bytes into string
      let dataReceived = characteristic.value! as NSData
      var out1: UInt32 = 0
      var out2: UInt32 = 0
      var out3: UInt32 = 0
      dataReceived.getBytes(&out1, range: NSRange(location: 0, length: 4))
      dataReceived.getBytes(&out2, range: NSRange(location: 4, length: 4))
      dataReceived.getBytes(&out3, range: NSRange(location: 8, length: 4))
      print(out1)
      print(out2)
      print(out3)
//
//      let firstChunk = characteristic.value![0...3]
//      var values = [UInt32](repeating: 0, count:characteristic.value!.count)
//      let myData = [UInt32](values)
//      print(myData)
////
//      // Convert bytes to integer (we know this number)
//      print(firstChunk)
//      var firstBuffer: Int = 0
//      let numberFromChunk = d.getBytes(&firstBuffer, length: 4)
////      firstChunk.getBytes(&firstBuffer, length: 4)
      
//      print(numberFromChunk)
      
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
    print("success")
    print(characteristic.uuid)
    print(error)
  }
  
  // Peripheral disconnected
  // Potentially hide relevant interface
  func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
    debugPrint("Disconnected.")
    
    // Start scanning again
    central.scanForPeripherals(withServices: nil, options: nil)
  }
  
  let motion = CMMotionManager()
  
  func startAccelerometers() {
    // Make sure the accelerometer hardware is available.
    if self.motion.isAccelerometerAvailable {
      self.motion.accelerometerUpdateInterval = 1.0 / 60.0  // 60 Hz
      self.motion.startAccelerometerUpdates()
      
      // Configure a timer to fetch the data.
      self.timer = Timer(fire: Date(), interval: (1.0/60.0),
                         repeats: true, block: { (timer) in
                          // Get the accelerometer data.
                          if let data = self.motion.accelerometerData {
                            let x: Int = Int(data.acceleration.x*100)
                            let y: Int = Int(data.acceleration.y*100)
                            let z: Int = Int(data.acceleration.z*100)
                            // Use the accelerometer data in your app.
                            self.xLabel.text = x.description
                            self.yLabel.text = y.description
                            self.zLabel.text = z.description
                            
                            self.xAvg = Int(Double(self.xAvg) * 0.999 + Double(x) * 0.001)
                            self.yAvg = Int(Double(self.yAvg) * 0.999 + Double(y) * 0.001)
                            self.zAvg = Int(Double(self.zAvg) * 0.999 + Double(z) * 0.001)
//                            print(self.xAvg, self.yAvg, self.zAvg)
                            let thresh: Int = 40
                            if (abs(x - self.xPrev) > thresh ||
                                abs(y - self.yPrev) > thresh ||
                                abs(z - self.zPrev) > thresh) {
                              print("active")
                              if (!self.prevState) {
                                self.counter = 0
                                self.stateValue = true
                                self.updateSettings()
                                self.intensityInput.value = 4
                                self.updateSettings()
                              }
                              self.prevState = true
                            } else {
                              self.counter = self.counter + 1
                              if (self.counter == thresh) {
                                print("inactive")
                                self.stateValue = false
                                self.updateSettings()
                                self.intensityInput.value = 0
                                self.updateSettings()
                              }
                              self.prevState = false
                            }
                            print(self.counter)
                            self.xPrev = x
                            self.yPrev = y
                            self.zPrev = z
                          }
      })
      
      // Add the timer to the current run loop.
      RunLoop.current.add(self.timer, forMode: .defaultRunLoopMode)
    }
  }

}

