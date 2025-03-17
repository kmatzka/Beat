//
//  BeatOutlineSettings.swift
//  Beat macOS
//
//  Created by Lauri-Matti Parppei on 25.6.2023.
//  Copyright © 2023 Lauri-Matti Parppei. All rights reserved.
//

import Cocoa
import BeatCore

@objc public protocol BeatOutlineSettingDelegate {
	func reloadOutline()
	weak var editorDelegate:BeatEditorDelegate? { get }
}

class BeatOutlineSettings: NSViewController {
	@IBOutlet weak var showSynopsis:NSButton?
	@IBOutlet weak var showNotes:NSButton?
	@IBOutlet weak var showSceneNumbers:NSButton?
	@IBOutlet weak var showMarkers:NSButton?
	@IBOutlet weak var showSnapshots:NSButton?
	
	var settings:[String:NSButton] = [:]
	
	@objc weak var outlineDelegate:BeatOutlineSettingDelegate?
	
	init() {
		super.init(nibName: "BeatOutlineSettings", bundle: Bundle.main)
	}

	required init?(coder: NSCoder) {
		super.init(coder: coder)
	}
		
	@IBAction func toggle(sender:BeatUserDefaultCheckbox?) {
		guard let state = sender?.state, let key = sender?.userDefaultKey
		else { return }
		
		let value = (state == .on) ? true : false
		BeatUserDefaults.shared().save(value, forKey: key)
		
		if sender?.resetPreview ?? false {
			if value {
				self.outlineDelegate?.editorDelegate?.parser.scenes().forEach { $0.printedLength = 0 }
			}
			
			self.outlineDelegate?.editorDelegate?.resetPreview()
		}
		
		outlineDelegate?.reloadOutline()
	}
}

