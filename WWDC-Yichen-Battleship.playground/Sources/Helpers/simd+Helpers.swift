/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Convenience extensions for SIMD vector and matrix types.
*/

import Foundation
import simd
import SceneKit

extension float4 {
    static let zero = float4(0.0)
    
    var xyz: float3 {
        get {
            return float3(x, y, z)
        }
        set {
            x = newValue.x
            y = newValue.y
            z = newValue.z
        }
    }
    
    init(_ xyz: float3, _ w: Float) {
        self.init(xyz.x, xyz.y, xyz.z, w)
    }
}
