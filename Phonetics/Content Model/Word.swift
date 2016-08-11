//
//  Word.swift
//  Phonetics
//
//  Created by Cal on 6/30/16.
//  Copyright © 2016 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

struct Word: Equatable {
    
    let text: String
    let pronunciation: String?
    
    var image: UIImage? {
        return UIImage(named: "\(text).jpg")
    }
    
    init?(text wordText: String?, pronunciation: String?) {
        guard let wordText = wordText else { return nil }
        
        var text = wordText.lowercaseString
        
        //remove padding spaces, if exist
        while text.hasPrefix(" ") {
            text = text.substringFromIndex(text.startIndex.successor())
        }
        
        while text.hasSuffix(" ") {
            text = text.substringToIndex(text.endIndex.predecessor())
        }
        
        self.text = text
        self.pronunciation = pronunciation
    }
    
    
    func attributedText(forSound sound: Sound, ofLetter letter: Letter) -> NSAttributedString {
        
        let explicitExclusions: [String : Int] = [
            "eagle" : 2,
            "skis" : 1
        ]
        
        var soundText = sound.displayString
        if soundText.hasPrefix("\(letter.text)\(letter.text.lowercaseString)") {
            soundText = letter.text
        }
        
        soundText = soundText.lowercaseString
        
        let wordText = self.text.lowercaseString
        var mutableWord = wordText
        let attributedWord = NSMutableAttributedString(string: wordText, attributes: [NSForegroundColorAttributeName : UIColor.blackColor()])
        let matchColor = UIColor(hue: 0.00833, saturation: 0.9, brightness: 0.79, alpha: 1.0)
        
        var matchIndex = 1
        
        while mutableWord.containsString(soundText) {
            let range = (mutableWord as NSString).rangeOfString(soundText)
            if (explicitExclusions[wordText] != matchIndex) {
                attributedWord.addAttributes([NSForegroundColorAttributeName : matchColor], range: range)
            }
            
            let replacement = String(count: soundText.length, repeatedValue: Character("_"))
            mutableWord = (mutableWord as NSString).stringByReplacingCharactersInRange(range, withString: replacement)
            matchIndex += 1
        }
        
        return attributedWord
    }
    
    
    func playAudio(withConcurrencyMode concurrencyMode: UAConcurrentAudioMode = .Interrupt) {
        
    }
    
    var lengthOfAudio: NSTimeInterval? {
        return 1.0
    }
    
    
    //use wordsapi.com to fetch an IPA pronunciation of the word
    //requires an API key & a freemium payment plan
    func fetchPronunciation(withKey key: String, completion: (String?) -> ()) {
        let method = "https://wordsapiv1.p.mashape.com/words/\(self.text.preparedForURL())/pronunciation"
        let request = NSMutableURLRequest(URL: NSURL(string: method)!)
        request.setValue(key, forHTTPHeaderField: "X-Mashape-Key")
        
        NSURLSession.sharedSession().dataTaskWithRequest(request) { (data, response, error) in
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                let dict = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments) as! NSDictionary
                if let subdict = dict["pronunciation"] as? NSDictionary {
                    if let pronunciation = subdict["all"] as? String {
                        completion(pronunciation)
                        return
                    }
                }
                
                completion(nil)
            }
            
            catch {
                completion(nil)
            }
            
        }.resume()
    }
    
}

func ==(left: Word, right: Word) -> Bool {
    return left.text == right.text
}
