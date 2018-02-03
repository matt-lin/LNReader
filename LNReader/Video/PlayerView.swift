//
//  PlayerView.swift
//  Manga Reader
//
//  Created by Matt Lin on 1/2/18.
//  Copyright © 2018 Matt Lin. All rights reserved.
//

import UIKit
import AVFoundation

class PlayerView: UIView {
    init(frame: CGRect, file: URL, delegate: VideoTableViewController?) {
        _topBar = UIVisualEffectView(frame: CGRect(x: 0, y: 0, width: 667, height: 50))
        _topBar.effect = UIBlurEffect(style: .regular)
        
        _slider = UISlider(frame: CGRect(x: 83.5, y: 0, width: 500, height: 50))

        _botBar = UIVisualEffectView(frame: CGRect(x: 0, y: 340, width: 667, height: 50))
        _botBar.effect = UIBlurEffect(style: .regular)
        
        _pauseButton = UIButton(frame: CGRect(x: 315.5, y: 4, width: 25, height: 27))
        _playButton = UIButton(frame: CGRect(x: 315.5, y: 4, width: 25, height: 27))
        _forward = UIButton(frame: CGRect(x: 380.5, y: 4, width: 25, height: 27))
        _backward = UIButton(frame: CGRect(x: 250.5, y: 4, width: 25, height: 27))
        
        active = 0
        super.init(frame: frame)
        _delegate = delegate
        setupPlayer(file)
        
        _slider.addTarget(self, action: #selector(jumpTo(_:)), for: .valueChanged)
        _topBar.contentView.addSubview(_slider)

        
        let backButton = UIButton(frame: CGRect(x: 10, y: 0, width: 50, height: 50))
        backButton.setTitle("Done", for: .normal)
        backButton.addTarget(self, action: #selector(back), for: .touchUpInside)
        backButton.setTitleColor(UIColor.black, for: .normal)
        backButton.setTitleColor(UIColor(red: 1, green: 1, blue: 1, alpha: 0.5), for: .highlighted)
        _topBar.contentView.addSubview(backButton)

        setupImages()
        
        self.addSubview(_topBar)
        self.addSubview(_botBar)
        
        self.backgroundColor = UIColor.black
    }
   
    
    deinit {
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let temp = doc.appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent("temp.mp4")
        try? FileManager.default.removeItem(at: temp)
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    @objc func jumpTo(_ sender: UISlider) {
        guard let durationTime = self.player?.currentItem?.duration, let time = Double(exactly: sender.value) else {
            return
        }
        
        var targetTime = CMTime(seconds: time, preferredTimescale: durationTime.timescale)
        guard targetTime.isValid && targetTime.isNumeric else { return }
        
        if targetTime > durationTime {
            targetTime = durationTime
        }
        
        let zero: CMTime = kCMTimeZero
        
        _playerItem?.seek(to: targetTime, toleranceBefore: zero, toleranceAfter: zero, completionHandler: nil)
    }
    
    
    @objc func back() {
        self.navigationController?.toggleNavigationBar(hide: false)
        if _observer != nil {
            player?.removeTimeObserver(_observer!)
        }
        player?.replaceCurrentItem(with: nil)
        _playerItem = nil
        player = nil
        
        AppUtility.lockOrientation(.portrait, andRotateTo: .portrait)
        self.navigationController?.popViewController(animated: false)
    }
    
    
    @objc func play() {
        self.player?.play()
        _playButton.removeFromSuperview()
        _botBar.contentView.addSubview(_pauseButton)
    }
    
    
    @objc func pause() {
        self.player?.pause()
        _pauseButton.removeFromSuperview()
        _botBar.contentView.addSubview(_playButton)
    }
    
    
    @objc func forward() {
        jump(amount: 10)
    }
    
    
    @objc func backward() {
        jump(amount: -10)
    }
    
    
    func jump(amount: Double) {
        guard let durationTime = self.player?.currentItem?.duration else {
            return
        }
        
        var targetTime = CMTimeAdd(self.player!.currentTime(), CMTime(seconds: amount, preferredTimescale: 1))
        guard targetTime.isValid && targetTime.isNumeric else {
            return
        }
        
        if targetTime > durationTime {
            targetTime = durationTime
        }
        
        let zero: CMTime = kCMTimeZero
        _playerItem?.seek(to: targetTime, toleranceBefore: zero, toleranceAfter: zero, completionHandler: nil)
        hideWait()
    }
    
    
    func show() {
        _topBar.isHidden = false
        _botBar.isHidden = false
        hideWait()
    }
    
    
    func hideWait() {
        let num = active + 1
        active += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            if num == self?.active {
                self?._topBar.isHidden = true
                self?._botBar.isHidden = true
            }
        }
    }
    
    
    func hide() {
        _topBar.isHidden = true
        _botBar.isHidden = true
        active += 1
    }
    

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if _topBar.isHidden {
            show()
        } else {
            hide()
        }
    }
    
    
    func setupPlayer(_ file: URL) {
        guard let doc = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let name = file.lastPathComponent
        let iv = String(name[Range(NSMakeRange(0, 16), in: name)!])
        
        let loc = doc.appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent(name)
        let temp = doc.appendingPathComponent("Downloads", isDirectory: true).appendingPathComponent("temp.mp4")

        guard let dec = _delegate.decrypt(location: loc, iv: iv), let _ = try? dec.write(to: temp) else { return }
        
        let asset = AVURLAsset(url: temp)
        let playerItem = AVPlayerItem(asset: asset)
        _playerItem = playerItem
        
        self.player = AVPlayer(playerItem: playerItem)

        self._slider.maximumValue = Float(CMTimeGetSeconds(asset.duration))
        
        _observer = self.player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main, using: { [unowned self] (curr) in
            if self._playerItem?.status == .readyToPlay {
                let time = CMTimeGetSeconds(curr)
                self._slider.value = Float(time)
            }
        })
    }
    
    
    func setupImages() {
        let pauseImage = UIImage(named: "pause")
        let clickedPauseImage = UIImage(named: "clickedPause")
        
        _pauseButton.setImage(pauseImage, for: .normal)
        _pauseButton.setImage(clickedPauseImage, for: .highlighted)
        _pauseButton.addTarget(self, action: #selector(pause), for: .touchUpInside)
        
        let playImage = UIImage(named: "play")
        let clickedPlayImage = UIImage(named: "clickedPlay")
        
        _playButton.setImage(playImage, for: .normal)
        _playButton.setImage(clickedPlayImage, for: .highlighted)
        _playButton.addTarget(self, action: #selector(play), for: .touchUpInside)
        _botBar.contentView.addSubview(_playButton)
        
        _forward.setImage(UIImage(named: "fastforward"), for: .normal)
        _forward.setImage(UIImage(named: "clickedFastforward"), for: .highlighted)
        _forward.addTarget(self, action: #selector(forward), for: .touchUpInside)
        _botBar.contentView.addSubview(_forward)
        
        _backward.setImage(UIImage(named: "fastbackward"), for: .normal)
        _backward.setImage(UIImage(named: "clickedFastbackward"), for: .highlighted)
        _backward.addTarget(self, action: #selector(backward), for: .touchUpInside)
        _botBar.contentView.addSubview(_backward)
    }
    
    
    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }

    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    
    override static var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
    
    
    static func hashStr(str: String) -> String {
        var result = UInt64 (5381)
        let buf = [UInt8](str.utf8)
        for b in buf {
            result = 127 * (result & 0x00ffffffffffffff) + UInt64(b)
        }
        return String(result)
    }
    
    
    var active: Int
    private var _observer: Any?
    private var _playerItem: AVPlayerItem?
    private var _topBar: UIVisualEffectView
    private var _slider: UISlider
    private var _botBar: UIVisualEffectView
    private var _pauseButton, _playButton, _forward, _backward: UIButton
    
    weak var navigationController: ViewController?
    weak private var _delegate: VideoTableViewController!
    
    static let VAL = "passwordpassword"
}
