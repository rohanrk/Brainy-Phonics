//
//  LetterViewController.swift
//  Phonetics
//
//  Created by Cal on 6/5/16.
//  Copyright © 2016 Cal Stephens. All rights reserved.
//

import UIKit

class LetterViewController : InteractiveGrowViewController {
    
    @IBOutlet weak var letterContainer: UIView!
    @IBOutlet weak var letterLabel: UILabel!
    @IBOutlet weak var checkmark: UIView!
    @IBOutlet weak var previousSoundButton: UIButton!
    @IBOutlet weak var nextSoundButton: UIButton!
    @IBOutlet weak var quizButton: UIButton!
    @IBOutlet weak var wordsView: UIView!
    @IBOutlet weak var buttonArea: UIView!
    
    @IBOutlet var wordViews: [WordView]!
    
    var letter: Letter!
    var difficulty: Letter.Difficulty!
    var sound: Sound!
    var timers = [Timer]()
    var currentlyPlaying = false
    
    var currentIndex: Int {
        return letter.sounds(for: difficulty).index(of: sound)!
    }
    
    var previousSound: Sound? {
        let prev = self.currentIndex - 1
        if prev < 0 { return nil }
        return letter.sounds(for: difficulty)[prev]
    }
    
    var nextSound: Sound? {
        let next = self.currentIndex + 1
        if next >= letter.sounds(for: difficulty).count { return nil }
        return letter.sounds(for: difficulty)[next]
    }
    
    var letterIndex: Int {
        return PHLetters.firstIndex(of: letter.text)!
    }
    
    var previousLetter: Letter? {
        return letterIndex > 0 ? PHContent[PHLetters[letterIndex - 1]] : nil
    }
    
    var nextLetter: Letter? {
        return letterIndex < PHLetters.count - 1 ? PHContent[PHLetters[letterIndex + 1]] : nil
    }
    
    //MARK: - Presentation
    static func present(for letter: Letter, with difficulty: Letter.Difficulty, inController other: UIViewController, initialSound: Sound? = nil) {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "letter") as! LetterViewController
        controller.letter = letter
        controller.difficulty = difficulty

        if let firstSound = initialSound {
            controller.sound = firstSound
        } else {
            controller.sound = letter.sounds(for: difficulty).first(where: { sound in
                return !sound.puzzleIsComplete
            }) ?? letter.sounds(for: difficulty).first
        }
        
        other.present(controller, animated: true, completion: nil)
    }
    
    
    //MARK: - Set up
    
    override func viewWillAppear(_ animated: Bool) {
        UAHaltPlayback()

        decorateForCurrentSound()
        sortOutletCollectionByTag(&wordViews)
        
        self.buttonArea.backgroundColor = difficulty.color
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        UAHaltPlayback()
        timers.forEach{ $0.invalidate() }
    }
    
    func decorateForCurrentSound(withTransition transition: Bool = false, withAnimationDelay: Bool = true, animationSubtype: String? = nil) {
        
        //cancel view animations to avoid overlap
        for view in wordViews {
            view.layer.removeAllAnimations()
        }
        
        self.letterLabel.layer.removeAllAnimations()
        self.timers.forEach { $0.invalidate() }
        self.timers = []
        
        //set up view. Letter only for Alphabet Letters. Sound for Phonics
        self.letterLabel.text = self.difficulty == .easyDifficulty ? letter.text.uppercased() + letter.text.lowercased() : sound.displayString.lowercased()
        self.checkmark.isHidden = !self.sound.puzzleIsComplete
        self.wordViews.forEach{ $0.alpha = 0.0 } // Word Views start transparent. Animate only for Phonics
        
        if self.difficulty == .standardDifficulty {
            
            self.previousSoundButton.isEnabled = previousSound != nil
            self.nextSoundButton.isEnabled = nextSound != nil
            for i in 0 ..< min(3, self.sound.primaryWords.count) {
                let wordView = wordViews[i]
                wordView.alpha = withAnimationDelay ? 0.0 : 1.0
                wordView.useWord(self.sound.primaryWords[i], forSound: self.sound, ofLetter: self.letter)
            }
        } else {
            // For Alphabet Letters, bump up font size and center
            /* For some reason, changing fonts programatically doesn't properly update the view so I mainly did it via storyboard
            if let font = UIFont.init(name: "ComicNeue-Bold", size: 100) {
                self.letterLabel.font = font
            } */
            // Alphabet Letters Buttons based on letters instead of sounds
            self.previousSoundButton.isEnabled = previousLetter != nil
            self.nextSoundButton.isEnabled = nextLetter != nil
        }
        //play audio, cue animations
        if !withAnimationDelay {
            self.playSoundAnimation()
        } else {
            Timer.scheduleAfter(0.4, addToArray: &self.timers) {
                self.playSoundAnimation()
            }
        }
        
        //play push transition for content
        if transition {
            let views: [UIView] = [letterContainer, wordsView]
            for view in views {
                let timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
                
                playTransitionForView(view,
                                      duration: 0.5,
                                      transition: kCATransitionPush,
                                      subtype: animationSubtype,
                                      timingFunction: timingFunction)
            }
        }
        
        //reset quiz button
        let updateQuizButton = {
            self.quizButton.alpha = 0.0
            self.quizButton.transform = .identity
        }
        
        if transition || !withAnimationDelay {
            UIView.animate(withDuration: 0.5, delay: 0.0, options: [.beginFromCurrentState], animations: updateQuizButton, completion: nil)
        } else {
            updateQuizButton()
        }
    }
    
    
    //MARK: - Animation
    
    func playSoundAnimation() {
        
        self.currentlyPlaying = true
        var startTime: TimeInterval = 0.3
        let timeBetween = 0.85
        
        Timer.scheduleAfter(startTime, addToArray: &timers) { 
            let soundAudioInfo = self.difficulty == .easyDifficulty ? self.letter.audioInfo : self.sound.pronunciationTiming
            PHContent.playAudioForInfo(soundAudioInfo)
            self.playSoundAnimation(on: self.letterLabel, for: soundAudioInfo)
        }
        
        startTime += (self.sound.pronunciationTiming?.wordDuration ?? 0.5) + timeBetween
        
        // Only perform wordview animations for Phonics
        if self.difficulty == .standardDifficulty {
            
            for (wordIndex, word) in self.sound.primaryWords.enumerated() {
                
                Timer.scheduleAfter(startTime, addToArray: &self.timers) {
                    let wordView = self.wordViews[wordIndex]
                    wordView.word?.playAudio()
                    self.playSoundAnimation(on: wordView, for: wordView.word?.audioInfo)
                }
                
                startTime += (word.audioInfo?.wordDuration ?? 0.0) + timeBetween
                
                if (word == self.sound.primaryWords.last) {
                    Timer.scheduleAfter(startTime, addToArray: &self.timers) {
                        self.currentlyPlaying = false
                        self.showQuizButton()
                    }
                }
            }
        
        // For Alphabet Letters, show quiz button after letter audio and animation
        } else {
            self.currentlyPlaying = false
            self.showQuizButton()
        }
    }
    
    func playSoundAnimation(on view: UIView, for audioInfo: AudioInfo?) {
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 0.8, animations: {
            view.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            view.alpha = 1.0
        })
        
        UIView.animate(withDuration: 0.5, delay: (audioInfo?.wordDuration ?? 0.2) + 0.3, usingSpringWithDamping: 1.0, animations: {
            view.transform = .identity
        })
    }
    
    func showQuizButton() {
        self.quizButton.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0) {
            self.quizButton.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.quizButton.alpha = 1.0
        }
        
        Timer.scheduleAfter(0.4, addToArray: &self.timers, handler: self.animateQuizButtonLoop(to: 0.95, then: 1.15))
        
    }
    
    func animateQuizButtonLoop(to scale: CGFloat, then nextScale: CGFloat) -> () -> () {
        return {
            UIView.animate(withDuration: 1.5, delay: 0.0, options: [.allowUserInteraction, .curveEaseInOut, .beginFromCurrentState], animations: {
                self.quizButton.transform = CGAffineTransform(scaleX: scale, y: scale)
            }, completion: nil)
            
            Timer.scheduleAfter(1.5, addToArray: &self.timers, handler: self.animateQuizButtonLoop(to: nextScale, then: scale))
        }
    }
    
    
    //MARK: - User Interaction
    
    @IBAction func backPressed(_ sender: UIButton) {
        self.presentingViewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func repeatPressed(_ sender: UIButton) {
        if self.currentlyPlaying { return }
        
        sender.isUserInteractionEnabled = false
        delay(1.0) {
            sender.isUserInteractionEnabled = true
        }
        
        //sender.tag = 0  >>  repeat Sound Animation
        //sender.tag = 1  >>  repeat pronunciation
        
        if (sender.tag == 0) {
            decorateForCurrentSound(withTransition: false, withAnimationDelay: false, animationSubtype: kCATransitionFade)
        } else if sender.tag == 1 {
            let audioInfo = self.difficulty == .easyDifficulty ? letter.audioInfo : sound.pronunciationTiming
            PHContent.playAudioForInfo(audioInfo)
            self.playSoundAnimation(on: self.letterLabel, for: audioInfo)
        }
    }
    
    @IBAction func previousSoundPressed(_ sender: AnyObject) {
        if self.difficulty == .standardDifficulty {
            sound = previousSound ?? sound
            decorateForCurrentSound(withTransition: true, animationSubtype: kCATransitionFromLeft)
        } else {
            letter = previousLetter ?? letter
            sound = letter.sounds(for: difficulty).first
            decorateForCurrentSound(withTransition: true, animationSubtype: kCATransitionFromLeft)
        }
    }
    
    @IBAction func nextSoundPressed(_ sender: AnyObject) {
        if self.difficulty == .standardDifficulty {
            sound = nextSound ?? sound
            decorateForCurrentSound(withTransition: true, animationSubtype: kCATransitionFromRight)
        } else {
            letter = nextLetter ?? letter
            sound = letter.sounds(for: difficulty).first
            decorateForCurrentSound(withTransition: true, animationSubtype: kCATransitionFromRight)
        }
    }
    
    @IBAction func openQuiz(_ sender: AnyObject) {
        QuizViewController.presentQuiz(customSound: self.sound, showingThreeWords: self.difficulty == .standardDifficulty, difficulty: self.difficulty, onController: self)
    }
    
    
    //MARK: - Interactive Grow behavior
    
    override func interactiveViewWilGrow(_ view: UIView) {
        if let wordView = view as? WordView {
            wordView.word?.playAudio()
        }
    }
    
    override func totalDurationForInterruptedAnimationOn(_ view: UIView) -> TimeInterval? {
        if let wordView = view as? WordView, let duration = wordView.word?.audioInfo?.wordDuration {
            return duration + 0.5
        } else { return 1.0 }
    }
    
    override func interactiveGrowScaleFor(_ view: UIView) -> CGFloat {
        return 1.15
    }
    
    override func interactiveGrowShouldHappenFor(_ view: UIView) -> Bool {
        return !self.currentlyPlaying
    }
    
}
