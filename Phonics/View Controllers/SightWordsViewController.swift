//
//  SightWordsViewController.swift
//  Phonics
//
//  Created by Cal Stephens on 5/21/17.
//  Copyright © 2017 Cal Stephens. All rights reserved.
//

import UIKit

class SightWordsViewController : UIViewController, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    
    //MARK: - Presentation
    
    static let storyboardID = "sightWords"
    
    public static func present(from source: UIViewController, using sightWordsManager: SightWordsManager) {
        let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: storyboardID) as! SightWordsViewController
        controller.sightWordsManager = sightWordsManager
        source.present(controller, animated: true, completion: nil)
    }
    
    
    var sightWordsManager: SightWordsManager!
    @IBOutlet weak var collectionView: UICollectionView!
    
    @IBOutlet weak var sidebarColorView: UIView!
    
    var bank: Bank {
        switch self.sightWordsManager!.category {
        case .preK:
            return Player.current.prekBank
        case .kindergarten:
            return Player.current.kindergartenBank
        case .readAWord:
            return Player.current.readAWordBank
        }
    }
    
    
    //MARK: - Setup
    
    override func viewDidLoad() {
        self.view.backgroundColor = self.sightWordsManager.category.color
        sidebarColorView.backgroundColor = self.sightWordsManager.category.color
    }

    override func viewWillAppear(_ animated: Bool) {
        collectionView.reloadData()
    }
    
    func playWords(wordsToPlay: [SightWord]) {
        var words = wordsToPlay
        if let nextWord = words.popLast() {
            nextWord.playAudio(using: sightWordsManager)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
                self.playWords(wordsToPlay: words)
            })
        }
    }
    
    
    //MARK: - Collection View Delegate
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.sightWordsManager.words.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let sightWord = self.sightWordsManager.words[indexPath.item]
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: SightWordCell.identifier, for: indexPath) as! SightWordCell
        cell.decorate(for: sightWord)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (self.view.frameInsetByMargins.width - 110) / 3
        return CGSize(width: width, height: width * 0.85)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        self.view.isUserInteractionEnabled = false
        
        //animate selection
        let cell = collectionView.cellForItem(at: indexPath)
        UIView.animate(withDuration: 0.4, delay: 0.0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
            cell?.transform = CGAffineTransform(scaleX: 1.075, y: 1.075)
        }, completion: nil)
        
        let sightWord = self.sightWordsManager.words[indexPath.item]
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) {
            SentencesViewController.present(from: self, for: sightWord, in: self.sightWordsManager)
            
            UIView.animate(withDuration: 0.4, delay: 0.5, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.0, options: [], animations: {
                cell?.transform = .identity
            }, completion: nil)
            
            self.view.isUserInteractionEnabled = true
        }
    }
    
    
    //MARK: - User Interaction
    
    @IBAction func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func bankButtonPressed(_ sender: Any) {
        self.view.isUserInteractionEnabled = false
        
        BankViewController.present(
            from: self,
            bank: self.bank,
            onDismiss: {
                self.view.isUserInteractionEnabled = true
        })
    }
    
    @IBAction func playQuiz(_ sender: Any) {
        SightWordsQuizViewController.present(from: self, using: self.sightWordsManager, mode: .allWords)
    }
}


//MARK: - SightWordCell

class SightWordCell : UICollectionViewCell {
    
    static let identifier = "sightWord"
    static var backgroundThread = DispatchQueue(label: "SightWordCellBackground", qos: .background)
    
    @IBOutlet var cardView: UIView!
    @IBOutlet var wordLabel: UILabel!
    @IBOutlet var leftImageView: UIImageView!
    @IBOutlet var rightImageView: UIImageView!
    @IBOutlet var fullImageView: UIImageView! // for readAWord, only one image
    @IBOutlet weak var starsStackView: UIStackView!
    @IBOutlet weak var checkmark: UIButton!
    
    // TODO: - THIS MAY NOT BE PERFORMANT to check category each time!
    
    func decorate(for sightWord: SightWord) {
        self.cardView.layer.cornerRadius = self.cardView.frame.height * 0.1
        self.wordLabel.text = sightWord.text
        self.wordLabel.adjustsFontSizeToFitWidth = true
        self.wordLabel.minimumScaleFactor = 0.2
        
        func shouldIgnoreImageUpdate() -> Bool {
            //ignore the image update if the text has already changed to a different word
            //(the cells can be resused faster than the images are loaded)
            return self.wordLabel.text != sightWord.text
        }
        
        func update(imageView: UIImageView, with sentence: Sentence) {
            imageView.update(on: SightWordCell.backgroundThread, withImage: {
                return sentence.thumbnail // this line is crashing
            }, shouldIgnoreUpdateIf: shouldIgnoreImageUpdate)
        }
        
        if let sentence2 = sightWord.sentence2 {
            fullImageView.removeFromSuperview()
            update(imageView: leftImageView, with: sightWord.sentence1)
            update(imageView: rightImageView, with: sentence2)
        } else {
            // readAWord: show only one image on card
            self.leftImageView.removeFromSuperview()
            self.rightImageView.removeFromSuperview()
            update(imageView: fullImageView, with: sightWord.sentence1)
        }
        
        // show stars
        // phonics: key is the phonic. sound is never nil.
        // alphabet letters: key is the letterText, like "A"
        let stars = Player.current.stars(for: sightWord.text).highScore
        starsStackView.update(stars: stars)
        
        checkmark.isHidden = stars < 5
    }
}
