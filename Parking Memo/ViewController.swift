//
//  ViewController.swift
//  Parking Memo
//
//  Created by Odysseus on 03/05/16.
//  Copyright © 2016 Alessio Moretti. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

// UIColor extension utility
extension UIColor {
    convenience init(hex: Int) {
        let r = hex / 0x10000
        let g = (hex - r*0x10000) / 0x100
        let b = hex - r*0x10000 - g*0x100
        self.init(red: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: 1)
    }
}


class ViewController: UIViewController, MKMapViewDelegate,CLLocationManagerDelegate {

    // creating outlet to the map
    @IBOutlet weak var mapView: MKMapView!
    // creating outlet to the segmented control
    @IBOutlet weak var applicationBehaviour: UISegmentedControl!
    // creating outlet to position storage button
    @IBOutlet weak var storageBtn: UIButton!
    // creating outlet to description of position retrieving
    @IBOutlet weak var controlDescription: UILabel!
    // creating outlet to developer info button
    @IBOutlet weak var devBtn: UIButton!
    
    
    // user location on map
    let locationManager: CLLocationManager = CLLocationManager()
    var userLatitude   : Double!
    var userLongitude  : Double!
    var userPrecision  : Double!
    var userAddress    : String!
    var userTimestamp  : String!
    // user location - data persistance
    struct userLocationKey {
        static let latKey = "parking_latitude"
        static let lngKey = "parking_longitude"
        static let pcsKey = "parking_precision"
        static let adrKey = "parking_address"
        static let timKey = "parking_timestamp"
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setting title of the view
        self.title = "Parking Memo"
        self.navigationController?.navigationBar.barTintColor = UIColor(hex: 0xD83E0C)
        self.navigationController?.navigationBar.titleTextAttributes = [NSForegroundColorAttributeName: UIColor.whiteColor()]

        
        // passing control to enable function (when app is active it is enabled by default)
        NSNotificationCenter.defaultCenter().addObserver(self,
                                                         selector: #selector(ViewController.applicationBecameActive(_:)),
                                                         name: UIApplicationDidBecomeActiveNotification,
                                                         object: nil)
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        // initializating the location manager
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.delegate = self
        
        
        // presetting segmented control -> parking retrieval mode
        retrievePosition()
        // hiding the button for position storage
        storageBtn.hidden = true
        // showing the dev info button
        devBtn.hidden = false

    }
    
    /* if segmented control changed, then changed the app behaviour */
    @IBAction func behaviourChanged(sender: UISegmentedControl) {
        switch applicationBehaviour.selectedSegmentIndex
        {
        case 0:
            // parking retrieving mode enabled
            storageBtn.hidden   = true
            devBtn.hidden = false
            
            // deactivating location manager
            locationManager.stopUpdatingLocation()
            // retrieving last position
            retrievePosition()
            break
        case 1:
            // parking storing position mode enabled
            storageBtn.hidden   = false
            devBtn.hidden = true
            
            // resetting user address
            self.userAddress = nil
            
            // description formatting
            let description_string = "aggiornamento posizione..."
            
            // visualizing description
            controlDescription.textAlignment = NSTextAlignment.Center
            controlDescription.text = description_string as String
            
            // removing all annotations from mapview 
            let previousAnnotations = mapView.annotations
            mapView.removeAnnotations(previousAnnotations)
            
            if (isUserLocation()) {
                // activating location manager
                locationManager.startUpdatingLocation()
                // from now... retrieving user location by delegate
            }
            break
        default:
            break
        }
    }
    
    /* storing position on user interaction */
    @IBAction func storePosition(sender: UIButton) {
        // retrieving datetime
        let timestamp = NSDateFormatter.localizedStringFromDate(NSDate(), dateStyle: .MediumStyle, timeStyle: .ShortStyle)

        // user application defaults - storing the position
        let defaults = NSUserDefaults.standardUserDefaults()
        defaults.setValue(self.userLatitude ,   forKey: userLocationKey.latKey)
        defaults.setValue(self.userLongitude,   forKey: userLocationKey.lngKey)
        defaults.setValue(self.userPrecision,   forKey: userLocationKey.pcsKey)
        defaults.setValue(self.userAddress  ,   forKey: userLocationKey.adrKey)
        defaults.setValue(timestamp         ,   forKey: userLocationKey.timKey)
        defaults.synchronize()
    }
    
    /* retrieving stored position */
    func retrievePosition() {
        
        // user application defaults - retrieving the position
        let defaults = NSUserDefaults.standardUserDefaults()
        let ulat: Double!
        let ulng: Double!
        if let user_latitude:  Double = defaults.doubleForKey(userLocationKey.latKey) {
            ulat = user_latitude
            if (ulat == 0.0) {
                // no position routine
                noPositionStored()
                return
            }
        } else { return }
        if let user_longitude: Double = defaults.doubleForKey(userLocationKey.lngKey) {
            ulng = user_longitude
            if (ulng == 0.0) {
                // no position routine
                noPositionStored()
                return
            }
        } else { return }
        if let user_precision: Double = defaults.doubleForKey(userLocationKey.pcsKey) {
            self.userPrecision = user_precision
        }
        if let user_address: String = defaults.stringForKey(userLocationKey.adrKey) {
            self.userAddress = user_address
        }
        if let user_timestamp: String = defaults.stringForKey(userLocationKey.timKey) {
            self.userTimestamp = user_timestamp
        }
        
        // description formatting
        var description_string = "Hai parcheggiato in " + self.userAddress;
        description_string    += ". Precisione del rilevamento: " + String(self.userPrecision) + " metri."
        // properly formatting description text
        let description = NSMutableAttributedString(string: description_string,
                                                    attributes:[NSFontAttributeName:UIFont(name: "HelveticaNeue-Light", size: 15.0)!])
        description.addAttribute(NSForegroundColorAttributeName, value: UIColor.orangeColor(),
                                 range: NSRange(location:20,length:self.userAddress.characters.count))
        // visualizing description
        controlDescription.textAlignment = NSTextAlignment.Center
        controlDescription.attributedText = description
        // centering map
        setLocation(ulat, lng: ulng, park: true)
        
    }
    func noPositionStored() {
        print("no position")
        controlDescription.textAlignment = NSTextAlignment.Center;
        controlDescription.text = "nessuna posizione salvata!"
        return
    }

    /* enabling position retrieval / check on location services <- when application is active */
    func applicationBecameActive(notification: NSNotification){
        isUserLocation()
    }
    
    /* verify if gps system is enabled */
    func isUserLocation()->Bool {
        if (!CLLocationManager.locationServicesEnabled()) {
            // display a message if location services are disabled
            let alert = UIAlertController(title: "Attenzione!", message: "I servizi di localizzazione sono disabilitati, non sarà possibile utilizzare l'applicazione. Vai in Impostazioni > Privacy > Localizzazione per abilitarli.", preferredStyle: UIAlertControllerStyle.Alert)
            self.presentViewController(alert, animated: true, completion: nil)
            return false
        } else {
            // dismissing alert if location services are enabled
            self.dismissViewControllerAnimated(true, completion: nil)
        }
        return true
    }
    
    /* user location delegate */
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // retrieving coordinate
        let locValue:CLLocationCoordinate2D = manager.location!.coordinate
        self.userLatitude  = locValue.latitude
        self.userLongitude = locValue.longitude
        // setting location
        setLocation(userLatitude, lng: userLongitude)
        
        // retrieving precision
        self.userPrecision = manager.location!.horizontalAccuracy
        
        // retrieving reverse geocoding informations
        let geoCoder = CLGeocoder()
        geoCoder.reverseGeocodeLocation(manager.location!, completionHandler: { (data, error) -> Void in
            if (data != nil) {
                let placeMarks = data! as [CLPlacemark]
                let loc: CLPlacemark = placeMarks[0]
                self.userAddress = ""
                // retrieving all locality information
                if let localityname = loc.name {
                    self.userAddress = self.userAddress + localityname
                }
                if let sublocality = loc.subLocality {
                    self.userAddress = self.userAddress + " (" + sublocality + ")"
                }
                if let locality = loc.locality {
                    self.userAddress = self.userAddress + ", " + locality
                }
                if (self.userAddress.characters.count == 0) {
                    self.userAddress = "< posizione sconosciuta >"
                }
            }
        })
        
        // description formatting
        if (self.userAddress != nil) {
            var description_string = "Stai parcheggiando in " + self.userAddress + ". ";
            if (self.userPrecision != nil) {
                description_string    += "Precisione: " + String(self.userPrecision) + " metri."
            }
            
            // properly formatting description text
            let description = NSMutableAttributedString(string: description_string,
                                                        attributes:[NSFontAttributeName:UIFont(name: "HelveticaNeue-Light", size: 15.0)!])
            description.addAttribute(NSForegroundColorAttributeName, value: UIColor.orangeColor(),
                                                                     range: NSRange(location:22,length:self.userAddress.characters.count))
            
            // visualizing description
            controlDescription.textAlignment = NSTextAlignment.Center
            controlDescription.attributedText = description
        }
    }
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError)
    {
        print(error)
    }

    /* presetting map with user location */
    func setLocation(lat: Double, lng: Double, park: Bool = false) {
        let initialLocation = CLLocation(latitude: lat, longitude: lng)
        let regionRadius: CLLocationDistance = 100
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(initialLocation.coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: true)
        self.mapView.showsUserLocation = true
        
        /*DEV SECTION
        let initialLocation = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let span = MKCoordinateSpanMake(0.2, 0.2)
        let coordinateRegion = MKCoordinateRegion(center: initialLocation, span: span)
        mapView.setRegion(coordinateRegion, animated: true)
        self.mapView.showsUserLocation = true
         */
        
        // setting annotation if parked behaviour
        if (park) {
            let annotation = MKPointAnnotation()
            annotation.coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            annotation.title = "Parcheggio"
            annotation.subtitle = self.userTimestamp
            mapView.addAnnotation(annotation)
            mapView.selectAnnotation(annotation, animated: true)
        }
    }
}

