//
//  TransparentView.swift
//  LNReader
//
//  Created by Matt Lin on 11/30/17.
//  Copyright © 2017 Matt Lin. All rights reserved.
//

import UIKit

class TransparentView: UIView {
    init(controller: ChapterViewController) {
        _controller = controller
        super.init(frame: controller.view.frame)
        self.backgroundColor = UIColor.clear
        self.isMultipleTouchEnabled = false
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        _controller?.toggleNavigationBar()
    }
    
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private weak var _controller: ChapterViewController?
}
