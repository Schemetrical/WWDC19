//
//  IntroViewController.swift
//  BattleshipAR
//
//  Created by Yichen Cao on 2019-03-16.
//  Copyright © 2019 Yichen Cao. All rights reserved.
//

import UIKit
import MultipeerConnectivity
import ARKit

class IntroViewController: UIViewController {
    
    weak var delegate: IntroViewControllerDelegate?
    private var session: MCSession!
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    private let serviceType = "yc-btlshp-ar"
    private var myPeerID: MCPeerID!
    let hostButton = UIButton(type: .system)
    let joinButton = UIButton(type: .system)
    let infoLabel = UILabel()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.white
        
        // Do any additional setup after loading the view.
        myPeerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        hostButton.setTitle("Host", for: .normal)
        hostButton.addTarget(self, action: #selector(host(sender:)), for: .touchUpInside)
        hostButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        joinButton.setTitle("Join", for: .normal)
        joinButton.addTarget(self, action: #selector(join(sender:)), for: .touchUpInside)
        joinButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        let stackView = UIStackView(arrangedSubviews: [hostButton, joinButton])
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        view.bottomAnchor.constraint(equalTo: stackView.bottomAnchor, constant: 50).isActive = true
        view.centerXAnchor.constraint(equalTo: stackView.centerXAnchor).isActive = true
        
        let topLabel = UILabel()
        topLabel.text = "BattleshipAR"
        topLabel.font = UIFont.systemFont(ofSize: 30, weight: .heavy)
        topLabel.textAlignment = .center
        topLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topLabel)
        topLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 100).isActive = true
        topLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        
        infoLabel.text = ""
        infoLabel.textAlignment = .center
        infoLabel.numberOfLines = 2
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(infoLabel)
        infoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        infoLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor).isActive = true
    }
    
    @objc func host(sender: UIButton) {
        serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        serviceAdvertiser.delegate = self
        infoLabel.text = "Looking for another device\nto join our game!"
        serviceAdvertiser.startAdvertisingPeer()
        disableButtons()
    }
    
    @objc func join(sender: UIButton) {
        serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        serviceBrowser.delegate = self
        infoLabel.text = "Waiting for another device\nto invite us into the game!"
        serviceBrowser.startBrowsingForPeers()
        disableButtons()
    }
    
    func disableButtons() {
        hostButton.isEnabled = false
        joinButton.isEnabled = false
    }
    
}

extension IntroViewController: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
        infoLabel.text = "\(peerID.displayName)\nhas joined the game!"
        delegate?.becomeHost(session: session)
        dismiss(animated: true, completion: nil)
    }
}

extension IntroViewController: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        infoLabel.text = "Asking \(peerID.displayName)\nto join the game!"
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        print("Lost peer!")
    }
}

extension IntroViewController: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(GameManager.EncapsulatedMessage.self, from: data) {
            if message.message == .worldMapData, let data = message.data {
                guard let ewm = try? JSONDecoder().decode(GameManager.EncapsulatedWorldMap.self, from: data) else {
                    return
                }
                if let wm = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: ewm.worldMapData), let worldMap = wm, let gb = try? NSKeyedUnarchiver.unarchivedObject(ofClass: GameBoard.self, from: ewm.gameBoardData), let gameBoard = gb {
                    delegate?.becomePeer(session: session, worldMap: worldMap, gameBoard: gameBoard)
                    dismiss(animated: true, completion: nil)
                }
            } else if message.message == .hostSettingUpGame {
                DispatchQueue.main.async {
                    self.infoLabel.text = "Host is setting up a game!"
                }
            }
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
    
    
}

protocol IntroViewControllerDelegate: class {
    func becomeHost(session: MCSession)
    func becomePeer(session: MCSession, worldMap: ARWorldMap,  gameBoard: GameBoard)
}
