import Foundation

/// On-device policy: look expensive, stay smooth, keep the Mac cool.
/// Highest *perceived* quality is FSR/MetalFX + a frame cap, not native 4K + ray tracing.
public struct OptimizationPolicy: Sendable, Equatable {
    public let fpsCap: Int
    public let upscaler: String
    public let rayTracing: String
    public let thermal: String
    public let dxvkHUD: String
    public let reason: String

    public init(
        fpsCap: Int,
        upscaler: String,
        rayTracing: String,
        thermal: String,
        dxvkHUD: String,
        reason: String
    ) {
        self.fpsCap = fpsCap
        self.upscaler = upscaler
        self.rayTracing = rayTracing
        self.thermal = thermal
        self.dxvkHUD = dxvkHUD
        self.reason = reason
    }
}

public struct OptimizationLayer: Sendable {
    public init() {}

    public func policy(
        for profile: TitleProfile,
        thermal: ProcessInfo.ThermalState = ProcessInfo.processInfo.thermalState
    ) -> OptimizationPolicy {
        let thermalName = Self.name(thermal)
        let fpsCap: Int
        switch thermal {
        case .critical: fpsCap = 30
        case .serious: fpsCap = 40
        case .fair: fpsCap = 60
        default: fpsCap = 60
        }

        let upscaler = profile.settings?.upscaler ?? "fsr-quality"
        let rayTracing = profile.settings?.rayTracing ?? "off"

        let reason = "cap \(fpsCap)fps, \(upscaler), RT \(rayTracing), thermal \(thermalName). Smooth + cool beats native 4K."

        return OptimizationPolicy(
            fpsCap: fpsCap,
            upscaler: upscaler,
            rayTracing: rayTracing,
            thermal: thermalName,
            dxvkHUD: "fps,memory,gpuload,scale",
            reason: reason
        )
    }

    public func apply(_ policy: OptimizationPolicy, into env: inout [String: String]) {
        env["DXVK_FRAME_RATE"] = "\(policy.fpsCap)"
        env["DXVK_HUD"] = policy.dxvkHUD
        env["DXVK_STATE_CACHE"] = "1"
        env["MVK_CONFIG_RESUME_LOST_DEVICE"] = "1"
        env["MVK_CONFIG_USE_METAL_ARGUMENT_BUFFERS"] = "1"
        env["MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS"] = "0"
        env["VKD3D_FEATURE_LEVEL"] = "12_0"
        env["MOGGED_UPSCALER"] = policy.upscaler
        env["MOGGED_RT"] = policy.rayTracing
        env["MOGGED_THERMAL"] = policy.thermal
    }

    private static func name(_ thermal: ProcessInfo.ThermalState) -> String {
        switch thermal {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}
