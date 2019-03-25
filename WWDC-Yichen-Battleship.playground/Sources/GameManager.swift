//
//  GameManager.swift
//  BattleshipAR
//
//  Created by Yichen Cao on 2019-03-16.
//  Copyright © 2019 Yichen Cao. All rights reserved.
//

import SceneKit
import MultipeerConnectivity

class GameManager: NSObject {
    
    public let session: MCSession
    weak var delegate: GameManagerDelegate?
    let isServer: Bool
    var gameState = GameState.setup
    
    enum GameState {
        case setup
        case myTurn
        case enemyTurn
    }
    
    init(isServer: Bool, session: MCSession) {
        self.isServer = isServer
        self.session = session
        super.init()
        session.delegate = self
    }
}

extension GameManager: MCSessionDelegate {
    enum Message: Int, Codable {
        case hostSettingUpGame
        case worldMapData
        case sendShipInfo
        case shoot
        case win
    }
    
    struct EncapsulatedMessage: Codable {
        let message: Message
        let data: Data?
    }
    
    struct EncapsulatedWorldMap: Codable {
        let worldMapData: Data
        let gameBoardData: Data
    }
    
    func sendToAllPeers(_ data: Data, type: Message) {
        do {
            try session.send(try JSONEncoder().encode(EncapsulatedMessage(message: type, data: data)), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("error sending data to peers: \(error.localizedDescription)")
        }
    }
    
    func send(message: Message) {
        do {
            try session.send(try JSONEncoder().encode(EncapsulatedMessage(message: message, data: nil)), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("error sending data to peers: \(error.localizedDescription)")
        }
    }
    
    func received(message: EncapsulatedMessage) {
        if message.message == .sendShipInfo {
            if let board = try? JSONDecoder().decode(BattleshipBoard.self, from: message.data!) {
                delegate?.update(board: board)
            }
        } else if message.message == .shoot {
            if let coordinates = try? JSONDecoder().decode(CGPoint.self, from: message.data!) {
                delegate?.shoot(x: Int(round(coordinates.x)), y: Int(round(coordinates.y)))
            }
        } else if message.message == .win {
            delegate?.lose()
        }
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        print("Peer \(peerID.displayName) changed state: \(state.rawValue)")
        if (state == .connected && isServer && gameState == .setup) {
            send(message: .hostSettingUpGame)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if let message = try? JSONDecoder().decode(EncapsulatedMessage.self, from: data) {
            received(message: message)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
}

protocol GameManagerDelegate: class {
    func update(board: BattleshipBoard)
    func shoot(x: Int, y: Int)
    func lose()
}
