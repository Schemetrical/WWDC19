//
//  BattleshipBoard.swift
//  BattleshipAR
//
//  Created by Yichen Cao on 2019-03-20.
//  Copyright © 2019 Yichen Cao. All rights reserved.
//

import Foundation

struct BattleshipBoard: Codable {
    static let size = 10 // length and width
    static let allShips = [Ship(name: "Carrier", length: 5), Ship(name: "Battleship", length: 4), Ship(name: "Cruiser", length: 3), Ship(name: "Submarine", length: 3), Ship(name: "Destroyer", length: 2)]
    var bombedBoard = Array(repeating: Array(repeating: false, count: size), count: size)
    var placedShips = [PositionedShip]()
}

struct PositionedShip: Codable {
    let ship: Ship
    var x: Int
    var y: Int
    var horizontal: Bool
}

struct Ship: Codable {
    let name: String
    let length: Int
}
