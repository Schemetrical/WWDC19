//
//  ViewController+Gestures.swift
//  BattleshipAR
//
//  Created by Yichen Cao on 2019-03-16.
//  Copyright © 2019 Yichen Cao. All rights reserved.
//

import UIKit
import SceneKit

extension ViewController: UIGestureRecognizerDelegate {
    
    // MARK: - UI Gestures and Touches
    @IBAction func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }
        
        switch sessionState {
        case .placingBoard:
            sessionState = .setupLevel
        case .myTurn:
            let location = gesture.location(in: sceneView)
            let results = sceneView.hitTest(location, options: nil)
            guard let nearestPlane = (results.filter { $0.node.name == "enemySlot" }.first) else {
                return
            }
            let coordinate = gameBoard!.enemyCoordinateAt(position: nearestPlane.node.position)
            if gameBoard?.enemyBoard?.bombedBoard[coordinate.x][coordinate.z] == false {
                if let shipIndex = gameBoard?.enemyShipMatrix[coordinate.x][coordinate.z], shipIndex != 0 {
                    // KABOOM
                    kaboomPlayer?.play()
                    gameBoard?.shipSinkCount[shipIndex - 1] -= 1
                    if gameBoard?.shipSinkCount.reduce(true, { $0 && $1 == 0 }) ?? false {
                        sessionState = .win
                    }
                } else {
                    // Sploosh
                    splooshPlayer?.play()
                }
                gameBoard?.enemyBoard?.bombedBoard[coordinate.x][coordinate.z] = true
                if let data = try? JSONEncoder().encode(CGPoint(x: coordinate.x, y: coordinate.z)) {
                    gameManager?.sendToAllPeers(data, type: .shoot)
                }
                if sessionState != .win {
                    sessionState = .notMyTurn
                }
            }
        default:
            break
        }
    }
    
    @IBAction func handlePinch(_ gesture: ThresholdPinchGestureRecognizer) {
        guard sessionState == .placingBoard, let gameBoard = gameBoard else { return }
        
        switch gesture.state {
        case .changed where gesture.isThresholdExceeded:
            gameBoard.scale(by: Float(gesture.scale))
            gesture.scale = 1
        default:
            break
        }
    }
    
    @IBAction func handleRotation(_ gesture: ThresholdRotationGestureRecognizer) {
        guard sessionState == .placingBoard, let gameBoard = gameBoard else { return }
        
        switch gesture.state {
        case .changed where gesture.isThresholdExceeded:
            if gameBoard.eulerAngles.x > .pi / 2 {
                gameBoard.simdEulerAngles.y += Float(gesture.rotation)
            } else {
                gameBoard.simdEulerAngles.y -= Float(gesture.rotation)
            }
            gesture.rotation = 0
        default:
            break
        }
    }
    
    @IBAction func handlePan(_ gesture: ThresholdPanGestureRecognizer) {
        if sessionState == .placingBoard, let gameBoard = gameBoard {
            let location = gesture.location(in: sceneView)
            let results = sceneView.hitTest(location, types: .existingPlane)
            guard let nearestPlane = results.first else {
                return
            }
            
            switch gesture.state {
            case .began:
                panOffset = nearestPlane.worldTransform.columns.3.xyz - gameBoard.simdWorldPosition
            case .changed:
                gameBoard.simdWorldPosition = nearestPlane.worldTransform.columns.3.xyz - panOffset
            default:
                break
            }
        } else if sessionState == .setupLevel, let gameBoard = gameBoard {
            if gesture.state == .began {
                let location = gesture.location(in: sceneView)
                let results = sceneView.hitTest(location, options: nil)
                guard let nearestPlane = (results.filter { $0.node.name == "boardSlot" }.first) else {
                    return
                }
                startingCoordinate = gameBoard.coordinateAt(position: nearestPlane.node.position)
                let ship = BattleshipBoard.allShips[gameBoard.currentBoard!.placedShips.count]

                if startingCoordinate!.x > 4 && startingCoordinate!.z > 4 {
                    gameBoard.currentBoard!.placedShips.append(PositionedShip(ship: ship, x: startingCoordinate!.x - ship.length + 1, y: startingCoordinate!.z, horizontal: true))
                } else if startingCoordinate!.x > 4 {
                    gameBoard.currentBoard!.placedShips.append(PositionedShip(ship: ship, x: startingCoordinate!.x , y: startingCoordinate!.z, horizontal: false))
                } else {
                    gameBoard.currentBoard!.placedShips.append(PositionedShip(ship: ship, x: startingCoordinate!.x , y: startingCoordinate!.z, horizontal: true))
                }
               
            }
            if gesture.state == .changed {
                guard let startingCoordinate = startingCoordinate else {
                    return
                }
                let location = gesture.location(in: sceneView)
                let results = sceneView.hitTest(location, options: nil)
                guard let nearestPlane = (results.filter { $0.node.name == "boardSlot" }.first) else {
                    return
                }
                guard let lastPlacedShip = gameBoard.currentBoard!.placedShips.last else {
                    return
                }
                let newCoordinate = gameBoard.coordinateAt(position: nearestPlane.node.position)
                let dx = newCoordinate.x - startingCoordinate.x
                let dz = newCoordinate.z - startingCoordinate.z
                if dx == 0 && dz == 0  {
                    return
                }
                // Spaghetti code to get ship positioning without landing outside the board
                let horizontal = dz == 0 ? true : (abs(Float(dx) / Float(dz)) > 1)
                if horizontal {
                    if dx < 0 {
                        if startingCoordinate.x - lastPlacedShip.ship.length < -1 {
                            return
                        }
                        gameBoard.currentBoard!.placedShips[gameBoard.currentBoard!.placedShips.count - 1] = PositionedShip(ship: lastPlacedShip.ship, x: startingCoordinate.x - lastPlacedShip.ship.length + 1, y: startingCoordinate.z, horizontal: horizontal)
                    } else {
                        if startingCoordinate.x + lastPlacedShip.ship.length > BattleshipBoard.size {
                            return
                        }
                        gameBoard.currentBoard!.placedShips[gameBoard.currentBoard!.placedShips.count - 1] = PositionedShip(ship: lastPlacedShip.ship, x: startingCoordinate.x, y: startingCoordinate.z, horizontal: horizontal)
                    }
                } else {
                    if dz < 0 {
                        if startingCoordinate.z - lastPlacedShip.ship.length < -1 {
                            return
                        }
                        gameBoard.currentBoard!.placedShips[gameBoard.currentBoard!.placedShips.count - 1] = PositionedShip(ship: lastPlacedShip.ship, x: startingCoordinate.x, y: startingCoordinate.z - lastPlacedShip.ship.length + 1, horizontal: horizontal)
                    } else {
                        if startingCoordinate.z + lastPlacedShip.ship.length > BattleshipBoard.size {
                            return
                        }
                        gameBoard.currentBoard!.placedShips[gameBoard.currentBoard!.placedShips.count - 1] = PositionedShip(ship: lastPlacedShip.ship, x: startingCoordinate.x, y: startingCoordinate.z, horizontal: horizontal)
                    }
                }
                
                // What's missing here is a way to prevent ships from overlapping.
            }
            if gesture.state == .ended || gesture.state == .cancelled {
                startingCoordinate = nil
                if gameBoard.currentBoard!.placedShips.count == BattleshipBoard.allShips.count {
                    sessionState = .waitingForReady
                }
            }
            if gesture.state == .failed {
                if startingCoordinate != nil {
                    gameBoard.currentBoard!.placedShips.removeLast()
                    startingCoordinate = nil
                }
            }
        }
        
    }
    
    private func gestureRecognizer(_ first: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith second: UIGestureRecognizer) -> Bool {
        if first is UIRotationGestureRecognizer && second is UIPinchGestureRecognizer {
            return true
        } else if first is UIRotationGestureRecognizer && second is UIPanGestureRecognizer {
            return true
        } else if first is UIPinchGestureRecognizer && second is UIRotationGestureRecognizer {
            return true
        } else if first is UIPinchGestureRecognizer && second is UIPanGestureRecognizer {
            return true
        } else if first is UIPanGestureRecognizer && second is UIPinchGestureRecognizer {
            return true
        } else if first is UIPanGestureRecognizer && second is UIRotationGestureRecognizer {
            return true
        }
        return false
    }
}
