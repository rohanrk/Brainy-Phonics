//
//  LaunchViewController.swift
//  Phonics
//
//  Created by Cal Stephens on 6/29/17.
//  Copyright © 2017 Cal Stephens. All rights reserved.
//

import UIKit

class LaunchViewController: UIViewController {
    
    override func viewDidAppear(_ animated: Bool) {
        PHPlayer.play("brainy phonics", ofType: "mp3")
        
        UAWhenDonePlayingAudio {
            if Bundle.main.infoDictionary?["TargetName"] as! String == "Phonics" {
                let homeViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "home") as! HomeViewController
                homeViewController.modalTransitionStyle = .coverVertical
                self.present(homeViewController, animated: true, completion: nil)
            }
            
            else {
                let phonicsViewController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "phonics") as! PhonicsViewController
                phonicsViewController.modalTransitionStyle = .coverVertical
                self.present(phonicsViewController, animated: true, completion: nil)
            }
        }
    }
    
}
