import Foundation
import AVFoundation
import UIKit

// MARK: - Haptic Manager
public final class HapticManager {
    public static let shared = HapticManager()
    private init() {}
    
    public func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }
    
    public func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }
    
    public func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }
}

// MARK: - Audio Manager
@MainActor
public final class AudioManager: ObservableObject {
    public static let shared = AudioManager()
    private var player: AVAudioPlayer?
    
    private init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    public enum SoundEffect: String {
        case celebration = "streak_celebration"
        case crackFirst = "streak_unfreeze_crack_first"
        case crackSecond = "streak_unfreeze_crack_second"
        case dayLands = "streak_unfreeze_day_lands"
        case flame = "streak_unfreeze_flame"
    }
    
    public func play(_ sound: SoundEffect) {
        guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3") else {
            // Fallback: sound effect not in bundle root, silent graceful fallback
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("Failed to play sound \(sound.rawValue): \(error)")
        }
    }
    
    public func playCelebration() { play(.celebration) }
    public func playFlame() { play(.flame) }
    public func playCrack1() { play(.crackFirst) }
    public func playCrack2() { play(.crackSecond) }
    public func playDayLands() { play(.dayLands) }
}

public typealias SoundEffectManager = AudioManager

// MARK: - Keyboard Dismissal Helper
public enum KeyboardHelper {
    public static func hide() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

import SwiftUI

extension View {
    public func hideKeyboard() {
        KeyboardHelper.hide()
    }
}