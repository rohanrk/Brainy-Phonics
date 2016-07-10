//
//  QuizViewController.swift
//  Phonetics
//
//  Created by Cal on 7/3/16.
//  Copyright © 2016 Cal Stephens. All rights reserved.
//

import Foundation
import UIKit

class QuizViewController : InteractiveGrowViewController {
    
    var letterPool: [Letter]!
    var currentLetter: Letter!
    var currentSound: Sound!
    var answerWord: Word!
    
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet var wordViews: [WordView]!
    
    var originalCenters = [WordView : CGPoint]()
    var timers = [NSTimer]()
    var state: QuizState = .Waiting
    
    enum QuizState {
        case Waiting, PlayingQuestion, Transitioning
    }
    
    
    //MARK: - Content Setup
    
    override func viewWillAppear(animated: Bool) {
        self.view.layoutIfNeeded()
        
        sortOutletCollectionByTag(&wordViews)
        wordViews.forEach{ originalCenters[$0] = $0.center }
        
        letterPool = PHContent.letters.map{ (_, letter) in letter }
        setupForRandomSoundFromPool()
    }
    
    override func viewWillDisappear(animated: Bool) {
        stopAnimations(stopAudio: true)
    }
    
    func setupForRandomSoundFromPool() {
        let isFirst = (currentSound == nil)
        self.currentLetter = letterPool.random()
        self.currentSound = currentLetter.sounds.random()
        self.answerWord = currentSound.words.random()
        
        soundLabel.text = self.currentSound.displayString
        
        let allWords = PHContent.allWordsNoDuplicates
        let blacklistedSound = currentSound.ipaPronunciation
        let blacklistedLetter = currentSound.sourceLetter.lowercaseString
        let possibleWords = allWords.filter{ word in
            return !word.pronunciation.containsString(blacklistedSound)
                    && !word.text.lowercaseString.containsString(blacklistedLetter)
        }
        
        var selectedWords: [Word] = [answerWord]
        while selectedWords.count != wordViews.count {
            if let candidateWord = possibleWords.random() where !selectedWords.contains(candidateWord) {
                selectedWords.append(candidateWord)
            }
        }
        
        selectedWords = selectedWords.shuffled()
        
        for (index, wordView) in wordViews.enumerate() {
            wordView.center = self.originalCenters[wordView]!
            wordView.showingText = false
            wordView.layoutIfNeeded()
            wordView.transform = CGAffineTransformIdentity
            wordView.alpha = 1.0
            wordView.useWord(selectedWords[index], forSound: currentSound, ofLetter: currentLetter)
        }
        
        transitionToCurrentSound(isFirst: isFirst)
    }
    
    
    //MARK: - Animation
    
    func transitionToCurrentSound(isFirst isFirst: Bool) {
        //animate if not first
        if !isFirst {
            for view in [wordViews.first!.superview!, self.soundLabel.superview!] {
                playTransitionForView(view, duration: 0.5, transition: kCATransitionPush, subtype: kCATransitionFromTop,
                                      timingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
            }
        }
        
        delay(0.5) {
            self.playQuestionAnimation()
        }
    }
    
    func playQuestionAnimation() {
        
        self.state = .PlayingQuestion
        
        var startTime: NSTimeInterval = 0.0
        let timeBetween = 0.85
        
        NSTimer.scheduleAfter(startTime, addToArray: &timers) {
            shakeView(self.soundLabel)
        }
        
        NSTimer.scheduleAfter(startTime - 0.3, addToArray: &timers) {
            PHContent.playAudioForInfo(self.currentSound.pronunciationTiming)
        }
        
        startTime += self.currentSound.pronunciationTiming.wordDuration + timeBetween
        
        for (index, wordView) in self.wordViews.enumerate() {
            
            NSTimer.scheduleAfter(startTime, addToArray: &self.timers) {
                self.playSoundAnimationForWord(index, delayAnimationBy: 0.3)
            }
            
            startTime += (wordView.word?.audioInfo?.wordDuration ?? 0.0) + timeBetween
            
            if (wordView == self.wordViews.last) {
                NSTimer.scheduleAfter(startTime - timeBetween, addToArray: &self.timers) {
                    self.state = .Waiting
                }
            }
        }
    }
    
    func playSoundAnimationForWord(index: Int, delayAnimationBy delay: NSTimeInterval = 0.0, extendAnimationBy extend: NSTimeInterval = 0.0) {
        if index >= self.wordViews.count { return }
        
        let wordView = self.wordViews[index]
        guard let word = wordView.word else { return }
        word.playAudio()
        
        UIView.animateWithDuration(0.4, delay: delay, usingSpringWithDamping: 0.8, animations: {
            wordView.transform = CGAffineTransformMakeScale(1.1, 1.1)
            wordView.alpha = 1.0
        })
        
        UIView.animateWithDuration(0.5, delay: delay + extend + (word.audioInfo?.wordDuration ?? 0.5), usingSpringWithDamping: 1.0, animations: {
            wordView.transform = CGAffineTransformIdentity
        })
    }
    
    func stopAnimations(stopAudio stopAudio: Bool = true) {
        if self.state != .Waiting {
            self.timers.forEach{ $0.invalidate() }
            if stopAudio { UAHaltPlayback() }
            self.state = .Waiting
        }
        
    }
    
    
    //MARK: - User Interaction
    
    @IBAction func repeatSound(sender: UIButton) {
        if self.state == .PlayingQuestion { return }
        
        sender.userInteractionEnabled = false
        delay(1.0) {
            sender.userInteractionEnabled = true
        }
        
        //sender.tag = 0  >>  repeat Sound Animation
        //sender.tag = 1  >>  repeat pronunciation
        
        if (sender.tag == 0) {
            playQuestionAnimation()
        } else if sender.tag == 1 {
            PHContent.playAudioForInfo(currentSound.pronunciationTiming)
            shakeView(self.soundLabel)
        }
    }
    
    func wordViewSelected(wordView: WordView) {
        wordView.superview?.bringSubviewToFront(wordView)

        if wordView.word == answerWord {
            correctWordSelected(wordView)
        } else {
            wordView.setShowingText(true, animated: true)
            shakeView(wordView)
        }
    }
    
    func correctWordSelected(wordView: WordView) {
        
        func animateAndContinue() {
            self.state = .Transitioning
            
            UIView.animateWithDuration(0.2) {
                self.wordViews.filter{ $0 != wordView }.forEach{ $0.alpha = 0.0 }
            }
            
            UIView.animateWithDuration(0.5, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [UIViewAnimationOptions.BeginFromCurrentState], animations: {
                let superSize = wordView.superview!.bounds.size
                let superCenter = CGPoint(x: superSize.width / 2, y: superSize.height / 2)
                wordView.center = superCenter
                }, completion: nil)
            
            PHPlayer.play("correct", ofType: "mp3")
            NSTimer.scheduleAfter(1.5, addToArray: &self.timers, handler: self.setupForRandomSoundFromPool)
        }
        
        wordView.setShowingText(true, animated: true, duration: 0.5)
        
        if (UAIsAudioPlaying()) {
            UAWhenDonePlayingAudio(animateAndContinue)
        } else {
            NSTimer.scheduleAfter(0.55, addToArray: &self.timers, handler: animateAndContinue)
        }
    }
    
    
    //MARK: - Interactive Grow behavior
    
    override func interactiveGrowScaleFor(view: UIView) -> CGFloat {
        return 1.1
    }
    
    override func interactiveViewWilGrow(view: UIView) {
        if let wordView = view as? WordView {
            
            if self.state == .PlayingQuestion {
                self.stopAnimations(stopAudio: false)
            }
            
            wordView.word?.playAudio()
        }
    }
    
    override func shouldAnimateShrinkForInteractiveView(view: UIView, isTouchUp: Bool) -> Bool {
        if view is WordView {
            return !isTouchUp
        }
        
        return true
    }
    
    override func totalDurationForInterruptedAnimationOn(view: UIView) -> NSTimeInterval? {
        if let wordView = view as? WordView, let duration = wordView.word?.audioInfo?.wordDuration {
            if wordView.word == self.answerWord { return 3.0 }
            return duration + 0.5
        } else { return 1.0 }
    }
    
    override func touchUpForInteractiveView(view: UIView) {
        if let wordView = view as? WordView {
            self.wordViewSelected(wordView)
        }
    }
    
}