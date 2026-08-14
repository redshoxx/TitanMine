import SwiftUI
import SceneKit
import UIKit

/// Native SceneKit battlefield. Everything in this view is real 3D geometry with
/// perspective, PBR materials, dynamic lights, camera depth, continuous animation
/// and impact VFX. No flat Canvas drawing is used for the boss anymore.
struct Boss3DScene: UIViewRepresentable {
    let hitToken: Int
    let criticalHit: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        context.coordinator.controller.makeView()
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        guard context.coordinator.lastHitToken != hitToken else { return }
        context.coordinator.lastHitToken = hitToken
        if hitToken > 0 {
            context.coordinator.controller.triggerHit(critical: criticalHit)
        }
    }

    final class Coordinator {
        let controller = BossSceneController()
        var lastHitToken = 0
    }
}

private final class BossSceneController {
    private let scene = SCNScene()
    private let bossRoot = SCNNode()
    private let cameraNode = SCNNode()
    private let impactPoint = SCNVector3(1.25, 4.15, 0.55)
    private var crystalNodes: [SCNNode] = []

    func makeView() -> SCNView {
        buildScene()

        let view = SCNView(frame: .zero, options: [SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue])
        view.scene = scene
        view.backgroundColor = UIColor(red: 0.015, green: 0.11, blue: 0.20, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.isPlaying = true
        view.rendersContinuously = true
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = false
        return view
    }

    func triggerHit(critical: Bool) {
        let strength: CGFloat = critical ? 1.0 : 0.55

        let knock = SCNAction.sequence([
            .moveBy(x: 0.12 * strength, y: 0.02, z: -0.08 * strength, duration: 0.045),
            .moveBy(x: -0.22 * strength, y: 0.03, z: 0.15 * strength, duration: 0.055),
            .moveBy(x: 0.10 * strength, y: -0.05, z: -0.07 * strength, duration: 0.075)
        ])
        bossRoot.runAction(knock, forKey: "impactKnock")

        let shake = SCNAction.sequence([
            .moveBy(x: 0.10 * strength, y: 0.04 * strength, z: 0, duration: 0.035),
            .moveBy(x: -0.19 * strength, y: -0.07 * strength, z: 0, duration: 0.040),
            .moveBy(x: 0.12 * strength, y: 0.05 * strength, z: 0, duration: 0.040),
            .moveBy(x: -0.03 * strength, y: -0.02 * strength, z: 0, duration: 0.045)
        ])
        cameraNode.runAction(shake, forKey: "cameraShake")

        spawnImpactFlash(critical: critical)
        spawnShockwave(critical: critical)
        spawnFragments(critical: critical)
    }

    private func buildScene() {
        scene.rootNode.childNodes.forEach { $0.removeFromParentNode() }
        crystalNodes.removeAll()

        scene.fogColor = UIColor(red: 0.015, green: 0.13, blue: 0.23, alpha: 1)
        scene.fogStartDistance = 17
        scene.fogEndDistance = 33
        scene.fogDensityExponent = 1.25

        addCamera()
        addLighting()
        addOcean()
        addVoxelIsland()
        addEnvironmentCrystals()
        addBoss()
        addMinerAndBeam()
        startAmbientMotion()
    }

    private func addCamera() {
        let camera = SCNCamera()
        camera.fieldOfView = 47
        camera.zNear = 0.1
        camera.zFar = 80
        camera.wantsHDR = true
        camera.bloomIntensity = 1.35
        camera.bloomThreshold = 0.58
        camera.bloomBlurRadius = 8
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0.0, 7.4, 14.8)

        let focus = SCNNode()
        focus.position = SCNVector3(0.0, 2.5, 0.0)
        scene.rootNode.addChildNode(focus)

        let look = SCNLookAtConstraint(target: focus)
        look.isGimbalLockEnabled = true
        cameraNode.constraints = [look]
        scene.rootNode.addChildNode(cameraNode)
    }

    private func addLighting() {
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(red: 0.22, green: 0.28, blue: 0.38, alpha: 1)
        ambient.intensity = 520
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let sun = SCNLight()
        sun.type = .directional
        sun.color = UIColor(red: 1.0, green: 0.94, blue: 0.82, alpha: 1)
        sun.intensity = 1750
        sun.castsShadow = true
        sun.shadowMode = .deferred
        sun.shadowRadius = 7
        sun.shadowSampleCount = 16
        let sunNode = SCNNode()
        sunNode.light = sun
        sunNode.eulerAngles = SCNVector3(-0.82, -0.55, -0.18)
        scene.rootNode.addChildNode(sunNode)

        let rim = SCNLight()
        rim.type = .omni
        rim.color = UIColor(red: 0.12, green: 0.78, blue: 1.0, alpha: 1)
        rim.intensity = 1250
        rim.attenuationStartDistance = 2
        rim.attenuationEndDistance = 15
        let rimNode = SCNNode()
        rimNode.light = rim
        rimNode.position = SCNVector3(3.5, 6.8, -3.5)
        scene.rootNode.addChildNode(rimNode)

        let warm = SCNLight()
        warm.type = .omni
        warm.color = UIColor(red: 1.0, green: 0.48, blue: 0.12, alpha: 1)
        warm.intensity = 600
        warm.attenuationEndDistance = 11
        let warmNode = SCNNode()
        warmNode.light = warm
        warmNode.position = SCNVector3(-4.0, 2.0, 3.0)
        scene.rootNode.addChildNode(warmNode)
    }

    private func addOcean() {
        let waterMaterial = pbr(
            color: UIColor(red: 0.01, green: 0.30, blue: 0.55, alpha: 0.92),
            metalness: 0.22,
            roughness: 0.18,
            emission: UIColor(red: 0.0, green: 0.10, blue: 0.18, alpha: 1)
        )

        let water = SCNPlane(width: 34, height: 34)
        water.materials = [waterMaterial]
        let waterNode = SCNNode(geometry: water)
        waterNode.eulerAngles.x = -.pi / 2
        waterNode.position.y = -0.20
        scene.rootNode.addChildNode(waterNode)

        for i in 0..<8 {
            let ring = SCNTorus(ringRadius: CGFloat(1.5 + Double(i) * 1.6), pipeRadius: 0.015)
            let mat = emissive(UIColor(red: 0.20, green: 0.78, blue: 1.0, alpha: 0.28), transparency: 0.28)
            ring.materials = [mat]
            let node = SCNNode(geometry: ring)
            node.eulerAngles.x = -.pi / 2
            node.position = SCNVector3(Float(i % 3 - 1) * 2.4, -0.13, Float(i / 3 - 1) * 2.2)
            scene.rootNode.addChildNode(node)

            let pulse = SCNAction.sequence([
                .scale(to: 1.08, duration: 1.6 + Double(i) * 0.06),
                .scale(to: 0.94, duration: 1.6 + Double(i) * 0.06)
            ])
            node.runAction(.repeatForever(pulse))
        }
    }

    private func addVoxelIsland() {
        let rock = pbr(color: UIColor(red: 0.22, green: 0.20, blue: 0.16, alpha: 1), metalness: 0.0, roughness: 0.94)
        let dirt = pbr(color: UIColor(red: 0.31, green: 0.22, blue: 0.11, alpha: 1), metalness: 0.0, roughness: 0.98)
        let grassA = pbr(color: UIColor(red: 0.24, green: 0.62, blue: 0.09, alpha: 1), metalness: 0.0, roughness: 0.86)
        let grassB = pbr(color: UIColor(red: 0.36, green: 0.76, blue: 0.12, alpha: 1), metalness: 0.0, roughness: 0.84)

        let base = SCNBox(width: 11.6, height: 1.55, length: 11.6, chamferRadius: 0.45)
        base.materials = [rock]
        let baseNode = SCNNode(geometry: base)
        baseNode.position.y = 0.32
        scene.rootNode.addChildNode(baseNode)

        let dirtLayer = SCNBox(width: 11.25, height: 0.56, length: 11.25, chamferRadius: 0.30)
        dirtLayer.materials = [dirt]
        let dirtNode = SCNNode(geometry: dirtLayer)
        dirtNode.position.y = 1.02
        scene.rootNode.addChildNode(dirtNode)

        for x in -4...4 {
            for z in -4...4 {
                let height = ((x + z) % 5 == 0) ? 0.20 : 0.14
                let tile = SCNBox(width: 1.18, height: CGFloat(height), length: 1.18, chamferRadius: 0.07)
                tile.materials = [((x + z) % 2 == 0) ? grassA : grassB]
                let tileNode = SCNNode(geometry: tile)
                tileNode.position = SCNVector3(Float(x) * 1.20, 1.34 + Float(height) * 0.5, Float(z) * 1.20)
                scene.rootNode.addChildNode(tileNode)
            }
        }

        for i in 0..<18 {
            let size = CGFloat(0.16 + Double(i % 4) * 0.045)
            let pebble = SCNBox(width: size, height: size * 0.7, length: size * 1.15, chamferRadius: size * 0.12)
            pebble.materials = [rock]
            let n = SCNNode(geometry: pebble)
            let x = Float((i * 37) % 91) / 10.0 - 4.55
            let z = Float((i * 53) % 87) / 10.0 - 4.35
            n.position = SCNVector3(x, 1.55, z)
            n.eulerAngles.y = Float(i) * 0.61
            scene.rootNode.addChildNode(n)
        }
    }

    private func addEnvironmentCrystals() {
        let positions: [SCNVector3] = [
            SCNVector3(-4.1, 1.7, -2.6), SCNVector3(-2.8, 1.6, 1.0),
            SCNVector3(4.0, 1.7, 2.3), SCNVector3(3.7, 1.6, -3.6),
            SCNVector3(-0.8, 1.6, 4.1), SCNVector3(2.4, 1.6, 3.7)
        ]

        for (index, position) in positions.enumerated() {
            let cluster = SCNNode()
            cluster.position = position
            for j in 0..<3 {
                let shard = makeCrystal(height: CGFloat(0.55 + Double((index + j) % 4) * 0.18), tint: j == 0 ? .cyan : .blue)
                shard.position.x = Float(j - 1) * 0.22
                shard.eulerAngles.z = Float(j - 1) * 0.18
                cluster.addChildNode(shard)
                crystalNodes.append(shard)
            }
            scene.rootNode.addChildNode(cluster)
        }
    }

    private func addBoss() {
        bossRoot.position = SCNVector3(1.25, 1.35, -0.82)
        scene.rootNode.addChildNode(bossRoot)

        let stoneA = pbr(color: UIColor(red: 0.31, green: 0.34, blue: 0.36, alpha: 1), metalness: 0.12, roughness: 0.72)
        let stoneB = pbr(color: UIColor(red: 0.19, green: 0.23, blue: 0.26, alpha: 1), metalness: 0.18, roughness: 0.78)
        let dark = pbr(color: UIColor(red: 0.09, green: 0.12, blue: 0.15, alpha: 1), metalness: 0.28, roughness: 0.56)

        let torso = boxNode(width: 3.20, height: 2.75, length: 2.55, radius: 0.32, material: stoneB)
        torso.position = SCNVector3(0, 2.48, 0)
        bossRoot.addChildNode(torso)

        let head = boxNode(width: 3.48, height: 2.35, length: 2.72, radius: 0.38, material: stoneA)
        head.position = SCNVector3(0, 4.55, 0.05)
        bossRoot.addChildNode(head)

        for x: Float in [-0.78, 0.78] {
            let socket = boxNode(width: 0.74, height: 0.46, length: 0.16, radius: 0.08, material: dark)
            socket.position = SCNVector3(x, 4.58, 1.42)
            bossRoot.addChildNode(socket)

            let eyeGeometry = SCNBox(width: 0.52, height: 0.23, length: 0.08, chamferRadius: 0.06)
            eyeGeometry.materials = [emissive(UIColor(red: 0.45, green: 0.96, blue: 1.0, alpha: 1), transparency: 1)]
            let eye = SCNNode(geometry: eyeGeometry)
            eye.position = SCNVector3(x, 4.58, 1.53)
            bossRoot.addChildNode(eye)

            let eyeLight = SCNLight()
            eyeLight.type = .omni
            eyeLight.color = UIColor.cyan
            eyeLight.intensity = 190
            eyeLight.attenuationEndDistance = 3.8
            let eyeLightNode = SCNNode()
            eyeLightNode.light = eyeLight
            eyeLightNode.position = SCNVector3(x, 4.58, 1.62)
            bossRoot.addChildNode(eyeLightNode)
        }

        let leftShoulder = SCNNode()
        leftShoulder.position = SCNVector3(-2.02, 3.55, 0)
        bossRoot.addChildNode(leftShoulder)
        let leftArm = boxNode(width: 1.25, height: 2.85, length: 1.55, radius: 0.28, material: stoneB)
        leftArm.position.y = -0.95
        leftArm.eulerAngles.z = 0.14
        leftShoulder.addChildNode(leftArm)

        let rightShoulder = SCNNode()
        rightShoulder.position = SCNVector3(2.02, 3.55, 0)
        bossRoot.addChildNode(rightShoulder)
        let rightArm = boxNode(width: 1.25, height: 2.85, length: 1.55, radius: 0.28, material: stoneB)
        rightArm.position.y = -0.95
        rightArm.eulerAngles.z = -0.14
        rightShoulder.addChildNode(rightArm)

        for x: Float in [-0.95, 0.95] {
            let leg = boxNode(width: 1.34, height: 1.65, length: 1.75, radius: 0.26, material: dark)
            leg.position = SCNVector3(x, 0.58, 0.05)
            bossRoot.addChildNode(leg)
        }

        let chestCrystal = makeCrystal(height: 1.10, tint: .cyan)
        chestCrystal.position = SCNVector3(0, 2.75, 1.40)
        chestCrystal.eulerAngles.x = 0.18
        bossRoot.addChildNode(chestCrystal)
        crystalNodes.append(chestCrystal)

        let crown = SCNNode()
        crown.position = SCNVector3(0, 5.84, 0)
        bossRoot.addChildNode(crown)
        for i in 0..<7 {
            let h = CGFloat(0.75 + Double((i * 7) % 5) * 0.22)
            let shard = makeCrystal(height: h, tint: i % 3 == 0 ? .white : .cyan)
            let x = Float(i - 3) * 0.42
            shard.position = SCNVector3(x, Float(h) * 0.35, -abs(x) * 0.08)
            shard.eulerAngles.z = x * -0.12
            crown.addChildNode(shard)
            crystalNodes.append(shard)
        }

        for side: Float in [-1, 1] {
            let shoulderCrystal = makeCrystal(height: 0.95, tint: .blue)
            shoulderCrystal.position = SCNVector3(side * 2.05, 4.18, 0.35)
            shoulderCrystal.eulerAngles.z = side * -0.55
            bossRoot.addChildNode(shoulderCrystal)
            crystalNodes.append(shoulderCrystal)
        }

        let breathe = SCNAction.sequence([
            .moveBy(x: 0, y: 0.12, z: 0, duration: 1.15),
            .moveBy(x: 0, y: -0.12, z: 0, duration: 1.15)
        ])
        breathe.timingMode = .easeInEaseOut
        bossRoot.runAction(.repeatForever(breathe), forKey: "bossIdle")

        let leftSwing = SCNAction.sequence([
            .rotateBy(x: 0, y: 0, z: 0.13, duration: 1.25),
            .rotateBy(x: 0, y: 0, z: -0.13, duration: 1.25)
        ])
        leftSwing.timingMode = .easeInEaseOut
        leftShoulder.runAction(.repeatForever(leftSwing))

        let rightSwing = SCNAction.sequence([
            .rotateBy(x: 0, y: 0, z: -0.11, duration: 1.25),
            .rotateBy(x: 0, y: 0, z: 0.11, duration: 1.25)
        ])
        rightSwing.timingMode = .easeInEaseOut
        rightShoulder.runAction(.repeatForever(rightSwing))
    }

    private func addMinerAndBeam() {
        let miner = SCNNode()
        miner.position = SCNVector3(-3.35, 1.55, 3.35)
        miner.eulerAngles.y = 0.42
        scene.rootNode.addChildNode(miner)

        let uniform = pbr(color: UIColor(red: 0.055, green: 0.14, blue: 0.25, alpha: 1), metalness: 0.20, roughness: 0.55)
        let skin = pbr(color: UIColor(red: 0.78, green: 0.49, blue: 0.28, alpha: 1), metalness: 0, roughness: 0.78)
        let helmet = pbr(color: UIColor(red: 0.95, green: 0.58, blue: 0.08, alpha: 1), metalness: 0.22, roughness: 0.45)

        let body = boxNode(width: 0.78, height: 1.05, length: 0.55, radius: 0.10, material: uniform)
        body.position.y = 0.75
        miner.addChildNode(body)

        let head = boxNode(width: 0.62, height: 0.62, length: 0.58, radius: 0.12, material: skin)
        head.position.y = 1.58
        miner.addChildNode(head)

        let hat = boxNode(width: 0.82, height: 0.22, length: 0.72, radius: 0.08, material: helmet)
        hat.position.y = 1.96
        miner.addChildNode(hat)

        let backpack = boxNode(width: 0.65, height: 0.92, length: 0.38, radius: 0.08, material: pbr(color: .brown, metalness: 0.08, roughness: 0.82))
        backpack.position = SCNVector3(0, 0.82, -0.43)
        miner.addChildNode(backpack)

        for x: Float in [-0.22, 0.22] {
            let leg = boxNode(width: 0.25, height: 0.62, length: 0.30, radius: 0.05, material: uniform)
            leg.position = SCNVector3(x, -0.05, 0)
            miner.addChildNode(leg)
        }

        let start = SCNVector3(-2.73, 2.18, 2.86)
        let end = impactPoint

        let outer = cylinderBetween(start: start, end: end, radius: 0.15, material: emissive(UIColor(red: 0.46, green: 0.10, blue: 1.0, alpha: 0.30), transparency: 0.30))
        scene.rootNode.addChildNode(outer)
        let middle = cylinderBetween(start: start, end: end, radius: 0.075, material: emissive(UIColor(red: 0.10, green: 0.82, blue: 1.0, alpha: 0.80), transparency: 0.82))
        scene.rootNode.addChildNode(middle)
        let core = cylinderBetween(start: start, end: end, radius: 0.025, material: emissive(.white, transparency: 1.0))
        scene.rootNode.addChildNode(core)

        let cannon = cylinderBetween(start: SCNVector3(-3.20, 2.05, 3.18), end: SCNVector3(-2.55, 2.35, 2.60), radius: 0.16, material: pbr(color: UIColor(red: 0.27, green: 0.14, blue: 0.48, alpha: 1), metalness: 0.78, roughness: 0.28))
        scene.rootNode.addChildNode(cannon)

        let projectileGeo = SCNSphere(radius: 0.10)
        projectileGeo.segmentCount = 14
        projectileGeo.materials = [emissive(UIColor(red: 1.0, green: 0.78, blue: 0.22, alpha: 1), transparency: 1)]
        let projectile = SCNNode(geometry: projectileGeo)
        projectile.position = start
        scene.rootNode.addChildNode(projectile)

        let fly = SCNAction.move(to: end, duration: 0.52)
        fly.timingMode = .easeInEaseOut
        let reset = SCNAction.run { node in node.position = start }
        projectile.runAction(.repeatForever(.sequence([fly, reset])))

        let recoil = SCNAction.sequence([
            .moveBy(x: 0.03, y: 0, z: 0.03, duration: 0.10),
            .moveBy(x: -0.03, y: 0, z: -0.03, duration: 0.18),
            .wait(duration: 0.24)
        ])
        miner.runAction(.repeatForever(recoil))
    }

    private func startAmbientMotion() {
        for (index, crystal) in crystalNodes.enumerated() {
            let delay = Double(index % 6) * 0.11
            let pulse = SCNAction.sequence([
                .wait(duration: delay),
                .scale(to: 1.09, duration: 0.72),
                .scale(to: 0.94, duration: 0.72),
                .scale(to: 1.0, duration: 0.38)
            ])
            pulse.timingMode = .easeInEaseOut
            crystal.runAction(.repeatForever(pulse))
        }
    }

    private func spawnImpactFlash(critical: Bool) {
        let sphere = SCNSphere(radius: critical ? 0.36 : 0.23)
        sphere.segmentCount = 18
        sphere.materials = [emissive(critical ? UIColor.orange : UIColor.cyan, transparency: 0.95)]
        let flash = SCNNode(geometry: sphere)
        flash.position = impactPoint
        flash.scale = SCNVector3(0.12, 0.12, 0.12)
        scene.rootNode.addChildNode(flash)

        let action = SCNAction.sequence([
            .group([
                .scale(to: critical ? 4.0 : 2.8, duration: 0.16),
                .fadeOut(duration: 0.22)
            ]),
            .removeFromParentNode()
        ])
        flash.runAction(action)
    }

    private func spawnShockwave(critical: Bool) {
        let torus = SCNTorus(ringRadius: critical ? 0.38 : 0.26, pipeRadius: critical ? 0.055 : 0.035)
        torus.ringSegmentCount = 48
        torus.pipeSegmentCount = 12
        torus.materials = [emissive(critical ? UIColor.yellow : UIColor.cyan, transparency: 0.9)]
        let ring = SCNNode(geometry: torus)
        ring.position = impactPoint
        ring.eulerAngles.x = 0.55
        ring.scale = SCNVector3(0.2, 0.2, 0.2)
        scene.rootNode.addChildNode(ring)

        ring.runAction(.sequence([
            .group([
                .scale(to: critical ? 5.2 : 3.4, duration: 0.30),
                .fadeOut(duration: 0.34),
                .rotateBy(x: 0.3, y: 0.5, z: 0.2, duration: 0.34)
            ]),
            .removeFromParentNode()
        ]))
    }

    private func spawnFragments(critical: Bool) {
        let count = critical ? 18 : 10
        for i in 0..<count {
            let s = CGFloat.random(in: 0.07...0.16)
            let geo = SCNBox(width: s, height: s, length: s, chamferRadius: s * 0.12)
            geo.materials = [i % 3 == 0 ? emissive(.cyan, transparency: 0.95) : pbr(color: UIColor(white: 0.55, alpha: 1), metalness: 0.12, roughness: 0.65)]
            let shard = SCNNode(geometry: geo)
            shard.position = impactPoint
            scene.rootNode.addChildNode(shard)

            let dx = CGFloat.random(in: -1.35...1.35)
            let dy = CGFloat.random(in: 0.35...1.75)
            let dz = CGFloat.random(in: -0.65...1.25)
            let duration = Double.random(in: 0.32...0.58)
            shard.runAction(.sequence([
                .group([
                    .moveBy(x: dx, y: dy, z: dz, duration: duration),
                    .rotateBy(x: .random(in: -2...2), y: .random(in: -2...2), z: .random(in: -2...2), duration: duration),
                    .fadeOut(duration: duration)
                ]),
                .removeFromParentNode()
            ]))
        }
    }

    private func boxNode(width: CGFloat, height: CGFloat, length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let geo = SCNBox(width: width, height: height, length: length, chamferRadius: radius)
        geo.materials = [material]
        return SCNNode(geometry: geo)
    }

    private func makeCrystal(height: CGFloat, tint: UIColor) -> SCNNode {
        let geo = SCNPyramid(width: height * 0.58, height: height, length: height * 0.58)
        let baseColor: UIColor
        if tint == .white {
            baseColor = UIColor(red: 0.72, green: 0.98, blue: 1.0, alpha: 1)
        } else if tint == .blue {
            baseColor = UIColor(red: 0.08, green: 0.40, blue: 1.0, alpha: 1)
        } else {
            baseColor = UIColor(red: 0.03, green: 0.82, blue: 1.0, alpha: 1)
        }
        let material = pbr(color: baseColor, metalness: 0.18, roughness: 0.12, emission: baseColor.withAlphaComponent(0.62))
        material.transparency = 0.92
        geo.materials = [material]
        return SCNNode(geometry: geo)
    }

    private func cylinderBetween(start: SCNVector3, end: SCNVector3, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let dz = end.z - start.z
        let distance = sqrt(dx * dx + dy * dy + dz * dz)
        let geo = SCNCylinder(radius: radius, height: CGFloat(distance))
        geo.radialSegmentCount = 16
        geo.materials = [material]
        let node = SCNNode(geometry: geo)
        node.position = SCNVector3((start.x + end.x) * 0.5, (start.y + end.y) * 0.5, (start.z + end.z) * 0.5)
        node.look(at: end, up: SCNVector3(0, 0, 1), localFront: SCNVector3(0, 1, 0))
        return node
    }

    private func pbr(color: UIColor, metalness: CGFloat, roughness: CGFloat, emission: UIColor? = nil) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.metalness.contents = NSNumber(value: Double(metalness))
        material.roughness.contents = NSNumber(value: Double(roughness))
        if let emission {
            material.emission.contents = emission
        }
        return material
    }

    private func emissive(_ color: UIColor, transparency: CGFloat) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.diffuse.contents = color
        material.emission.contents = color
        material.transparency = transparency
        material.isDoubleSided = true
        material.blendMode = .add
        material.writesToDepthBuffer = false
        return material
    }
}
