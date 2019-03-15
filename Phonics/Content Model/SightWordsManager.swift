//
//  SightWordsManager.swift
//  Phonics
//
//  Created by Cal Stephens on 5/21/17.
//  Copyright © 2017 Cal Stephens. All rights reserved.
//

import Foundation

class SightWordsManager {
    
    
    //MARK: - Categories
    
    public enum Category {
        case preK, kindergarten, readAWord
        
        var color: UIColor {
            switch(self) {
            case .preK: return #colorLiteral(red: 0.5109489352, green: 0.7969939907, blue: 0.6771487374, alpha: 1)
            case .kindergarten: return #colorLiteral(red: 0.5696855614, green: 0.8092797134, blue: 0.5067765564, alpha: 1)
            case .readAWord: return #colorLiteral(red: 0.7, green: 0.3, blue: 0.2, alpha: 1)
            }
        }
        
        private var folderNamePrefix: String {
            switch(self) {
            case .preK: return "Pre-K Sight Words"
            case .kindergarten: return "Kindergarten Sight Words"
            case .readAWord: return "Words"
            }
        }
        
        var audioFolderName: String {
            return self.folderNamePrefix
        }
        
        var imageFolderName: String {
            return self == .readAWord ? "" : self.folderNamePrefix + " Art"
        }
        
        func individualAudioFilePath(for word: SightWord) -> String {
            return  self.audioFolderName + (self == .readAWord ? "/" : "/Individual Words/") + word.text.lowercased()
        }
    }
    
    
    //MARK: - Setup
    
    let category: Category
    let words: [SightWord]
    
    public init(category: Category) {
        self.category = category
        
        guard let mainResourcePath = Bundle.main.resourcePath else {
            self.words = []
            return
        }
        
        let audioFolder = mainResourcePath.appending("/" + category.audioFolderName)
        let imageFolder = mainResourcePath.appending("/" + category.imageFolderName)
        
        let audioFiles = (try? FileManager.default.contentsOfDirectory(atPath: audioFolder)) ?? []
        let imageFiles = (try? FileManager.default.contentsOfDirectory(atPath: imageFolder)) ?? []
        
        
        
        self.words = SightWordsManager.buildSightWords(fromAudio: audioFiles, andImages: imageFiles, for: category)
    }
    
    static func buildSightWords(fromAudio audioFiles: [String],
                                andImages allImageFiles: [String],
                                for category: Category) -> [SightWord] {
        
        var imageFiles = allImageFiles
        
        var completedWords = [SightWord]()
        var temporarySentences = [String : Sentence]()
        
        for audioFileNameWithEnding in audioFiles {
            //audioFileNameWithEnding format: "word-# (Sentence here).mp3"
            guard let audioFileName = audioFileNameWithEnding.components(separatedBy: ".").first else { continue }
            guard let metadata = audioFileName.components(separatedBy: " ").first else { continue }
            guard let highlightWord = category == .readAWord ? audioFileName : metadata.components(separatedBy: "-").first else { continue }
            
            var sentenceText = category == .readAWord ? audioFileName : audioFileName.replacingOccurrences(of: metadata + " ", with: "")
            
            let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
            tagger.string = sentenceText
            if #available(iOS 11.0, *) {
                tagger.enumerateTags(in: NSRange(location: 0, length: sentenceText.utf16.count), unit: .word, scheme: .lexicalClass, options: [.omitPunctuation, .omitWhitespace]) { (tag, range, _) in
                    if tag == NSLinguisticTag.verb {
                        sentenceText = sentenceText.replacingOccurrences(of: ";", with: ".")
                    }
                }
                sentenceText = sentenceText.replacingOccurrences(of: ";", with: "") // Omit punctuation
                sentenceText = sentenceText.lowercased() // Omit capitalization
            } else {
                // Fallback on earlier versions
                // If we can't check for verbs we assume all sentences are complete
                sentenceText = sentenceText.replacingOccurrences(of: ";", with: ".")
            }
            
            // sentenceText = sentenceText.replacingOccurrences(of: ";", with: ".")
            
            guard let indexOfImageWithSameMetadata = imageFiles.index(where: { $0.hasPrefix(metadata) }) else { continue }
            var imageFileName = imageFiles.remove(at: indexOfImageWithSameMetadata)
            
            if imageFileName == "pig latin content.mp3" {
                imageFileName = "pig.jpg" // weird bug, idk
            }
            
            
            let newSentence = Sentence(text: sentenceText,
                                   highlightWord: highlightWord,
                                   audioFileName: category.audioFolderName + "/" + audioFileName,
                                   imageFileName: (category == .readAWord ? imageFileName : category.imageFolderName + "/" + imageFileName))
            
            
            //build completed SightWord. note that readAWord does not need a pair.
            if category == .readAWord {
                let newSightWord = SightWord(text: highlightWord, sentence1: newSentence, sentence2: nil)
                completedWords.append(newSightWord)
                temporarySentences.removeValue(forKey: highlightWord)
            } else if let otherSentence = temporarySentences[highlightWord] {
                    let newSightWord = SightWord(text: highlightWord, sentence1: otherSentence, sentence2: newSentence)
                    completedWords.append(newSightWord)
                    temporarySentences.removeValue(forKey: highlightWord)
            } else {
                // first time reaching this word
                temporarySentences[highlightWord] = newSentence
            }
            
        }
        
        if temporarySentences.count != 0 {
            print("\nSOME TEMPORARY SENTENCES WEREN'T ASSIGNED TO WORDS (missing their partner):")
            temporarySentences.forEach {
                print("\($0.key): \($0.value.text)")
            }
            print()
        }
        
        return completedWords.sorted(by: { left, right in
            left.text.lowercased() < right.text.lowercased()
        })
    }
    
}
