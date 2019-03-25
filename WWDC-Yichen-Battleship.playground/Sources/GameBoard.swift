//
//  GameBoard.swift
//  BattleshipAR
//
//  Created by Yichen Cao on 2019-03-16.
//  Copyright © 2019 Yichen Cao. All rights reserved.
//

import Foundation
import ARKit

class GameBoard: SCNNode {
    static let minimumScale: Float = 0.25
    static let maximumScale: Float = 3.0
    static let borderColor = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
    
    var preferredSize: CGSize = CGSize(width: 0.3, height: 0.6)
    private let slotLength = 0.3 / CGFloat(BattleshipBoard.size)
    var queuedNodes = [SCNNode]()
    var nodesToRemove = [SCNNode]()
    var shouldUpdateBattleshipBoard = false
    var inverted = false
    var currentBoard: BattleshipBoard? {
        didSet {
            shouldUpdateBattleshipBoard = true
        }
    }
    var enemyBoard: BattleshipBoard? {
        didSet {
            shouldUpdateBattleshipBoard = true
        }
    }
    var enemyShipMatrix = Array(repeating: Array(repeating: 0, count: BattleshipBoard.size), count: BattleshipBoard.size)
    var shipSinkCount = Array(repeating: 0, count: BattleshipBoard.allShips.count)
    var battleshipBoardNodes = [SCNNode]()
    
    override init() {
        super.init()
        // Create fill plane
        queuedNodes.append(fillPlane)
    }
    
    required init?(coder aDecoder: NSCoder) {
        inverted = true
        super.init(coder: aDecoder)
    }
    
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
    }
    
    override static var supportsSecureCoding: Bool {
        return true
    }
    
    private lazy var boardSlots = Array(count: BattleshipBoard.size, elementCreator: Array(count: BattleshipBoard.size, elementCreator:createSlot(enemy: false)))
    
    private lazy var enemySlots = Array(count: BattleshipBoard.size, elementCreator: Array(count: BattleshipBoard.size, elementCreator:createSlot(enemy: true)))
    
    private var gameElementNodes = [SCNNode]()
    private lazy var textNodes: [SCNNode] = {
        let youText = SCNText(string: "YOU", extrusionDepth: 0.01)
        youText.font = UIFont.systemFont(ofSize: 0.1, weight: .heavy)
        youText.firstMaterial?.diffuse.contents = UIColor.gray
        let youTextNode = SCNNode(geometry: youText)
        youTextNode.position.z += Float(preferredSize.width)
        youTextNode.position.x -= (youTextNode.boundingBox.max.x - youTextNode.boundingBox.min.x) / 2
        youTextNode.position.y -= 1
//        youTextNode.eulerAngles.x = .pi / 2
        
        let themText = SCNText(string: "ENEMY", extrusionDepth: 0.01)
        themText.font = UIFont.systemFont(ofSize: 0.1, weight: .heavy)
        themText.firstMaterial?.diffuse.contents = UIColor.red
        let themTextNode = SCNNode(geometry: themText)
        themTextNode.eulerAngles.y = .pi
        themTextNode.position.z -= Float(preferredSize.width)
        themTextNode.position.x += (themTextNode.boundingBox.max.x - themTextNode.boundingBox.min.x) / 2
        themTextNode.position.y -= 1
//        youTextNode.eulerAngles.x = .pi / 2
        return [youTextNode, themTextNode]
    }()

    private lazy var fillPlane: SCNNode = {
        let plane = SCNPlane(width: preferredSize.width, height: preferredSize.height)
        let node = SCNNode(geometry: plane)
        node.name = "fillPlane"
        node.opacity = 0.6
        node.eulerAngles.x = .pi/2
        
        let material = plane.firstMaterial!
//        material.diffuse.contents = UIImage(named: "gameassets.scnassets/textures/grid.png")
//        let textureScale = float4x4(scale: float3(40, 40 * aspectRatio, 1))
//        material.diffuse.simdContentsTransform = textureScale
//        material.emission.contents = UIImage(named: "gameassets.scnassets/textures/grid.png")
//        material.emission.simdContentsTransform = textureScale
//        material.diffuse.wrapS = .repeat
//        material.diffuse.wrapT = .repeat
        material.isDoubleSided = true
        material.ambient.contents = UIColor.black
        material.lightingModel = .constant
        
        return node
    }()
    
    func updateNodes() {
        nodesToRemove.forEach { $0.removeFromParentNode() }
        nodesToRemove.removeAll()
        queuedNodes.forEach(addChildNode)
        queuedNodes.removeAll()
        if shouldUpdateBattleshipBoard, let currentBoard = currentBoard {
            battleshipBoardNodes.forEach { $0.removeFromParentNode() }
            battleshipBoardNodes.removeAll()
            shouldUpdateBattleshipBoard = false
            for x in 0..<currentBoard.bombedBoard.count {
                for z in 0..<currentBoard.bombedBoard[x].count {
                    guard currentBoard.bombedBoard[x][z] else {
                        continue
                    }
                    let node = createBomb()
                    node.position = positionAtCoordinate(x: x, z: z, offset: 0.02)
                    battleshipBoardNodes.append(node)
                }
            }
            for positionedShip in currentBoard.placedShips {
                let node = createShip(width: positionedShip.horizontal ? positionedShip.ship.length : 1, height: positionedShip.horizontal ? 1 : positionedShip.ship.length)
                node.position = positionAtCoordinate(x: positionedShip.x, z: positionedShip.y, offset: 0.015)
                if positionedShip.horizontal {
                    node.position.x += (Float(positionedShip.ship.length) * Float(slotLength) - Float(slotLength)) / 2
                } else {
                    node.position.z += (Float(positionedShip.ship.length) * Float(slotLength) - Float(slotLength)) / 2
                }
                battleshipBoardNodes.append(node)
            }
            if let enemyBoard = enemyBoard {
                for x in 0..<enemyBoard.bombedBoard.count {
                    for z in 0..<enemyBoard.bombedBoard[x].count {
                        guard enemyBoard.bombedBoard[x][z] else {
                            continue
                        }
                        let node = createBomb()
                        node.position = enemyPositionAtCoordinate(x: x, z: z, offset: 0.02)
                        if enemyShipMatrix[x][z] != 0 {
                            node.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.9334570313, green: 0, blue: 0.02595535536, alpha: 1)
                        }
                        battleshipBoardNodes.append(node)
                    }
                }
                for shipIndex in 0..<shipSinkCount.count {
                    if shipSinkCount[shipIndex] == 0 {
                        // Ship is sunk, reveal
                        let positionedShip = enemyBoard.placedShips[shipIndex]
                        let node = createShip(width: positionedShip.horizontal ? positionedShip.ship.length : 1, height: positionedShip.horizontal ? 1 : positionedShip.ship.length)
                        node.position = enemyPositionAtCoordinate(x: positionedShip.x, z: positionedShip.y, offset: 0.015)
                        if positionedShip.horizontal {
                            node.position.x -= (Float(positionedShip.ship.length) * Float(slotLength) - Float(slotLength)) / 2
                        } else {
                            node.position.z -= (Float(positionedShip.ship.length) * Float(slotLength) - Float(slotLength)) / 2
                        }
                        node.geometry?.firstMaterial?.diffuse.contents = #colorLiteral(red: 0.521568656, green: 0.1098039225, blue: 0.05098039284, alpha: 1)
                        battleshipBoardNodes.append(node)
                    }
                }
            }
            battleshipBoardNodes.forEach(addChildNode)
        }
    }
    
    func showBoards() {
        var nodes = [SCNNode]()
        for x in 0..<BattleshipBoard.size {
            for z in 0..<BattleshipBoard.size {
                let node = boardSlots[x][z]
                node.position = positionAtCoordinate(x: x, z: z, offset: 0.01)
                nodes.append(node)
            }
        }
        queuedNodes += nodes
    }
    
    func showEnemyBoards() {
        var nodes = [SCNNode]()
        for x in 0..<BattleshipBoard.size {
            for z in 0..<BattleshipBoard.size {
                let node = enemySlots[x][z]
                node.position = enemyPositionAtCoordinate(x: x, z: z, offset: 0.01)
                nodes.append(node)
            }
        }
        queuedNodes += nodes
    }
    
    func addTextToScene() {
        queuedNodes += textNodes
    }
    
    func removeTextFromScene() {
        nodesToRemove += textNodes
    }
    
    func positionAtCoordinate(x: Int, z: Int, offset: CGFloat) -> SCNVector3 {
        let halfLength = slotLength / 2
        return SCNVector3(CGFloat(x) * slotLength - preferredSize.width / 2 + halfLength, offset, CGFloat(z) * slotLength + halfLength)
    }
    
    func enemyPositionAtCoordinate(x: Int, z: Int, offset: CGFloat) -> SCNVector3 {
        let halfLength = slotLength / 2
        return SCNVector3(preferredSize.width / 2 - halfLength - CGFloat(x) * slotLength, offset, -halfLength - CGFloat(z) * slotLength)
    }
    
    func coordinateAt(position: SCNVector3) -> (x: Int, z: Int) {
        let halfLength = slotLength / 2
        return (x: Int(round((CGFloat(position.x) + preferredSize.width / 2 - halfLength) / slotLength)), z: Int(round((CGFloat(position.z) - halfLength) / slotLength)))
    }
    
    func enemyCoordinateAt(position: SCNVector3) -> (x: Int, z: Int) {
        let halfLength = slotLength / 2
        return (x: -Int(round((CGFloat(position.x) - preferredSize.width / 2 + halfLength) / slotLength)), z: -Int(round((CGFloat(position.z) + halfLength) / slotLength)))
    }
    
    func createSlot(enemy: Bool) -> SCNNode {
        let plane = SCNPlane(width: preferredSize.width / CGFloat(BattleshipBoard.size), height: preferredSize.width / CGFloat(BattleshipBoard.size))
        plane.cornerRadius = 0.003
        let node = SCNNode(geometry: plane)
        node.name = enemy ? "enemySlot" : "boardSlot"
        node.eulerAngles.x = .pi / 2
        node.scale = SCNVector3(0.9, 0.9, 0.9)
//        node.opacity = 0.5
        
        let material = plane.firstMaterial!
        material.isDoubleSided = true
        material.diffuse.contents = enemy ? #colorLiteral(red: 0.9411764741, green: 0.4980392158, blue: 0.3529411852, alpha: 1) : #colorLiteral(red: 0.2588235438, green: 0.7568627596, blue: 0.9686274529, alpha: 1)
//        material.lightingModel = .blinn
        return node
    }
    
    func createBomb() -> SCNNode {
        let plane = SCNPlane(width: preferredSize.width / CGFloat(BattleshipBoard.size), height: preferredSize.width / CGFloat(BattleshipBoard.size))
        plane.cornerRadius = plane.width / 2
        let node = SCNNode(geometry: plane)
        node.name = "bomb"
        node.eulerAngles.x = .pi / 2
        node.scale = SCNVector3(0.6, 0.6, 0.6)
        
        let material = plane.firstMaterial!
        material.isDoubleSided = true
        material.diffuse.contents = #colorLiteral(red: 0.2549019754, green: 0.2745098174, blue: 0.3019607961, alpha: 1)
        material.lightingModel = .blinn
        return node
    }
    
    func createShip(width: Int, height: Int) -> SCNNode {
        let plane = SCNPlane(width: preferredSize.width / CGFloat(BattleshipBoard.size) * CGFloat(width) - 0.005, height: preferredSize.width / CGFloat(BattleshipBoard.size) * CGFloat(height) - 0.005)
        plane.cornerRadius = 0.01
        let node = SCNNode(geometry: plane)
        node.name = "ship"
        node.eulerAngles.x = .pi / 2
        
        let material = plane.firstMaterial!
        material.isDoubleSided = true
        material.diffuse.contents = #colorLiteral(red: 0.1452498747, green: 0.9554882812, blue: 0, alpha: 1)
        material.lightingModel = .blinn
        return node
    }
    
    func scale(by factor: Float) {
        // assumes we always scale the same in all 3 dimensions
        let currentScale = simdScale.x
        let newScale = clamp(currentScale * factor, GameBoard.minimumScale, GameBoard.maximumScale)
        simdScale = float3(newScale)
    }
    
    public func clamp<T>(_ value: T, _ minValue: T, _ maxValue: T) -> T where T: Comparable {
        return min(max(value, minValue), maxValue)
    }
    
}

extension Array {
    // Non referencing population of an array :)
    public init(count: Int, elementCreator: @autoclosure () -> Element) {
        self = (0 ..< count).map { _ in elementCreator() }
    }
}
