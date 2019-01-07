//
//  Player.swift
//  Phonics
//
//  Created by Cal Stephens on 12/22/16.
//  Copyright © 2016 Cal Stephens. All rights reserved.
//

import Foundation

let PHDefaultPlayerKey = "defaultPlayer-2"



class Player : NSObject, NSCoding {
    
    static var current = Player.load(id: PHDefaultPlayerKey) ?? Player()
    
    
    //MARK: Properties
    
    var id: String
    var puzzleProgress: [String : PuzzleProgress]
    
    /// [“a”: 3, “ah”: 3, “apple”: 1]
    /// lowercased alphabet letters, phonics, and words
    private var stars: [String: Star]
    
    /// keys:
    /// Phonics: sound.soundID
    /// Alphabet: "al-" + sound.sourceLetter
    /// rest of the app: the word itself
    func stars(for key: String) -> Star {
        return self.stars[key.lowercased()] ?? Star(highScore: 0, currentStreak: 0)
    }
    
    /// updates current streak,
    /// and updates highScore if necessary
    /// @returns new High Score (usually unchanged)
    @discardableResult
    func updateStars(for k: String, newValue: Int) -> Int {
        let key = k.lowercased()
        let existingValue = stars[key]
        if existingValue == nil || existingValue!.highScore < newValue {
            stars[key] = Star(highScore: newValue, currentStreak: newValue)
        } else {
            stars[key]?.currentStreak = newValue
        }
        return stars[key]?.highScore ?? 0
    }
    
    var hasSeenSightWordsCelebration: Bool
    let celebrationAmount = 125  // 125 gold coins, which is 1 truck
    
    var celebrate: Bool {
        return sightWordCoins.gold >= celebrationAmount && !hasSeenSightWordsCelebration
    }
    
    var sightWordCoins: (gold: Int, silver: Int) {
        willSet {
            // reset hasSeenCelebration to false if users wins a new truck
            hasSeenSightWordsCelebration = !(hasSeenSightWordsCelebration && newValue.gold % celebrationAmount == 0)
        }
    }
    
    override init() {
        self.id = PHDefaultPlayerKey
        self.puzzleProgress = [:]
        self.stars = [:]
        self.sightWordCoins = (0, 0)
        self.hasSeenSightWordsCelebration = false
    }
    
    
    //MARK: - NSCoding
    
    enum Key: String, NSCodingKey {
        case id = "Player.id"
        case puzzleProgress = "Player.puzzleProgress"
        case sightWordGoldCoins = "Player.sightWordCoins.gold"
        case sightWordSilverCoins = "Player.sightWordCoins.silver"
        case hasSeenSightWordsCelebration = "Player.hasSeenCelebration"
        case stars = "Player.stars"
    }
    
    required init?(coder decoder: NSCoder) {
        guard let id = (decoder.value(for: Key.id) as? String) else { return nil }
        self.id = id
        
        self.puzzleProgress = (decoder.value(for: Key.puzzleProgress) as? [String : PuzzleProgress]) ?? [:]
        
        let sightWordGoldCoins = (decoder.value(for: Key.sightWordGoldCoins) as? Int) ?? 0
        let sightWordSilverCoins = (decoder.value(for: Key.sightWordSilverCoins) as? Int) ?? 0
        self.sightWordCoins = (sightWordGoldCoins, sightWordSilverCoins)
        
        self.hasSeenSightWordsCelebration = decoder.value(for: Key.hasSeenSightWordsCelebration) as? Bool ?? false
        
        self.stars = decoder.value(for: Key.stars) as? [String: Star] ?? [:]
    }
    
    func encode(with encoder: NSCoder) {
        encoder.setValue(self.id, for: Key.id)
        encoder.setValue(self.puzzleProgress, for: Key.puzzleProgress)
        encoder.setValue(self.sightWordCoins.gold, for: Key.sightWordGoldCoins)
        encoder.setValue(self.sightWordCoins.silver, for: Key.sightWordSilverCoins)
        encoder.setValue(self.hasSeenSightWordsCelebration, for: Key.hasSeenSightWordsCelebration)
        encoder.setValue(self.stars, for: Key.stars)
    }
    
    
    //MARK: - Persistence
    
    func save() {
        
        let key = "player.\(id)"
        let defaults = UserDefaults.standard
        defaults.synchronize()
        
        defaults.set(true, forKey: "has been saved recently")
        
        let encodedData = NSKeyedArchiver.archivedData(withRootObject: self)
        print("saved \(encodedData)")
        defaults.set(encodedData, forKey: key)
        defaults.synchronize()
    }
    
    static func load(id: String) -> Player? {
        let key = "player.\(id)"
        let defaults = UserDefaults.standard
        defaults.synchronize()
        
        print("has been saved recently: \(defaults.bool(forKey: "has been saved recently"))")
        
        guard let data = defaults.data(forKey: key) else {
            print("NO DATA FOR \(key)")
            return nil
        }
        
        print("loaded \(data)")
        
        guard let player = NSKeyedUnarchiver.unarchiveObject(with: data) as? Player else {
            print("FAILED TO UNARCHIVE PLAYER")
        
            return nil
        }
        
        
        return player
    }
    
}

class Star: NSObject, NSCoding {
    enum Key: String, NSCodingKey {
        case highScore = "Star.highScore"
        case current = "Star.current"
    }
    
    required init?(coder decoder: NSCoder) {
        highScore = (decoder.value(for: Key.highScore) as? Int) ?? 0
        currentStreak = (decoder.value(for: Key.current) as? Int) ?? 0
    }
    
    func encode(with encoder: NSCoder) {
        encoder.setValue(self.highScore, for: Key.highScore)
        encoder.setValue(self.currentStreak, for: Key.current)
    }
    
    var highScore: Int
    var currentStreak: Int
    
    override init() {
        self.highScore = 0
        self.currentStreak = 0
    }
    
    init(highScore: Int, currentStreak: Int) {
        self.highScore = highScore
        self.currentStreak = currentStreak
    }
}
