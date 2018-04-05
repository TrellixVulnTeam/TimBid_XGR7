//
//  BuyerVC.swift
//  Buyer
//
//  Created by William J. Wolfe on 11/8/17.
//  Copyright © 2017 William J. Wolfe. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class BuyerVC: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, AuctionController {

    @IBOutlet weak var acceptAuctionBtn: UIButton!
    @IBOutlet weak var chatBttnOutlet: UIButton!
    @IBOutlet weak var payBttnOutlet: UIButton!
    
    @IBOutlet weak var myMap: MKMapView!
    private var locationManager = CLLocationManager();
    private var userLocation: CLLocationCoordinate2D?;
    private var sellerLocation: CLLocationCoordinate2D?;
    
    private var timer = Timer();
    
    private var acceptedAuction = false;
    private var buyerCanceledAuction = false;
    private var canChat = false;
    private var canPay = false;
    
    private let CHAT_SEGUE = "ChatSegue";
    private let PAY_SEGUE = "PaySegue";
    
    private var delta = 0.01;
    //.0005 --> 0.1 km = 328  ft
    //.0010 --> 0.2 km = 656  ft
    //.0050 --> 1.0 km = 3280 ft
    //.0100 --> 2.0 km
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //chatBttnOutlet.layer.cornerRadius = 4
        //acceptAuctionBtn.layer.cornerRadius = 4
        //payBttnOutlet.layer.cornerRadius = 4
        
        
        
        chatBttnOutlet.backgroundColor = UIColor.jsq_messageBubbleBlue()
        chatBttnOutlet.layer.cornerRadius = chatBttnOutlet.frame.height/2
        chatBttnOutlet.layer.shadowColor = UIColor.darkGray.cgColor
        chatBttnOutlet.layer.shadowRadius = 4
        chatBttnOutlet.layer.shadowOpacity = 0.5
        chatBttnOutlet.layer.shadowOffset = CGSize(width: 0, height: 0)
        
        acceptAuctionBtn.backgroundColor = UIColor.jsq_messageBubbleRed()
        acceptAuctionBtn.layer.cornerRadius = acceptAuctionBtn.frame.height/2
        acceptAuctionBtn.layer.shadowColor = UIColor.darkGray.cgColor
        acceptAuctionBtn.layer.shadowRadius = 4
        acceptAuctionBtn.layer.shadowOpacity = 0.5
        acceptAuctionBtn.layer.shadowOffset = CGSize(width: 0, height: 0)
        
        payBttnOutlet.backgroundColor = UIColor.jsq_messageBubbleGreen()
        payBttnOutlet.layer.cornerRadius = payBttnOutlet.frame.height/2
        payBttnOutlet.layer.shadowColor = UIColor.darkGray.cgColor
        payBttnOutlet.layer.shadowRadius = 4
        payBttnOutlet.layer.shadowOpacity = 0.5
        payBttnOutlet.layer.shadowOffset = CGSize(width: 0, height: 0)
        
        initializeLocationManager();
        AuctionHandler.Instance.delegate = self;
        //AuctionHandler.Instance.observeMessagesForBuyer();
        chatBttnOutlet.isHidden = true;
        payBttnOutlet.isHidden = true;
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        AuctionHandler.Instance.observeMessagesForBuyer();
    }
    
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        DBProvider.Instance.dbRef.removeAllObservers()
    }
 
    
    private func initializeLocationManager() {
        locationManager.delegate = self;
        locationManager.desiredAccuracy = kCLLocationAccuracyBest;
        locationManager.requestWhenInUseAuthorization();
        locationManager.startUpdatingLocation();
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // if we have the coordinates from the manager
        if let location = locationManager.location?.coordinate {
            userLocation = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
            
            let region = MKCoordinateRegion(
                center: userLocation!,
                span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005));
            
            myMap.setRegion(region, animated: true);
            
            myMap.removeAnnotations(myMap.annotations);
            
            if sellerLocation != nil {
                if acceptedAuction {
                    let sellerAnnotation = MKPointAnnotation();
                    sellerAnnotation.coordinate = sellerLocation!;
                    sellerAnnotation.title = "Sellers Location";
                    myMap.addAnnotation(sellerAnnotation);
                }
            }
 
            
            let annotation = MKPointAnnotation();
            annotation.coordinate = userLocation!;
            annotation.title = "Buyer's Location";
            myMap.addAnnotation(annotation);
            
        }
        
    }

    @IBAction func logout(_ sender: Any) {
        if AuthProvider.Instance.logOut() {
            
            if acceptedAuction {
                acceptAuctionBtn.isHidden = true;
                AuctionHandler.Instance.cancelAuctionForBuyer();
                MessagesHandler.Instance.cancelChat();
                timer.invalidate();
            }
            
            
            dismiss(animated: true, completion: nil);
            
        } else {
            // problem with logging out
            alertTheUser(title: "Could Not Logout", message: "We could not logout at the moment, please try again later");

        }
    }
    
    func checkProximity(lat: Double, long: Double, description: String, min_price: String) {
        if nearby(lat: lat, long: long) && !acceptedAuction
        {
            let min_price_int = Int(min_price)!/100
            addRecordToItem()
            print("right before acceptreject alert")
            
            presentAcceptRejectOption(
                    title:          "Auction Request",
                    message:        "Item Up For Sale, Description:\(description), Min Price: $\(min_price_int)");
            
            print("right after acceptreject alert")
        } else
        {
            rejectAuction()
        }
    }
    
    func nearby(lat: Double, long: Double) -> Bool {
        //delta is a global variable
        if userLocation != nil {
            if  (lat  <= self.userLocation!.latitude + delta)   && (lat  >= self.userLocation!.latitude - delta)
                &&
                (long <= self.userLocation!.longitude + delta)  && (long >= self.userLocation!.longitude - delta)
            {
                return true
            } else
            {
                return false
            }
        } else {
            print("missing location information")
            return false
        }
    }
    
    func sellerCanceledAuction() {
        if !buyerCanceledAuction {
            AuctionHandler.Instance.cancelAuctionForBuyer(); //removes requestAccepted (buyer_id) item from DB
            self.acceptedAuction = false;
            self.acceptAuctionBtn.isHidden = true;
            if AuctionHandler.Instance.seller != "" {
    
                alertTheUser(
                    title:          "Auction Canceled",
                    message:        "\(AuctionHandler.Instance.seller) Has Canceled The Auction"
                    );
            }
            AuctionHandler.Instance.seller = "";
            AuctionHandler.Instance.amount_paid = "";
        }
        //added this line after lots of testing.
        //the symptom was that the requestAccepted was not being deleted when the seller canceled.
        //this only happened after a couple of cycles of request/accepted/cancels etc:
        buyerCanceledAuction = false
    }
    
    func auctionCanceled() {
        rejectAuction()
        buyerCanceledAuction = false;
        AuctionHandler.Instance.amount_paid = ""
        timer.invalidate();
    }
    
    func updateSellersLocation(lat: Double, long: Double) {
        sellerLocation = CLLocationCoordinate2D(latitude: lat, longitude: long);
        print("(updating sellers location) seller =\(AuctionHandler.Instance.seller) ")
    }
    
    @objc func updateBuyersLocation() {
        AuctionHandler.Instance.updateBuyerLocation(lat: userLocation!.latitude, long: userLocation!.longitude);
    }
    
    // the "cancel" button, somehow I named it oddly
    @IBAction func buyItem(_ sender: Any) {
        if acceptedAuction {
            buyerCanceledAuction = true;
            acceptAuctionBtn.isHidden = true;
            AuctionHandler.Instance.cancelAuctionForBuyer(); //remove requestAccepted (buyer_id)
            timer.invalidate();
        }
    }
    
    private func presentAcceptRejectOption(title: String, message: String) {

        
        let alert = UIAlertController(
            title:      title,
            message:    message,
            preferredStyle: .alert);
        
        /*
        var rootViewController = UIApplication.shared.keyWindow?.rootViewController
        
        if let navigationController = rootViewController as? UINavigationController {
            rootViewController = navigationController.viewControllers.first
        }
        
        if let tabBarController = rootViewController as? UITabBarController {
            rootViewController = tabBarController.selectedViewController
        }
        */
        
        let accept = UIAlertAction(
            title: "Accept",
            style: .default,
            handler: { (alertAction: UIAlertAction) in
                print("in the accept section of the alert")
                AuctionHandler.Instance.seller = AuctionHandler.Instance.temp_seller
                self.acceptedAuction = true;
                self.acceptAuctionBtn.isHidden = false;
                self.timer = Timer.scheduledTimer(timeInterval: TimeInterval(10), target: self, selector: #selector(BuyerVC.updateBuyersLocation), userInfo: nil, repeats: true);
                
                AuctionHandler.Instance.auctionAccepted(
                    lat:    Double(self.userLocation!.latitude),
                    long:   Double(self.userLocation!.longitude)); //creates a new Auction_Accepted child (autoID)
            });
        
        let reject = UIAlertAction(
            title: "Reject",
            style: .default,
            handler: { (alertAction: UIAlertAction) in
                
                self.rejectAuction()
            });
            
        alert.addAction(accept);
        alert.addAction(reject);
        //rootViewController?.present(alert, animated: true, completion: nil)
        present(alert, animated: true, completion: nil)
        
        
    }
    
    @IBAction func startChat(_ sender: Any) {
        performSegue(withIdentifier: CHAT_SEGUE, sender: nil)
    }
    
    internal func enableChat() {
        chatBttnOutlet.isHidden = false;
    }
    
    internal func disableChat() {
        chatBttnOutlet.isHidden = true;
    }
    
    
    @IBAction func pay(_ sender: Any) {
        performSegue(withIdentifier: PAY_SEGUE, sender: nil)
    }
    
    internal func enablePay() {
        payBttnOutlet.isHidden = false;
    }
    
    internal func disablePay() {
        payBttnOutlet.isHidden = true;
    }
    
    private func rejectAuction() {
        self.acceptedAuction = false
        self.acceptAuctionBtn.isHidden = true;
        AuctionHandler.Instance.seller = "";
    }
    
    func addRecordToItem() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        let newItem = NSEntityDescription.insertNewObject(forEntityName: "Item", into: context)
        newItem.setValue(AuctionHandler.Instance.item_description, forKey: "item_description")
        newItem.setValue(AuctionHandler.Instance.min_price_cents, forKey: "item_price")
        newItem.setValue(AuctionHandler.Instance.seller_id, forKey: "seller_identifier")
        newItem.setValue(Date(), forKey: "post_date")
        newItem.setValue(Date(), forKey: "purchase_date") //should fix this, the item is not sold yet. date should be nil
        do
        {
            try context.save()
        }
        catch
        {
            print("error trying to save to core data")
        }
    }
    
    private func alertTheUser(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert);
        let ok = UIAlertAction(title: "OK", style: .default, handler: nil);
        alert.addAction(ok);
        present(alert, animated: true, completion: nil);
    }
}