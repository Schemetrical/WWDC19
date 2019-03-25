//
//  ViewController.swift
//  BattleshipAR
//
//  Created by Yichen Cao on 2019-03-16.
//  Copyright © 2019 Yichen Cao. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity
import AVFoundation

public class ViewController: UIViewController {
    
    // Host:
    // 1. Looking for surface
    // 2. Placing Board
    // 3. Setup Level (send board over), place ship
    // 4. Game in Progress
    
    // Client:
    // 1. Localizing to board
    // 2. Setup Level
    // 3. Game in Progress
    
    enum SessionState {
        case setup
        case lookingForSurface
        case placingBoard
        case localizingToBoard
        case setupLevel
        case waitingForReady
        case myTurn
        case notMyTurn
        case win
        case lose
        
        var localizedInstruction: String? {
            switch self {
            case .lookingForSurface:
                return NSLocalizedString("Find a flat surface to place the game.", comment: "")
            case .placingBoard:
                return NSLocalizedString("Scale, rotate or move the board. Tap to continue.", comment: "")
            case .myTurn:
                return NSLocalizedString("Your turn. Tap on where you think the enemy's ships are.", comment: "")
            case .notMyTurn:
                return NSLocalizedString("Waiting on enemy to shoot at your ships.", comment: "")
            case .win:
                return NSLocalizedString("You win!", comment: "")
            case .lose:
                return NSLocalizedString("You lose :( better luck next time.", comment: "")
            case .waitingForReady:
                return NSLocalizedString("Waiting for enemy to place their ships.", comment: "")
            case .setupLevel:
                return NSLocalizedString("Place your 5 ships. Tap on the starting grid and drag in the direction of the ship", comment: "")
            case .localizingToBoard:
                return NSLocalizedString("Synchronizing world map, please point the camera towards the game surface. It will be faster if you have the same view as the host.", comment: "")
            case .setup:
                return nil
            }
        }
    }
    
    var sceneView: ARSCNView!
    var gameBoard: GameBoard?
    
    var infoLabel: UILabel!
    var panOffset = float3()
    var planeNode: SCNNode?
    var startingCoordinate: (x: Int, z: Int)?
    
    var enemyReady = false
    
    var splooshPlayer: AVAudioPlayer?
    var kaboomPlayer: AVAudioPlayer?
    
    var sessionState: SessionState = .setup {
        didSet {
            guard oldValue != sessionState else { return }
            DispatchQueue.main.async {
                self.infoLabel.text = self.sessionState.localizedInstruction
            }
            if sessionState == .placingBoard {
                gameBoard?.addTextToScene()
                DispatchQueue.main.async {
                    self.view.isMultipleTouchEnabled = true
                }
            }
            if sessionState == .setupLevel && gameManager!.isServer {
                sceneView.session.getCurrentWorldMap { worldMap, error in
                    guard let map = worldMap
                        else { print("Error: \(error!.localizedDescription)"); return }
                    guard let worldMapData = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                        else { fatalError("can't encode map") }
                    guard let gameBoard = self.gameBoard
                        else { fatalError("no game board!") }
                    guard let gameBoardData = try? NSKeyedArchiver.archivedData(withRootObject: gameBoard, requiringSecureCoding: true) else { fatalError("can't encode map") }
                    do {
                        self.gameManager?.sendToAllPeers(try JSONEncoder().encode(GameManager.EncapsulatedWorldMap(worldMapData: worldMapData, gameBoardData: gameBoardData)), type: .worldMapData)
                    } catch {
                        print("error encoding world map data: \(error.localizedDescription)")
                    }
                }
            }
            
            if sessionState == .setupLevel {
                gameBoard?.removeTextFromScene()
                gameBoard?.currentBoard = BattleshipBoard()
                gameBoard?.showBoards()
                DispatchQueue.main.async {
                    self.view.isMultipleTouchEnabled = false
                }
            } else if sessionState == .waitingForReady {
                gameBoard?.removeTextFromScene()
                if let board = gameBoard?.currentBoard, let data = try? JSONEncoder().encode(board) {
                    gameManager?.sendToAllPeers(data, type: .sendShipInfo)
                } else {
                    print("No board to send??")
                }
                gameBoard?.showEnemyBoards()
                if enemyReady {
                    enemyReady = false
                    sessionState = gameManager!.isServer ? .myTurn : .notMyTurn
                }
            } else if sessionState == .myTurn {
                gameManager?.gameState = .myTurn
            } else if sessionState == .notMyTurn {
                gameManager?.gameState = .enemyTurn
            } else if sessionState == .win {
                gameManager?.send(message: .win)
            } else if sessionState == .lose {
                gameBoard?.shipSinkCount = [0, 0, 0, 0, 0]
                gameBoard?.shouldUpdateBattleshipBoard = true
            }
        }
    }
    
    var gameManager: GameManager? {
        didSet {
            guard let manager = gameManager else {
                sessionState = .setup
                return
            }
            
            if !manager.isServer {
                sessionState = .localizingToBoard
            } else {
                sessionState = .lookingForSurface
            }
            manager.delegate = self
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        
        // MARK: DEBUG
        //        becomeHost(session: MCSession(peer: MCPeerID(displayName: "test")))
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Set the scene to the view
        sceneView.scene = SCNScene()
        
        [UITapGestureRecognizer(target: self, action: #selector(handleTap(_:))), ThresholdPanGestureRecognizer(target: self, action: #selector(handlePan(_:))), ThresholdPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:))), ThresholdRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))].forEach { (gr) in
            sceneView.addGestureRecognizer(gr)
            gr.delegate = self
        }
        
        guard let splooshURL = Bundle.main.url(forResource: "sploosh", withExtension: "aifc"), let kaboomURL =  Bundle.main.url(forResource: "kaboom", withExtension: "aifc") else { return }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            splooshPlayer = try AVAudioPlayer(contentsOf: splooshURL, fileTypeHint: AVFileType.aifc.rawValue)
            kaboomPlayer = try AVAudioPlayer(contentsOf: kaboomURL, fileTypeHint: AVFileType.aifc.rawValue)
            
        } catch let error {
            print(error.localizedDescription)
        }
        
    }
    
    func setupView() {
        sceneView = ARSCNView()
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sceneView)
        sceneView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        sceneView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        sceneView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        sceneView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        infoLabel = UILabel()
        infoLabel.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.font = UIFont.systemFont(ofSize: 17)
        infoLabel.text = "Initializing AR session."
        infoLabel.numberOfLines = 0
        infoLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 300).isActive = true
        infoLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 22).isActive = true
        
        let vev = UIVisualEffectView()
        vev.effect = UIBlurEffect(style: .light)
        vev.translatesAutoresizingMaskIntoConstraints = false
        vev.layer.cornerRadius = 7
        vev.clipsToBounds = true
        vev.contentView.addSubview(infoLabel)
        infoLabel.topAnchor.constraint(equalTo: vev.topAnchor, constant: 8).isActive = true
        vev.bottomAnchor.constraint(equalTo: infoLabel.bottomAnchor, constant: 8).isActive = true
        infoLabel.leadingAnchor.constraint(equalTo: vev.leadingAnchor, constant: 8).isActive = true
        vev.trailingAnchor.constraint(equalTo: infoLabel.trailingAnchor, constant: 14).isActive = true
        
        view.addSubview(vev)
        vev.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20).isActive = true
        vev.leftAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leftAnchor, constant: 16).isActive = true
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        if sessionState == .setup {
            let introVC = IntroViewController()
            introVC.modalTransitionStyle = .crossDissolve
            introVC.delegate = self
            present(introVC, animated: false, completion: nil)
        }
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
}

extension ViewController: IntroViewControllerDelegate {
    func becomeHost(session: MCSession) {
        gameManager = GameManager(isServer: true, session: session)
        gameManager?.delegate = self
        sessionState = .lookingForSurface
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.autoenablesDefaultLighting = true
        sceneView.session.run(configuration)
    }
    
    func becomePeer(session: MCSession, worldMap: ARWorldMap, gameBoard: GameBoard) {
        print("World map and game board received")
        gameManager = GameManager(isServer: false, session: session)
        gameManager?.delegate = self
        self.gameBoard = gameBoard
        gameBoard.eulerAngles.y += .pi
        sessionState = .localizingToBoard
        let configuration = ARWorldTrackingConfiguration()
        //        configuration.planeDetection = .horizontal
        configuration.initialWorldMap = worldMap
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

extension ViewController: ARSCNViewDelegate {
    
    // MARK: - ARSCNViewDelegate
    
    // Override to create and configure nodes for anchors added to the view's session.
    //    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    //
    //        return SCNNode()
    //    }
    
    public func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard sessionState == .lookingForSurface || sessionState == .localizingToBoard else {
            return
        }
        if anchor is ARPlaneAnchor {
            planeNode = node
            if sessionState == .lookingForSurface {
                gameBoard = GameBoard()
                node.addChildNode(gameBoard!)
                sessionState = .placingBoard
                
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = []
                sceneView.session.run(configuration)
            } else if sessionState == .localizingToBoard {
                print(node)
                if let gameBoard = gameBoard {
                    node.addChildNode(gameBoard)
                    sessionState = .setupLevel
                } else {
                    print("Error: game board not found")
                }
            }
        }
        
    }
    
    public func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    public func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    public func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    public func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        gameBoard?.updateNodes()
    }
}


extension ViewController: GameManagerDelegate {
    func lose() {
        sessionState = .lose
    }
    
    func shoot(x: Int, y: Int) {
        gameBoard?.currentBoard?.bombedBoard[x][y] = true
        if sessionState != .lose || sessionState == .win {
            sessionState = .myTurn
        }
    }
    
    func update(board: BattleshipBoard) {
        gameBoard?.enemyBoard = board
        for shipIndex in 0..<board.placedShips.count {
            let shipPosition = board.placedShips[shipIndex]
            gameBoard?.shipSinkCount[shipIndex] = shipPosition.ship.length
            if shipPosition.horizontal {
                for x in 0..<shipPosition.ship.length {
                    gameBoard?.enemyShipMatrix[shipPosition.x + x][shipPosition.y] = shipIndex + 1
                }
            } else {
                for y in 0..<shipPosition.ship.length {
                    gameBoard?.enemyShipMatrix[shipPosition.x][shipPosition.y + y] = shipIndex + 1
                }
            }
        }
        if sessionState == .waitingForReady {
            sessionState = gameManager!.isServer ? .myTurn : .notMyTurn
        } else {
            enemyReady = true
        }
    }
}


