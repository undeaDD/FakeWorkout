import UIKit
import HealthKit

class ViewController: UIViewController {
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var valueField: UITextField!
    @IBOutlet weak var button: UIButton!
    
    private var isDisabled = true
    private var isRunning = false
    private var builder: HKWorkoutBuilder?
    private var healthStore = HKHealthStore()
    private let allTypes = Set([
        HKObjectType.workoutType(),
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
    ])
    
    // open activity app
    @IBAction func openActivityApp(_ sender: UIBarButtonItem) {
        UIApplication.shared.open(URL(string: "activitysharing://")!)
    }

    // start / stop workout
    @IBAction func buttonPressed(_ sender: UIButton) {
        // check healthkit authorization
        if isDisabled { print("healthkit not authorized") }
        
        if isRunning {
            // end workouot collection
            builder?.endCollection(withEnd: Date()) { success, error in
                if let error { print(error.localizedDescription) }
                print("end Workout: \(success)")
                
                if success {
                    // end workout
                    self.builder?.finishWorkout(completion: { workout, error in
                        if let error { print(error.localizedDescription) }
                        print("finished Workout: \(workout?.duration ?? -1)")
                    })
                }
            }
            
            // update button and image
            button.backgroundColor = .systemBlue
            button.setTitle("Begin Workout", for: .normal)
            imageView.image = UIImage(named: "fat")
        } else {
            // start workout
            builder?.beginCollection(withStart: Date()) { success, error in
                if let error { print(error.localizedDescription) }
                print("begin Workout: \(success)")
            }
            
            // update button and image
            button.backgroundColor = .systemRed
            button.setTitle("End Workout", for: .normal)
            imageView.image = UIImage(named: "sumo")
        }
        
        isRunning = !isRunning
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // style textfield
        let suffix = UILabel(frame: CGRect(x: 0, y: 0, width: 0, height: 45))
        suffix.text = " kcal   "
        valueField.rightView = suffix
        valueField.rightViewMode = .always
        
        // add tap to close keyboard gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(hideKeyboard))
        view.addGestureRecognizer(tapGesture)

        // request healthkit authorization
        healthStore.requestAuthorization(toShare: allTypes, read: allTypes) { (success, error) in
            if let error { print(error.localizedDescription) }
            print("request Auth: \(success)")
            
            if success {
                DispatchQueue.main.async {
                    // style and enable button
                    self.button.backgroundColor = .systemBlue
                    self.isDisabled = false

                    // configure workout session
                    let workoutConfig = HKWorkoutConfiguration()
                    workoutConfig.locationType = .indoor
                    workoutConfig.activityType = .other
                    
                    // instanciate workout builder object
                    self.builder = HKWorkoutBuilder(healthStore: self.healthStore, configuration: workoutConfig, device: .local())
                }
            }
        }
        
        // start repeating timer
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            if self.isRunning && !self.isDisabled {
                // get value and configure sample data
                let value = Double(self.valueField.text ?? "10.0") ?? 10.0
                let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
                let quantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: value)
                
                // create workout sample data
                let sample = HKCumulativeQuantitySample(type: type, quantity: quantity, start: Date(), end: Date())
                
                // add data to current workout
                self.builder?.add([sample]) { success, error in
                    if let error { print(error.localizedDescription) }
                    print("add Sample: \(success) -> \(value) kcal")
                }
            }
        }
    }

    @objc func hideKeyboard() {
        view.endEditing(true)
    }
}
