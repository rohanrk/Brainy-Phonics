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
    
    var sound: Sound?
    var totalAnswerWordPool: [Word]!
    var remainingAnswerWordPool: [Word]!
    
    var onlyShowThreeWords: Bool = false
    var dismissOnReturnFromModal = false
    var difficulty: Letter.Difficulty?
    var isEntireQuiz: Bool = false // not just one item
    
    var currentLetter: Letter!
    var currentSound: Sound!
    var answerWord: Word!
    var currentAlphabetLetter: String? {
        return currentSound?.sourceLetter.lowercased()
    }
    
    var bank: Bank {
        return self.difficulty == .easyDifficulty ? Player.current.lettersBank : Player.current.phonicsBank
    }

    
    @IBOutlet weak var soundLabel: UILabel!
    @IBOutlet var wordViews: [WordView]!
    @IBOutlet weak var topLeftWordLeading: NSLayoutConstraint!
    @IBOutlet weak var fourthWord: WordView!
    
    @IBOutlet weak var puzzleView: PuzzleView!
    @IBOutlet weak var puzzleShadow: UIView!
    @IBOutlet weak var bankButton: UIButton!
    
    /// 0 or 150
    @IBOutlet weak var buttonAreaToWords: NSLayoutConstraint!
    @IBOutlet weak var soundSuperview: UIView!
    @IBOutlet weak var wordSuperView: UIView!
    

    var originalCenters = [WordView : CGPoint]()
    var timers = [Timer]()
    var state: QuizState = .waiting
    var attempts = 0
    var index = 0 //the index of the previous word in the total array
    var starsCurrentStreak: Int! {
        didSet {
            let key: String = self.difficulty == .easyDifficulty ? currentSound.sourceLetter : currentSound.soundId
            starsHighScore = Player.current.updateStars(for: key, newValue: starsCurrentStreak)
        }
    }
    var starsHighScore: Int!
    
    enum QuizState {
        case waiting, playingQuestion, transitioning
    }
    
    
    //MARK: - Transition
    
    static func presentQuiz(customSound: Sound?, showingThreeWords: Bool, difficulty: Letter.Difficulty?, onController controller: UIViewController) {
        let quiz = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "quiz") as! QuizViewController
        quiz.sound = customSound
        quiz.onlyShowThreeWords = showingThreeWords
        quiz.difficulty = difficulty
        controller.present(quiz, animated: true, completion: nil)
    }
    
    
    //MARK: - Content Setup
    
    override func viewDidLoad() {
        if difficulty == .easyDifficulty {
            // center the words and get rid of puzzle area
            self.soundSuperview.backgroundColor = .white
            self.puzzleShadow.isHidden = true
            self.puzzleView.isHidden = true
            buttonAreaToWords.constant = 0
        }
        isEntireQuiz = self.sound == nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        if let sound = self.sound {
            totalAnswerWordPool = sound.allWords
            
            //this starts out the same as Total,
            //but will have values removed if correct on first try
            remainingAnswerWordPool = sound.allWords
        }
        
        if let difficulty = self.difficulty {
            self.view.backgroundColor = difficulty.color
        }
        
        if self.onlyShowThreeWords {
            enum TopLeftLeadingPriority: Float {
                case centerView = 850
                case leftAlignView = 950
                
                var priority: UILayoutPriority {
                    return UILayoutPriority(rawValue: self.rawValue)
                }
            }
            
            self.topLeftWordLeading.priority = TopLeftLeadingPriority.centerView.priority
            self.fourthWord.removeFromSuperview()
            self.interactiveViews.remove(at: self.interactiveViews.index(of: self.fourthWord)!)
            self.wordViews.remove(at: self.wordViews.index(of: self.fourthWord)!)
        }
        
        self.view.layoutIfNeeded()
        bankButton.isHidden = self.difficulty == .standardDifficulty
        sortOutletCollectionByTag(&wordViews)
        wordViews.forEach{ originalCenters[$0] = $0.center }
        
        setupForRandomSoundFromPool()
        
        // Sound View is hidden in Ipad so make sure that's brought to the front
        if iPad() {
            self.view.bringSubview(toFront: soundSuperview)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        stopAnimations(stopAudio: true)
    }
    
    func setupForRandomSoundFromPool() {
        let isFirst = (currentSound == nil)
        attempts = 0
        
        
        if let sound = self.sound {
            //if there is one specific sound
            
            self.currentSound = sound
            self.currentLetter = PHContent[self.currentSound.sourceLetter]!
            
            if remainingAnswerWordPool.isEmpty {
                //start over from beginning, just in case.
                remainingAnswerWordPool = totalAnswerWordPool
            }
            
            if index >= remainingAnswerWordPool.count {
                //loop from beginning again, but avoiding any First-Try's
                index = 0
            }
            
            answerWord = remainingAnswerWordPool[index]
            index += 1
            
        } else {
            //if global quiz
            
            let randomLetter = PHLetters.random()!
            self.currentLetter = PHContent[randomLetter]
            self.currentSound = self.currentLetter.sounds(for: difficulty ?? .standardDifficulty).random()
            self.answerWord = self.currentSound.allWords.random()
        }
        
        // now that i have currentSound...
        setupStars()
        
        //get other (wrong) word choices
        let allWords = PHContent.allWordsNoDuplicates
        let blacklistedSound = currentSound.ipaPronunciation ?? currentSound.displayString.lowercased()
        let additionalBlacklists = currentSound.blacklist
        
        let possibleWords = allWords.filter { word in
            
            for character in blacklistedSound {
                if word.pronunciation?.contains("\(character)") == true {
                    return false
                }
            }
            
            for blacklist in additionalBlacklists {
                if word.text.lowercased().contains(blacklist) {
                    return false
                }
            }
            
            if let sound = sound, sound.soundId == "schwa" && sound.displayString.lowercased() == "i" {
                //special case: remove hatchet, basket,
                //and any other two- syllable word in which the vowel in the second syllable is a, e, i, or u.
                var vowels = 0
                for letter in word.text {
                    if (letter == "a" || letter == "e" || letter == "i" || letter == "u")
                        || (letter == "o" && vowels == 0) {
                        vowels += 1
                        if vowels > 1 {
                            return false
                        }
                    }
                }
            }
            
            return true
        }
        
        
        // used only for phonics: all 4 word choices, including answer
        var selectedWords: [Word] = [answerWord]
        if difficulty == .standardDifficulty {
            while selectedWords.count != wordViews.count {
                if let candidateWord = possibleWords.random(), !selectedWords.contains(candidateWord) {
                    selectedWords.append(candidateWord)
                }
            }
            selectedWords = selectedWords.shuffled()
        }
        
        // used only for alphabet letters: all 4 letter choices, including answer
        var selectedLetters: [String] = [currentAlphabetLetter!]
        if difficulty == .easyDifficulty {
            while selectedLetters.count != wordViews.count {
                let candidateLetter = String.randomAlphabetLetter()
                if !selectedLetters.contains(candidateLetter) {
                    selectedLetters.append(candidateLetter)
                }
            }
            selectedLetters = selectedLetters.shuffled()
        }
        
        
        
        // set Phonics wordviews to be images of differnt words,
        // and set Alphabet Letters wordviews to be single letters
        
        for (index, wordView) in wordViews.enumerated() {
            wordView.center = self.originalCenters[wordView]!
            wordView.showingText = false
            wordView.layoutIfNeeded()
            wordView.transform = CGAffineTransform.identity
            wordView.alpha = 1.0
            
            if self.difficulty == .easyDifficulty {
                // alphabet letters: only letter, no image
                wordView.useLetter(selectedLetters[index])
                iPad() ? wordView.letterLabelView.editLabelFont(font: UIFont.comicSans(size: 90)) : wordView.letterLabelView.editLabelFont(font: UIFont.comicSans(size: 65))
                
            } else {
                // phonics: include image
                wordView.useWord(selectedWords[index], forSound: currentSound, ofLetter: currentLetter)
            }
        }
        
        if difficulty == .standardDifficulty {
            soundLabel.text = self.currentSound.displayString.lowercased()
            
            //update puzzle
            puzzleView.puzzleName = self.currentSound.puzzleName
            
            if let puzzle = puzzleView.puzzle {
                let puzzleProgress = Player.current.progress(for: puzzle)
                
                puzzleView.isPieceVisible = puzzleProgress.isPieceOwned
            }
        } else {
            soundLabel.text = ""
        }
        
        
        transitionToCurrentSound(isFirst: isFirst)
    }
    
    
    
    
    // MARK: - STARS
    
    func setupStars() {
        guard let sound = currentSound else {return}
        let star = Player.current.stars(for: self.difficulty == .easyDifficulty ? sound.sourceLetter : sound.soundId)
        self.starsHighScore = star.highScore
        self.starsCurrentStreak = star.currentStreak
    }
    
    
    
    
    
    //MARK: - Question Animation
    
    func transitionToCurrentSound(isFirst: Bool) {
        //animate if not first
        if !isFirst {
            var viewsToAnimate = [wordViews.first!.superview!]
            
            //only transition the sound label and puzzle if animating from all sounds
            if self.sound == nil {
                viewsToAnimate.append(self.soundLabel.superview!)
            }
            
            for view in viewsToAnimate {
                playTransitionForView(view, duration: 0.5, transition: kCATransitionPush, subtype: kCATransitionFromTop,
                                      timingFunction: CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut))
            }
        }
        
        delay(0.5) {
            self.playQuestionAnimation()
        }
    }
    
    func playQuestionAnimation() {
        
        self.state = .playingQuestion
        self.wordViews.first!.superview!.isUserInteractionEnabled = true
        
        var startTime: TimeInterval = 0.0
        let timeBetween = 0.85
        
        Timer.scheduleAfter(startTime, addToArray: &timers) {
            shakeView(self.soundLabel)
        }
        
        let info = difficulty == .easyDifficulty ? currentLetter.audioInfo : currentSound.pronunciationTiming
        
        Timer.scheduleAfter(startTime - 0.3, addToArray: &timers) {
            PHContent.playAudioForInfo(info)
        }
        
        startTime += (info?.wordDuration ?? 0.5) + timeBetween
        
        for (index, wordView) in self.wordViews.enumerated() {

            Timer.scheduleAfter(startTime, addToArray: &self.timers) {
                self.playSoundAnimationForWord(index, delayAnimationBy: 0.3)
            }
            
            startTime += (wordView.word?.audioInfo?.wordDuration ?? 0.0) + timeBetween
            
            if (wordView == self.wordViews.last) {
                Timer.scheduleAfter(startTime - timeBetween, addToArray: &self.timers) {
                    self.state = .waiting
                }
            }
        }
    }
    
    func playSoundAnimationForWord(_ index: Int, delayAnimationBy delay: TimeInterval = 0.0, extendAnimationBy extend: TimeInterval = 0.0) {
        if index >= self.wordViews.count { return }
        
        let wordView = self.wordViews[index]
        guard let word = wordView.word else { return }
        word.playAudio()
        
        UIView.animate(withDuration: 0.5, delay: delay, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
            wordView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            wordView.alpha = 1.0
        }, completion: nil)
        
        let shrinkDelay = delay + extend + (word.audioInfo?.wordDuration ?? 0.5)
        UIView.animate(withDuration: 0.5, delay: shrinkDelay, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [.allowUserInteraction], animations: {
            wordView.transform = CGAffineTransform.identity
        }, completion: nil)
    }
    
    func stopAnimations(stopAudio: Bool = true) {
        if self.state != .waiting {
            self.timers.forEach{ $0.invalidate() }
            if stopAudio { UAHaltPlayback() }
            self.state = .waiting
        }
    }
    
    
    //MARK: - User Interaction
    
    @IBAction func backPressed(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func bankButtonPressed(_ sender: UIButton) {
        presentBank()
    }
    
    func presentBank() {
        self.view.isUserInteractionEnabled = false
        
        BankViewController.present(
            from: self,
            bank: self.bank,
            onDismiss: {
                self.view.isUserInteractionEnabled = true
        })
    }
    
    @IBAction func repeatSound(_ sender: UIButton) {
        if UAIsAudioPlaying() {return}
        
        sender.isUserInteractionEnabled = false
        delay(1.0) {
            sender.isUserInteractionEnabled = true
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
    
    func wordViewSelected(_ wordView: WordView) {
        self.attempts += 1
        
        if self.difficulty == .easyDifficulty {
            let selectedLetter = wordView.letterLabelView.text
            if let letter = selectedLetter, letter.hasSuffix(currentAlphabetLetter!) {
                // correct sound!
                if attempts == 1 { // first try
                    starsCurrentStreak += 1
                } else {
                    starsCurrentStreak = 0
                }
                
                correctWordSelected(wordView)
            } else {
                
                shakeView(wordView)
                delay(0.6) {
                    // replay sound
                    PHContent.playAudioForInfo(self.currentLetter.audioInfo)
                }
            }
        } else {
            // PHONICS, not alphabet letters

            if wordView.word == answerWord {
                if attempts == 1 { // first try
                    index -= 1
                    if remainingAnswerWordPool != nil {
                        remainingAnswerWordPool.remove(at: index)
                    }
                    
                    starsCurrentStreak += 1
                    
                } else {
                    starsCurrentStreak = 0
                }
                
                correctWordSelected(wordView)
            } else {
                wordView.setShowingText(true, animated: true)
                shakeView(wordView)
            }
        }
    }
    
    @IBAction func showPuzzleDetail(_ sender: Any) {
        //don't allow the user to show the puzzle during a transition (but allow if spawned from other action)
        if sender is UIButton && self.state == .transitioning { return }
        
        self.view.isUserInteractionEnabled = false
        PuzzleDetailViewController.present(
            for: self.currentSound,
            from: self.puzzleView,
            withPuzzleShadow: self.puzzleShadow,
            in: self,
            onDismiss: {
                self.view.isUserInteractionEnabled = true
                
                if self.dismissOnReturnFromModal {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        )
    }
    
    func correctWordSelected(_ wordView: WordView) {
        self.state = .transitioning
        self.wordViews.first!.superview!.isUserInteractionEnabled = false
        
        if self.difficulty == .standardDifficulty {
            wordView.setShowingText(true, animated: true, duration: 0.5)
        }
        
        func hideOtherWords() {
            UIView.animate(withDuration: 0.2, animations: {
                self.wordViews.filter{ $0 != wordView }.forEach{ $0.alpha = 0.0 }
            }) 
        }
        
        func animateAndContinue() {
            UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0.0, options: [.beginFromCurrentState], animations: {
                wordView.center = wordView.superview!.superview!.convert(wordView.superview!.center, to: wordView.superview!)
            }, completion: nil)
            
            PHPlayer.play("correct", ofType: "mp3")
            
            if self.difficulty == .easyDifficulty {
                delay(0.6) {
                    PHContent.playAudioForInfo(self.currentLetter.audioInfo) // good reinforcement
                }
            }
            
            if self.difficulty == .standardDifficulty {
                // puzzle
                let pieceSpawnPoint = self.view.convert(wordView.center, from: wordView.superview)
                Timer.scheduleAfter(0.8, addToArray: &self.timers, handler: self.addNewPuzzlePiece(spawningAt: pieceSpawnPoint))
                var puzzleWasAlreadyComplete = false
                if let puzzle = self.puzzleView.puzzle {
                    puzzleWasAlreadyComplete = Player.current.progress(for: puzzle).isComplete
                }
                
                //if the puzzle goes from Incomplete to Complete, show the puzzle detail
                //Otherwise continue to next sound
                Timer.scheduleAfter(1.45, addToArray: &self.timers, handler: {
                    
                    if !puzzleWasAlreadyComplete, let puzzle = self.puzzleView.puzzle {
                        if Player.current.progress(for: puzzle).isComplete {
                            self.dismissOnReturnFromModal = true
                            self.showPuzzleDetail(self)
                            return
                        }
                    }
                    
                    self.setupForRandomSoundFromPool()
                })
            } else {
                // coin
                Timer.scheduleAfter(1.45, addToArray: &self.timers) {
                    let selectedWordViewCenter = wordView.superview!.convert(wordView.center, to: self.view)
                    self.playCoinAnimation(startingAt: selectedWordViewCenter)
                }
                
                Timer.scheduleAfter(2.7, addToArray: &self.timers) {
                    //celebration if over threshold, else continue
                    if self.bank.celebrate {
                        self.presentBank()
                    } else {
                        self.setupForRandomSoundFromPool()
                    }
                }
            }
        }
        
        if UAIsAudioPlaying() {
            UAWhenDonePlayingAudio {
                hideOtherWords()
                Timer.scheduleAfter(0.1, addToArray: &self.timers, handler: animateAndContinue)
            }
        } else {
            Timer.scheduleAfter(0.45, addToArray: &self.timers, handler: hideOtherWords)
            Timer.scheduleAfter(0.55, addToArray: &self.timers, handler: animateAndContinue)
        }
    }
    
    
    //MARK: - Coins
    
    func playCoinAnimation(startingAt origin: CGPoint) {
        var coinImage: UIImage?
        switch(self.attempts) {
        case 1:
            coinImage = #imageLiteral(resourceName: "coin-gold")
            bank.coins.gold += 1
        case 2:
            coinImage = #imageLiteral(resourceName: "coin-silver")
            bank.coins.silver += 1
        default:
            coinImage = nil
        }
        
        if let coinImage = coinImage {
            
            //save new coin
            Player.current.save()
            
            let coinView = UIImageView(image: coinImage)
            coinView.frame.size = iPad() ? CGSize(width: 150, height: 150) : CGSize(width: 75, height: 75)
            coinView.center = origin
            coinView.alpha = 0.0
            self.view.addSubview(coinView)
            
            self.view.bringSubview(toFront: bankButton)
            
            //animate coin into piggy bank
            UIView.animate(withDuration: 0.125, animations: {
                coinView.alpha = 1.0
            })
            
            UIView.animate(withDuration: 0.95, delay: 0.0, usingSpringWithDamping: 1.0, animations: {
                coinView.frame.size = CGSize(width: 40, height: 40)
                coinView.center = self.bankButton.superview!.convert(self.bankButton.center, to: self.view)
            })
            
            //pulse piggybank
            UIView.animate(withDuration: 0.25, delay: 0.5, options: [.allowUserInteraction, .curveEaseInOut, .beginFromCurrentState], animations: {
                self.bankButton.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
            }, completion: nil)
            
            UIView.animate(withDuration: 0.45, delay: 0.9, options: [.allowUserInteraction, .curveEaseInOut, .beginFromCurrentState], animations: {
                self.bankButton.transform = .identity
            }, completion: { bool in
                coinView.alpha = 0.0
            })
        }
    }
    
    
    //MARK: - Puzzle Pieces
    
    //partial-application so it can passed as () -> () to Timer.scheduleAfter
    func addNewPuzzlePiece(spawningAt spawnPoint: CGPoint) -> () -> () {
        return {
            guard let puzzle = self.puzzleView.puzzle else { return }
            let progress = Player.current.progress(for: puzzle)
            
            func animate(piece newPiece: (row: Int, col: Int)) {
                
                //find subview for specific piece
                guard let newPieceView = self.puzzleView.subviews.first(where: { subview in
                    guard let pieceView = subview as? PuzzlePieceView else { return false }
                    
                    return (pieceView.piece.row == newPiece.row)
                        && (pieceView.piece.col == newPiece.col)
                }) as? PuzzlePieceView else { return }
                
                //set up initial state
                guard let pieceImageView = newPieceView.imageView else { return }
                let animationImage = UIImageView(image: pieceImageView.image)
                
                let pieceScale: CGFloat = iPad() ? 1.5 : 2.25
                animationImage.alpha = 0.0
                animationImage.frame.size = CGSize(width: pieceImageView.frame.width * pieceScale,
                                                   height: pieceImageView.frame.height * pieceScale)
                animationImage.center = spawnPoint
                
                self.view.addSubview(animationImage)
                
                //animate
                UIView.animate(withDuration: 0.1) {
                    animationImage.alpha = 1.0
                }
                
                UIView.animate(withDuration: 0.5, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                
                    let finalFrame = self.view.convert(pieceImageView.bounds, from: pieceImageView)
                    animationImage.frame = finalFrame
                    
                }, completion: { _ in
                    animationImage.removeFromSuperview()
                    newPieceView.isHidden = false
                })
                
                
            }
            
            let numberOfPieces: Int
            switch(self.attempts) {
                case 0...1: numberOfPieces = 2
                case 2: numberOfPieces = 1
                default: numberOfPieces = 0
            }
            
            for _ in 0 ..< numberOfPieces {
                if let piece = progress.addRandomPiece() {
                    animate(piece: piece)
                }
            }
            
            Player.current.save()
        }
    }
    
    
    //MARK: - Interactive Grow behavior
    
    override func interactiveGrowScaleFor(_ view: UIView) -> CGFloat {
        return 1.1
    }
    
    override func interactiveViewWilGrow(_ view: UIView) {
        if let wordView = view as? WordView {
            
            if self.state == .playingQuestion {
                self.stopAnimations(stopAudio: false)
            }
            
            wordView.word?.playAudio()
        }
    }
    
    override func shouldAnimateShrinkForInteractiveView(_ view: UIView, isTouchUp: Bool) -> Bool {
        if view is WordView {
            return !isTouchUp
        }
        
        return true
    }
    
    override func totalDurationForInterruptedAnimationOn(_ view: UIView) -> TimeInterval? {
        if let wordView = view as? WordView, let duration = wordView.word?.audioInfo?.wordDuration {
            if wordView.word == self.answerWord { return 4.0 }
            return duration + 0.5
        } else { return 1.0 }
    }
    
    override func touchUpForInteractiveView(_ view: UIView) {
        if let wordView = view as? WordView {
            self.wordViewSelected(wordView)
        }
    }
    
}
